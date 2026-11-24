import 'dart:math';

import 'packet.dart';
import 'type_tags.dart';

/// Running statistics for one type tag.
class TagStats {
  TagStats(this.typeTag);

  final String typeTag;
  int packets = 0;
  int samples = 0;
  int? firstTimestamp;
  int? lastTimestamp;
  double minValue = double.infinity;
  double maxValue = double.negativeInfinity;
  double _sum = 0;
  int _numeric = 0;
  List<String> lastPayload = const [];

  double? get mean => _numeric == 0 ? null : _sum / _numeric;
  bool get isNumeric => _numeric > 0;

  /// Samples per second estimated from device timestamps.
  /// Null until there is at least one second of data.
  double? get rateHz {
    if (firstTimestamp == null || lastTimestamp == null) return null;
    final spanMs = lastTimestamp! - firstTimestamp!;
    if (spanMs < 1000) return null;
    // The first packet's samples were taken before firstTimestamp, so they
    // are not counted in the span.
    return (samples - _firstPacketSamples) / (spanMs / 1000);
  }

  int _firstPacketSamples = 0;

  void add(EmotiBitPacket p) {
    packets++;
    final n = p.payload.length;
    if (packets == 1) _firstPacketSamples = n;
    samples += n;
    firstTimestamp ??= p.timestamp;
    lastTimestamp = p.timestamp;
    lastPayload = p.payload;
    for (final v in p.values) {
      _sum += v;
      _numeric++;
      minValue = min(minValue, v);
      maxValue = max(maxValue, v);
    }
  }
}

/// Aggregates everything a device sends: per-tag rates and value ranges,
/// plus packet loss detected from gaps in the device's packet counter.
class EmotiBitStats {
  static const _syncTags = {
    TypeTag.requestData, TypeTag.timestampLocal, TypeTag.timestampUtc, TypeTag.ack,
  };
  final Map<String, TagStats> tags = {};
  int totalPackets = 0;
  int _lostPackets = 0;
  int? _lastPacketNumber;
  int? firstTimestamp;
  int? lastTimestamp;

  /// Packets the device numbered but that never arrived.
  int get lostPackets => _lostPackets;
  double get lossPercent =>
      totalPackets + _lostPackets == 0 ? 0 : 100 * _lostPackets / (totalPackets + _lostPackets);

  Duration get span => firstTimestamp == null
      ? Duration.zero
      : Duration(milliseconds: lastTimestamp! - firstTimestamp!);

  void add(EmotiBitPacket p) {
    totalPackets++;
    firstTimestamp ??= p.timestamp;
    lastTimestamp = max(lastTimestamp ?? p.timestamp, p.timestamp);
    tags.putIfAbsent(p.typeTag, () => TagStats(p.typeTag)).add(p);

    // Time-sync packets use their own counter on the device; skip them.
    if (_syncTags.contains(p.typeTag)) return;
    // packetNumber is a uint16 counter shared by all data packets.
    final last = _lastPacketNumber;
    if (last != null) {
      final gap = (p.packetNumber - last - 1) & 0xFFFF;
      // Large "gaps" are reorders or counter resets, not loss.
      if (gap > 0 && gap < 1000) _lostPackets += gap;
    }
    _lastPacketNumber = p.packetNumber;
  }

  /// Tags sorted: sensor streams first, then derived, then everything else.
  List<TagStats> get sorted {
    int group(String t) => TypeTag.sensorStreams.contains(t)
        ? 0
        : TypeTag.derived.contains(t)
            ? 1
            : 2;
    return tags.values.toList()
      ..sort((a, b) {
        final g = group(a.typeTag).compareTo(group(b.typeTag));
        return g != 0 ? g : a.typeTag.compareTo(b.typeTag);
      });
  }

  /// Fixed-width text table for terminals and reports.
  String toTable() {
    final b = StringBuffer()
      ..writeln('${'Tag'.padRight(4)} ${'Señal'.padRight(22)} ${'Paq.'.padLeft(7)} '
          '${'Muestras'.padLeft(9)} ${'Hz'.padLeft(7)} ${'Mín'.padLeft(11)} '
          '${'Media'.padLeft(11)} ${'Máx'.padLeft(11)}  Último');
    for (final t in sorted) {
      String num(double v) => v.isFinite ? _fmt(v).padLeft(11) : '—'.padLeft(11);
      final label = TypeTag.labels[t.typeTag] ?? '';
      final last = t.lastPayload.isEmpty ? '' : t.lastPayload.last;
      b.writeln('${t.typeTag.padRight(4)} ${label.padRight(22).substring(0, 22)} '
          '${'${t.packets}'.padLeft(7)} ${'${t.samples}'.padLeft(9)} '
          '${(t.rateHz?.toStringAsFixed(1) ?? '—').padLeft(7)} '
          '${t.isNumeric ? num(t.minValue) : '—'.padLeft(11)} '
          '${t.mean == null ? '—'.padLeft(11) : num(t.mean!)} '
          '${t.isNumeric ? num(t.maxValue) : '—'.padLeft(11)}  '
          '${last.length > 24 ? '${last.substring(0, 24)}…' : last}');
    }
    b.write('Total: $totalPackets paquetes · perdidos: $lostPackets '
        '(${lossPercent.toStringAsFixed(2)} %) · duración: ${_dur(span)}');
    return b.toString();
  }

  static String _fmt(double v) =>
      v.abs() >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(v.abs() >= 10 ? 2 : 4);

  static String _dur(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
