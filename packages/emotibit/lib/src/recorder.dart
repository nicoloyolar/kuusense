import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'packet.dart';
import 'preview.dart';
import 'type_tags.dart';

/// Writes a session to disk while it streams.
///
/// - `raw.csv`: every packet line exactly as the EmotiBit sent it — the same
///   format as the device's SD-card files, so the official EmotiBit DataParser
///   can process it.
/// - `sync.csv`: `host_epoch_ms,device_ms` pairs (~1/s) to map the device clock
///   (ms since boot) to wall-clock time.
/// - `events.csv`: `host_epoch_ms,device_ms,label` for markers added in the app.
/// - `signals.csv`: per-second summary for dashboards, written on [stop]
///   (see [SignalPreviewBuilder]); [preview] also gives the session figures.
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
  final SignalPreviewBuilder preview = SignalPreviewBuilder();
  DateTime? startedAt;
  DateTime? endedAt;

  File get rawFile => File('${directory.path}/raw.csv');
  File get syncFile => File('${directory.path}/sync.csv');
  File get eventsFile => File('${directory.path}/events.csv');
  File get signalsFile => File('${directory.path}/signals.csv');
  List<File> get files => filesIn(directory);

  /// The files of a session folder, in upload order.
  static List<File> filesIn(Directory d) => [
        for (final name in ['raw.csv', 'sync.csv', 'events.csv', 'signals.csv'])
          File('${d.path}/$name'),
      ];

  /// Closes a recording that was left open (the app was killed mid-session):
  /// drops a half-written last line from `raw.csv` so it stays valid for the
  /// DataParser, then rebuilds `signals.csv` from `raw.csv` and `sync.csv`.
  /// Returns null if the folder has no `raw.csv`.
  static Future<RecoveredRecording?> recover(Directory directory) async {
    final raw = File('${directory.path}/raw.csv');
    if (!await raw.exists()) return null;
    final bytes = await raw.readAsBytes();
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] != 0x0A) {
      end--;
    }
    if (end != bytes.length) {
      final f = await raw.open(mode: FileMode.append);
      await f.truncate(end);
      await f.close();
    }
    final rawText = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
    final syncFile = File('${directory.path}/sync.csv');
    final syncText = await syncFile.exists() ? await syncFile.readAsString() : '';
    final eventsFile = File('${directory.path}/events.csv');
    if (!await eventsFile.exists()) {
      await eventsFile.writeAsString('host_epoch_ms,device_ms,label\n');
    }
    if (!await syncFile.exists()) {
      await syncFile.writeAsString('host_epoch_ms,device_ms\n');
    }

    final preview = SignalPreviewBuilder.fromRecording(rawText, syncText);
    await File('${directory.path}/signals.csv').writeAsString(preview.toCsv());

    var count = 0;
    final tags = <String>{};
    for (final p in EmotiBitPacket.parseAll(rawText)) {
      count++;
      if (TypeTag.sensorStreams.contains(p.typeTag) || TypeTag.derived.contains(p.typeTag)) {
        tags.add(p.typeTag);
      }
    }
    int? lastHostMs;
    for (final line in syncText.split('\n').reversed) {
      lastHostMs = int.tryParse(line.split(',').first.trim());
      if (lastHostMs != null) break;
    }
    lastHostMs ??= (await raw.lastModified()).millisecondsSinceEpoch;
    return RecoveredRecording(
      directory: directory,
      preview: preview,
      packetCount: count,
      tagsSeen: tags,
      endedAtMs: lastHostMs,
    );
  }

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
    preview.add(p, now);
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
    await signalsFile.writeAsString(preview.toCsv());
  }

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt!);
}

/// A recording closed by [SessionRecorder.recover].
class RecoveredRecording {
  RecoveredRecording({
    required this.directory,
    required this.preview,
    required this.packetCount,
    required this.tagsSeen,
    required this.endedAtMs,
  });

  final Directory directory;
  final SignalPreviewBuilder preview;
  final int packetCount;
  final Set<String> tagsSeen;

  /// Phone time of the last data written (last `sync.csv` line).
  final int endedAtMs;

  List<File> get files => SessionRecorder.filesIn(directory);
}
