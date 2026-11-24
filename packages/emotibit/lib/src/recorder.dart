import 'dart:async';
import 'dart:io';

import 'packet.dart';
import 'type_tags.dart';

/// Writes a session to disk while it streams.
///
/// - `raw.csv`: every packet line exactly as the EmotiBit sent it — the same
///   format as the device's SD-card files, so the official EmotiBit DataParser
///   can process it.
/// - `sync.csv`: `host_epoch_ms,device_ms` pairs (~1/s) to map the device clock
///   (ms since boot) to wall-clock time.
/// - `events.csv`: `host_epoch_ms,device_ms,label` for markers added in the app.
class SessionRecorder {
  SessionRecorder._(this.directory, this._raw, this._sync, this._events);

  final Directory directory;
  final IOSink _raw;
  final IOSink _sync;
  final IOSink _events;
  int _lastSyncHostMs = 0;
  int _lastDeviceMs = 0;
  int packetCount = 0;
  final Set<String> tagsSeen = {};
  DateTime? startedAt;
  DateTime? endedAt;

  File get rawFile => File('${directory.path}/raw.csv');
  File get syncFile => File('${directory.path}/sync.csv');
  File get eventsFile => File('${directory.path}/events.csv');
  List<File> get files => [rawFile, syncFile, eventsFile];

  static Future<SessionRecorder> start(Directory directory) async {
    await directory.create(recursive: true);
    final r = SessionRecorder._(
      directory,
      File('${directory.path}/raw.csv').openWrite(),
      File('${directory.path}/sync.csv').openWrite()..writeln('host_epoch_ms,device_ms'),
      File('${directory.path}/events.csv').openWrite()..writeln('host_epoch_ms,device_ms,label'),
    );
    r.startedAt = DateTime.now();
    return r;
  }

  void add(EmotiBitPacket p) {
    if (endedAt != null) return;
    _raw.write(p.encode());
    packetCount++;
    _lastDeviceMs = p.timestamp;
    if (TypeTag.sensorStreams.contains(p.typeTag) || TypeTag.derived.contains(p.typeTag)) {
      tagsSeen.add(p.typeTag);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSyncHostMs >= 1000) {
      _sync.writeln('$now,${p.timestamp}');
      _lastSyncHostMs = now;
    }
  }

  void mark(String label) {
    if (endedAt != null) return;
    final safe = label.replaceAll(RegExp(r'[,\n\r]'), ' ');
    _events.writeln('${DateTime.now().millisecondsSinceEpoch},$_lastDeviceMs,$safe');
  }

  Future<void> stop() async {
    if (endedAt != null) return;
    endedAt = DateTime.now();
    await Future.wait([_raw.close(), _sync.close(), _events.close()]);
  }

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt!);
}
