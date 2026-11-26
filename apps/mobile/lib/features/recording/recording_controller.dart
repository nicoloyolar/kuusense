import 'dart:async';
import 'dart:collection';

import 'package:emotibit/emotibit.dart';
import 'package:flutter/foundation.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';

import 'background_recording.dart';
import 'device_scanner.dart';
import 'session_upload_queue.dart';

export 'session_upload_queue.dart' show UploadState;

/// Holds everything the tutor app does with the device: selected child, connection,
/// live values, recording and upload. Screens only read from / call into this.
class RecordingController extends ChangeNotifier {
  RecordingController(this.repo) : uploads = SessionUploadQueue(repo) {
    uploads.addListener(notifyListeners);
  }

  final KuusenseRepository repo;

  /// Finished sessions still on the phone; uploads them when it can.
  final SessionUploadQueue uploads;

  /// How long a recording waits for a lost EmotiBit before it is closed.
  static const reconnectWindow = Duration(minutes: 5);
  static const _reconnectEvery = Duration(seconds: 3);

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

  Future<void> connect(DiscoveredEmotiBit device) async {
    await disconnect();
    deviceLostMessage = null;
    _attach(await EmotiBitHost.connect(device));
    unawaited(LastEmotiBit.save(device));
  }

  void _attach(EmotiBitConnection conn) {
    connection = conn;
    _lastDevice = conn.device;
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

  Future<void> _detach() async {
    await _packetSub?.cancel();
    await _statusSub?.cancel();
    _packetSub = null;
    _statusSub = null;
    final c = connection;
    connection = null;
    await c?.close();
  }

  Future<void> disconnect() async {
    await _detach();
    notifyListeners();
  }

  void _onDeviceLost() {
    _detach();
    if (isRecording) {
      _beginReconnect();
    } else {
      deviceLostMessage = 'Se perdió la conexión con el EmotiBit.';
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- reconnection
  DiscoveredEmotiBit? _lastDevice;
  DateTime? _gapStart;
  int _reconnectRun = 0;

  /// The device dropped during a recording and the app is looking for it.
  bool get isReconnecting => _gapStart != null;

  /// Time left before the recording is closed if the device does not return.
  Duration get reconnectTimeLeft {
    final start = _gapStart;
    if (start == null) return Duration.zero;
    final left = reconnectWindow - DateTime.now().difference(start);
    return left.isNegative ? Duration.zero : left;
  }

  /// Keeps the recording open and tries to reach the same EmotiBit again.
  /// The gap is marked in events.csv (`gap_start`/`gap_end`) and saved in
  /// the session, so the dataset shows where data is missing.
  void _beginReconnect() {
    if (_gapStart != null) return;
    _gapStart = DateTime.now();
    _recorder?.mark('gap_start');
    BackgroundRecording.status('Reconectando con el EmotiBit…');
    _reconnectLoop(++_reconnectRun);
  }

  Future<void> _reconnectLoop(int run) async {
    final device = _lastDevice;
    while (run == _reconnectRun && isRecording && _gapStart != null) {
      if (device != null) {
        final conn = await _tryReconnect(device);
        if (run != _reconnectRun || !isRecording || _gapStart == null) {
          await conn?.close();
          return;
        }
        if (conn != null) {
          _endGap();
          _attach(conn);
          BackgroundRecording.status('Grabando sesión');
          return;
        }
      }
      if (reconnectTimeLeft == Duration.zero) {
        await stopRecording(reason: SessionEndReason.deviceLost);
        return;
      }
      notifyListeners(); // countdown
      await Future<void>.delayed(_reconnectEvery);
    }
  }

  /// Looks for the device at its last address, then by broadcast (its IP
  /// may change if it rebooted), and connects if it answers.
  Future<EmotiBitConnection?> _tryReconnect(DiscoveredEmotiBit last) async {
    for (final targets in [
      [last.address],
      null, // broadcast
    ]) {
      try {
        final found = await EmotiBitHost.discover(targets: targets);
        final match = found.where((d) => d.deviceId == last.deviceId);
        if (match.isEmpty) continue;
        return await EmotiBitHost.connect(match.first);
      } catch (e) {
        debugPrint('reconnect attempt failed: $e');
      }
    }
    return null;
  }

  void _endGap() {
    final start = _gapStart;
    if (start == null) return;
    _gapStart = null;
    _recorder?.mark('gap_end');
    if (_gaps.length < SessionGap.maxPerSession) {
      _gaps.add(SessionGap(
        fromMs: start.millisecondsSinceEpoch,
        toMs: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    _saveMeta();
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
  PendingSession? _meta;
  Timer? _liveTimer;
  final List<SessionGap> _gaps = [];

  /// Upload state of the last recorded session.
  UploadState get uploadState {
    final s = session;
    return (s == null || isRecording) ? UploadState.idle : uploads.stateOf(s.id);
  }

  String? get uploadError => session == null ? null : uploads.errorOf(session!.id);

  /// Behaviors and notes marked during the current session, in order.
  final List<SessionEvent> events = [];

  bool get isRecording => _recorder != null && _recorder!.endedAt == null;
  Duration get elapsed => _recorder?.duration ?? Duration.zero;

  Future<void> startRecording({
    SessionContext context = const SessionContext(),
  }) async {
    final conn = connection;
    if (conn == null || childId == null || isRecording) return;
    events.clear();
    _gaps.clear();
    final s = await repo.startSession(
      childId: childId!,
      deviceId: conn.device.deviceId,
      appVersion: '0.1.0',
      context: context,
    );
    session = s;
    uploads.activeSessionId = s.id;
    final dir = await SessionUploadQueue.dirFor(s.id);
    _recorder = await SessionRecorder.start(dir);
    _meta = PendingSession(
      sessionId: s.id,
      childId: s.childId,
      uid: s.createdByUid,
      startedAtMs: s.startedAtMs,
    );
    await _saveMeta();
    _liveTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pushLive());
    await BackgroundRecording.begin();
    notifyListeners();
  }

  /// Keeps session.json up to date so nothing is lost if the app dies.
  Future<void> _saveMeta() async {
    final m = _meta;
    final rec = _recorder;
    if (m == null || rec == null) return;
    m
      ..gaps = List.of(_gaps)
      ..events = List.of(events);
    try {
      await m.write(rec.directory);
    } catch (e) {
      debugPrint('session.json not written: $e');
    }
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
    _saveMeta();
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
    _saveMeta();
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

  Future<void> stopRecording({
    SessionEndReason reason = SessionEndReason.stopped,
  }) async {
    final rec = _recorder;
    final s = session;
    final m = _meta;
    if (rec == null || s == null || m == null || rec.endedAt != null) return;
    _reconnectRun++; // ends any reconnection loop
    if (_gapStart != null) _endGap();
    _liveTimer?.cancel();
    await rec.stop();
    final streams = rec.tagsSeen.toList()..sort();
    m
      ..endedAtMs = rec.endedAt!.millisecondsSinceEpoch
      ..endReason = reason
      ..packetCount = rec.packetCount
      ..streams = streams
      ..stats = rec.preview.statsJson();
    await _saveMeta();
    uploads.activeSessionId = null;
    await BackgroundRecording.end();
    if (reason == SessionEndReason.deviceLost) {
      deviceLostMessage =
          'El EmotiBit no volvió en ${reconnectWindow.inMinutes} minutos. '
          'La sesión se cerró y se guardó como incompleta.';
    }
    notifyListeners();
    await uploads.run();
  }

  /// Retries uploads that failed (files are still on the phone).
  Future<void> retryUpload() => uploads.run();

  /// Starts the upload queue: recovers sessions left open by a closed app and
  /// uploads anything pending. Called once after sign-in.
  void startUploads() => uploads.start();

  @override
  void dispose() {
    _reconnectRun++;
    _uiTimer?.cancel();
    _liveTimer?.cancel();
    connection?.close();
    uploads.removeListener(notifyListeners);
    uploads.dispose();
    super.dispose();
  }
}
