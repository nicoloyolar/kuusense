import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:emotibit/emotibit.dart';
import 'package:flutter/foundation.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:path_provider/path_provider.dart';

enum UploadState { idle, uploading, done, failed }

/// Holds everything the tutor app does with the device: selected child, connection,
/// live values, recording and upload. Screens only read from / call into this.
class RecordingController extends ChangeNotifier {
  RecordingController(this.repo);

  final KuusenseRepository repo;

  // ---------------------------------------------------------------- selected child
  /// The child (NNA) the tutor is working with; sessions are recorded for it.
  String? childId;

  /// Name shown in the UI (the child's nickname, from its private profile).
  String? childLabel;

  void selectChild(String id, String label) {
    childId = id;
    childLabel = label;
    notifyListeners();
  }

  void clearChild() {
    childId = null;
    childLabel = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- device
  EmotiBitConnection? connection;
  StreamSubscription<EmotiBitPacket>? _packetSub;
  StreamSubscription<EmotiBitConnectionStatus>? _statusSub;

  bool get isConnected =>
      connection?.status == EmotiBitConnectionStatus.connected;

  Future<List<DiscoveredEmotiBit>> scan({String? manualIp}) {
    final ip = manualIp?.trim();
    return EmotiBitHost.discover(
      targets: (ip == null || ip.isEmpty) ? null : [InternetAddress(ip)],
    );
  }

  Future<void> connect(DiscoveredEmotiBit device) async {
    await disconnect();
    deviceLostMessage = null;
    final conn = await EmotiBitHost.connect(device);
    connection = conn;
    _packetSub = conn.packets.listen(_onPacket);
    _statusSub = conn.statusChanges.listen((s) {
      if (s == EmotiBitConnectionStatus.disconnected) _onDeviceLost();
    });
    _uiTimer ??= Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (_dirty) {
        _dirty = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _packetSub?.cancel();
    await _statusSub?.cancel();
    await connection?.close();
    connection = null;
    notifyListeners();
  }

  void _onDeviceLost() {
    connection = null;
    deviceLostMessage = 'Se perdió la conexión con el EmotiBit.';
    if (isRecording) stopRecording();
    notifyListeners();
  }

  String? deviceLostMessage;

  // ---------------------------------------------------------------- live values
  static const plotSamples = 250;
  final Map<String, double> latest = {};
  final Map<String, ListQueue<double>> traces = {
    TypeTag.ppgInfrared: ListQueue(),
    TypeTag.eda: ListQueue(),
  };
  bool _dirty = false;
  Timer? _uiTimer;

  void _onPacket(EmotiBitPacket p) {
    _recorder?.add(p);
    final values = p.values;
    if (values.isEmpty) return;
    latest[p.typeTag] = values.last;
    final trace = traces[p.typeTag];
    if (trace != null) {
      trace.addAll(values);
      while (trace.length > plotSamples) {
        trace.removeFirst();
      }
    }
    _dirty = true;
  }

  double? get temperature =>
      latest[TypeTag.temperature0] ?? latest[TypeTag.thermopile];

  // ---------------------------------------------------------------- recording
  SessionRecorder? _recorder;
  RecordingSession? session;
  Timer? _liveTimer;
  UploadState uploadState = UploadState.idle;
  String? uploadError;

  /// Behaviors and notes marked during the current session, in order.
  final List<SessionEvent> events = [];

  bool get isRecording => _recorder != null && _recorder!.endedAt == null;
  Duration get elapsed => _recorder?.duration ?? Duration.zero;

  Future<void> startRecording({
    SessionContext context = const SessionContext(),
  }) async {
    final conn = connection;
    if (conn == null || childId == null || isRecording) return;
    uploadState = UploadState.idle;
    uploadError = null;
    events.clear();
    final s = await repo.startSession(
      childId: childId!,
      deviceId: conn.device.deviceId,
      appVersion: '0.1.0',
      context: context,
    );
    session = s;
    final dir = await getApplicationDocumentsDirectory();
    _recorder = await SessionRecorder.start(
      Directory('${dir.path}/sessions/${s.id}'),
    );
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushLive());
    notifyListeners();
  }

  /// Marks a behavior from [BehaviorCatalog] (or a note) at the current time.
  void addEvent(String kind, {String? note}) {
    final s = session;
    if (!isRecording || s == null) return;
    final text = note?.trim();
    final event = SessionEvent(
      atMs: DateTime.now().millisecondsSinceEpoch,
      kind: kind,
      note: (text == null || text.isEmpty)
          ? null
          : text.substring(0, text.length.clamp(0, SessionEvent.maxNoteLength)),
    );
    if (events.length >= SessionEvent.maxPerSession) return;
    // events.csv keeps the machine id; the note text goes after a colon.
    _recorder!.mark(event.note == null ? kind : '$kind:${event.note}');
    connection?.sendUserNote(event.label); // also lands on the device's SD file
    events.add(event);
    repo
        .addSessionEvent(s.childId, s.id, event)
        .catchError((Object e) => debugPrint('event push failed: $e'));
    notifyListeners();
  }

  /// Removes the last marked event (a mistaken tap). events.csv keeps an
  /// `undo:` line instead of erasing, so the raw record stays append-only.
  void undoLastEvent() {
    final s = session;
    if (!isRecording || s == null || events.isEmpty) return;
    final event = events.removeLast();
    _recorder!.mark('undo:${event.kind}');
    repo
        .removeSessionEvent(s.childId, s.id, event)
        .catchError((Object e) => debugPrint('event undo failed: $e'));
    notifyListeners();
  }

  void _pushLive() {
    final s = session;
    if (s == null) return;
    repo
        .pushLive(
          s.childId,
          s.id,
          LiveSnapshot(
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            heartRate: latest[TypeTag.heartRate],
            eda: latest[TypeTag.eda],
            temperature: temperature,
            batteryPercent: latest[TypeTag.batteryPercent],
          ),
        )
        .catchError((Object e) => debugPrint('live push failed: $e'));
  }

  Future<void> stopRecording() async {
    final rec = _recorder;
    final s = session;
    if (rec == null || s == null || rec.endedAt != null) return;
    _liveTimer?.cancel();
    await rec.stop();
    notifyListeners();
    await _upload(s, rec);
  }

  Future<void> _upload(RecordingSession s, SessionRecorder rec) async {
    uploadState = UploadState.uploading;
    notifyListeners();
    try {
      await repo.updateSession(s.childId, s.id, {
        'status': SessionStatus.uploading.name,
        'endedAtMs': rec.endedAt!.millisecondsSinceEpoch,
        'packetCount': rec.packetCount,
        'streams': rec.tagsSeen.toList()..sort(),
        // Full list again, in case a live event write was lost offline.
        'events': [for (final e in events) e.toMap()],
      });
      final files = <String, String>{};
      for (final f in rec.files) {
        final name = f.uri.pathSegments.last;
        final ref = repo.sessionFileRef(s.childId, s.id, name);
        await ref.putFile(f);
        files[name] = ref.fullPath;
      }
      await repo.updateSession(s.childId, s.id, {
        'files': files,
        'status': SessionStatus.uploaded.name,
      });
      uploadState = UploadState.done;
      // Local copy kept until the upload succeeded; now safe to delete.
      await rec.directory.delete(recursive: true);
    } catch (e) {
      uploadState = UploadState.failed;
      uploadError = '$e';
      await repo
          .updateSession(s.childId, s.id, {'status': SessionStatus.failed.name})
          .catchError((_) {});
    }
    notifyListeners();
  }

  /// Retries a failed upload of the last session (files are still on disk).
  Future<void> retryUpload() async {
    final rec = _recorder;
    final s = session;
    if (rec != null && s != null && uploadState == UploadState.failed) {
      await _upload(s, rec);
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _liveTimer?.cancel();
    connection?.close();
    super.dispose();
  }
}
