import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emotibit/emotibit.dart';
import 'package:flutter/foundation.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:path_provider/path_provider.dart';

/// What the phone knows about one recorded session, kept next to its files
/// as `session.json` so an upload survives app restarts and a recording
/// survives the app being killed.
class PendingSession {
  PendingSession({
    required this.sessionId,
    required this.childId,
    required this.uid,
    required this.startedAtMs,
    this.endedAtMs,
    this.endReason,
    this.packetCount = 0,
    this.streams = const [],
    this.stats,
    this.gaps = const [],
    this.events = const [],
  });

  static const fileName = 'session.json';

  final String sessionId;
  final String childId;

  /// Tutor who recorded it; only that account may upload the files.
  final String uid;
  final int startedAtMs;
  int? endedAtMs;
  SessionEndReason? endReason;
  int packetCount;
  List<String> streams;
  Map<String, Object?>? stats;
  List<SessionGap> gaps;
  List<SessionEvent> events;

  /// Null while recording (or if the app died before it ended).
  bool get isEnded => endedAtMs != null;

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'childId': childId,
    'uid': uid,
    'startedAtMs': startedAtMs,
    'endedAtMs': endedAtMs,
    'endReason': endReason?.name,
    'packetCount': packetCount,
    'streams': streams,
    'stats': stats,
    'gaps': [for (final g in gaps) g.toMap()],
    'events': [for (final e in events) e.toMap()],
  };

  factory PendingSession.fromJson(Map<String, dynamic> m) => PendingSession(
    sessionId: m['sessionId'] as String,
    childId: m['childId'] as String,
    uid: m['uid'] as String,
    startedAtMs: (m['startedAtMs'] as num).toInt(),
    endedAtMs: (m['endedAtMs'] as num?)?.toInt(),
    endReason: SessionEndReason.values.asNameMap()[m['endReason']],
    packetCount: (m['packetCount'] as num?)?.toInt() ?? 0,
    streams: List<String>.from(m['streams'] as List? ?? const []),
    stats: (m['stats'] as Map?)?.cast<String, Object?>(),
    gaps: [
      for (final g in (m['gaps'] as List? ?? const []))
        SessionGap.fromMap(Map<String, dynamic>.from(g as Map)),
    ],
    events: [
      for (final e in (m['events'] as List? ?? const []))
        SessionEvent.fromMap(Map<String, dynamic>.from(e as Map)),
    ],
  );

  static Future<PendingSession?> read(Directory dir) async {
    final f = File('${dir.path}/$fileName');
    try {
      if (!await f.exists()) return null;
      return PendingSession.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('unreadable ${f.path}: $e');
      return null;
    }
  }

  /// Written to a temp file and renamed, so a crash never leaves half a file.
  Future<void> write(Directory dir) async {
    final tmp = File('${dir.path}/$fileName.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename('${dir.path}/$fileName');
  }
}

enum UploadState { idle, uploading, done, failed }

/// Uploads every finished session still on the phone, oldest first, and
/// recovers sessions left open by an app that was closed mid-recording.
/// Runs after each recording, when the app starts and every few minutes,
/// so nothing is lost if there was no internet or the app was closed.
class SessionUploadQueue extends ChangeNotifier {
  SessionUploadQueue(this.repo);

  final KuusenseRepository repo;

  static const retryEvery = Duration(minutes: 2);

  final Map<String, UploadState> _states = {};
  final Map<String, String> _errors = {};
  Timer? _timer;
  bool _running = false;
  bool _again = false;

  /// Session being recorded right now; never touched by the queue.
  String? activeSessionId;

  /// Sessions on this phone not yet uploaded (after the last run).
  int pendingCount = 0;

  UploadState stateOf(String sessionId) =>
      _states[sessionId] ?? UploadState.idle;
  String? errorOf(String sessionId) => _errors[sessionId];

  static Future<Directory> rootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/sessions');
  }

  static Future<Directory> dirFor(String sessionId) async =>
      Directory('${(await rootDir()).path}/$sessionId');

  /// Starts the periodic retry and runs once now.
  void start() {
    _timer ??= Timer.periodic(retryEvery, (_) => run());
    run();
  }

  /// Uploads everything pending. Safe to call any time; overlapping calls
  /// are merged into one extra pass.
  Future<void> run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        try {
          await _pass();
        } catch (e) {
          debugPrint('upload queue pass failed: $e');
        }
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _pass() async {
    final root = await rootDir();
    if (!await root.exists()) return;
    final pending = <(Directory, PendingSession)>[];
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final meta = await PendingSession.read(e);
      if (meta == null || meta.uid != repo.uid) continue;
      if (meta.sessionId == activeSessionId) continue;
      pending.add((e, meta));
    }
    pending.sort((a, b) => a.$2.startedAtMs.compareTo(b.$2.startedAtMs));
    pendingCount = pending.length;
    notifyListeners();

    for (final (dir, meta) in pending) {
      if (meta.sessionId == activeSessionId) continue;
      if (!meta.isEnded) await _recover(dir, meta);
      if (await _upload(dir, meta)) pendingCount--;
      notifyListeners();
    }
  }

  /// The app died mid-recording: close the files and mark it incomplete.
  Future<void> _recover(Directory dir, PendingSession meta) async {
    final r = await SessionRecorder.recover(dir);
    final streams = r?.tagsSeen.toList() ?? <String>[];
    streams.sort();
    meta
      ..endedAtMs = r?.endedAtMs ?? meta.startedAtMs
      ..endReason = SessionEndReason.appClosed
      ..packetCount = r?.packetCount ?? 0
      ..streams = streams
      ..stats = r?.preview.statsJson();
    // A gap still open when the app died is not saved: the session simply
    // ends with the last data written (endedAtMs).
    await meta.write(dir);
  }

  Future<bool> _upload(Directory dir, PendingSession meta) async {
    final id = meta.sessionId;
    _states[id] = UploadState.uploading;
    _errors.remove(id);
    notifyListeners();
    try {
      await repo.updateSession(meta.childId, id, {
        'status': SessionStatus.uploading.name,
        'endedAtMs': meta.endedAtMs,
        'packetCount': meta.packetCount,
        'streams': meta.streams,
        'stats': meta.stats,
        'endReason': meta.endReason?.name,
        'gaps': [for (final g in meta.gaps) g.toMap()],
        // Full list again, in case a live event write was lost offline.
        'events': [for (final e in meta.events) e.toMap()],
      });
      final files = <String, String>{};
      for (final f in SessionRecorder.filesIn(dir)) {
        if (!await f.exists()) continue;
        final name = f.uri.pathSegments.last;
        final ref = repo.sessionFileRef(meta.childId, id, name);
        await ref.putFile(f);
        files[name] = ref.fullPath;
      }
      await repo.updateSession(meta.childId, id, {
        'files': files,
        'status': SessionStatus.uploaded.name,
      });
      // Local copy kept until the upload succeeded; now safe to delete.
      await dir.delete(recursive: true);
      _states[id] = UploadState.done;
      return true;
    } catch (e) {
      _states[id] = UploadState.failed;
      _errors[id] = '$e';
      await repo
          .updateSession(meta.childId, id, {
            'status': SessionStatus.failed.name,
          })
          .catchError((_) {});
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
