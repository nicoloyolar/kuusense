import 'dart:collection';
import 'dart:math';

import 'packet.dart';
import 'stats.dart';
import 'type_tags.dart';

/// Builds a light per-second summary of a session (`signals.csv`) plus
/// whole-session figures, so dashboards can chart a session without reading
/// the full `raw.csv`.
///
/// `signals.csv` columns (one row per wall-clock second, empty = no data):
/// `host_epoch_ms,heart_rate,eda,temperature,motion,battery`
/// - heart_rate: mean HR (bpm) reported by the device in that second
/// - eda: mean EDA (µS)
/// - temperature: mean skin temperature (°C), T0 if the device sends it, else TH
/// - motion: movement intensity (g), the combined standard deviation of the
///   three accelerometer axes within the second (≈0 when still)
/// - battery: last battery percentage
///
/// [statsJson] keys match `SessionStats` in packages/kuusense_models.
class SignalPreviewBuilder {
  static const csvHeader = 'host_epoch_ms,heart_rate,eda,temperature,motion,battery';

  final SplayTreeMap<int, _Second> _seconds = SplayTreeMap();
  final EmotiBitStats _stats = EmotiBitStats();
  final _hr = _Range();
  final _eda = _Range();
  final _t0 = _Range();
  final _th = _Range();
  double? _batteryStart;
  double? _batteryEnd;
  int _scrCount = 0;

  /// Adds a packet received (or, offline, mapped) at [hostMs] wall-clock time.
  void add(EmotiBitPacket p, int hostMs) {
    _stats.add(p);
    final values = p.values;
    if (values.isEmpty) return;
    final sec = _seconds.putIfAbsent(hostMs ~/ 1000, _Second.new);
    switch (p.typeTag) {
      case TypeTag.heartRate:
        sec.hr.addAll(values);
        _hr.addAll(values);
      case TypeTag.eda:
        sec.eda.addAll(values);
        _eda.addAll(values);
      case TypeTag.temperature0:
        sec.t0.addAll(values);
        _t0.addAll(values);
      case TypeTag.thermopile:
        sec.th.addAll(values);
        _th.addAll(values);
      case TypeTag.accelX:
        sec.ax.addAll(values);
      case TypeTag.accelY:
        sec.ay.addAll(values);
      case TypeTag.accelZ:
        sec.az.addAll(values);
      case TypeTag.batteryPercent:
        sec.battery = values.last;
        _batteryStart ??= values.first;
        _batteryEnd = values.last;
      case TypeTag.scrAmplitude:
        _scrCount += values.length;
    }
  }

  /// Rebuilds the preview from a recording on disk: `raw.csv` lines mapped to
  /// wall-clock time with the `host_epoch_ms,device_ms` pairs of `sync.csv`.
  static SignalPreviewBuilder fromRecording(String rawCsv, String syncCsv) {
    final sync = <(int, int)>[]; // (device_ms, host_ms)
    for (final line in syncCsv.split('\n').skip(1)) {
      final parts = line.trim().split(',');
      if (parts.length < 2) continue;
      final host = int.tryParse(parts[0]);
      final device = int.tryParse(parts[1]);
      if (host != null && device != null) sync.add((device, host));
    }
    final b = SignalPreviewBuilder();
    for (final p in EmotiBitPacket.parseAll(rawCsv)) {
      final host = hostTimeFor(p.timestamp, sync);
      if (host != null) b.add(p, host);
    }
    return b;
  }

  /// Maps a device timestamp to host time by interpolating between the
  /// nearest sync pairs (or offsetting from the closest one at the edges).
  /// A device reboot makes device time jump back; pairs are searched in
  /// recording order, so the first matching segment wins.
  static int? hostTimeFor(int deviceMs, List<(int, int)> sync) {
    if (sync.isEmpty) return null;
    for (var i = 0; i + 1 < sync.length; i++) {
      final (d0, h0) = sync[i];
      final (d1, h1) = sync[i + 1];
      if (d1 > d0 && deviceMs >= d0 && deviceMs <= d1) {
        return h0 + ((deviceMs - d0) * (h1 - h0) / (d1 - d0)).round();
      }
    }
    // Outside every segment: offset from the pair with the closest device time.
    var best = sync.first;
    for (final s in sync) {
      if ((s.$1 - deviceMs).abs() < (best.$1 - deviceMs).abs()) best = s;
    }
    return best.$2 + (deviceMs - best.$1);
  }

  bool get _useT0 => _t0.count > 0;

  String toCsv() {
    final b = StringBuffer()..writeln(csvHeader);
    String f(double? v, int digits) => v == null ? '' : v.toStringAsFixed(digits);
    for (final MapEntry(key: second, value: s) in _seconds.entries) {
      b.writeln([
        second * 1000,
        f(s.hr.mean, 1),
        f(s.eda.mean, 4),
        f((_useT0 ? s.t0 : s.th).mean, 2),
        f(s.motion, 4),
        f(s.battery, 0),
      ].join(','));
    }
    return b.toString();
  }

  /// Whole-session figures; keys match `SessionStats` in kuusense_models.
  Map<String, Object?> statsJson() => {
        'heartRate': _hr.toJson(),
        'eda': _eda.toJson(),
        'temperature': (_useT0 ? _t0 : _th).toJson(),
        'scrCount': _scrCount,
        'lossPercent': double.parse(_stats.lossPercent.toStringAsFixed(2)),
        'batteryStart': _batteryStart,
        'batteryEnd': _batteryEnd,
      };
}

class _Second {
  final hr = _Range();
  final eda = _Range();
  final t0 = _Range();
  final th = _Range();
  final ax = _Range();
  final ay = _Range();
  final az = _Range();
  double? battery;

  /// Combined standard deviation of the three axes, or null without data.
  double? get motion {
    if (ax.count < 2 && ay.count < 2 && az.count < 2) return null;
    return sqrt(ax.variance + ay.variance + az.variance);
  }
}

/// Count, min, mean, max and variance of a stream of values.
class _Range {
  int count = 0;
  double _sum = 0;
  double _sumSq = 0;
  double min = double.infinity;
  double max = double.negativeInfinity;

  void addAll(Iterable<double> values) {
    for (final v in values) {
      count++;
      _sum += v;
      _sumSq += v * v;
      if (v < min) min = v;
      if (v > max) max = v;
    }
  }

  double? get mean => count == 0 ? null : _sum / count;

  double get variance {
    if (count < 2) return 0;
    final m = _sum / count;
    return (_sumSq / count - m * m).clamp(0, double.infinity);
  }

  Map<String, double>? toJson() {
    double r(double v) => double.parse(v.toStringAsFixed(3));
    return count == 0 ? null : {'min': r(min), 'mean': r(mean!), 'max': r(max)};
  }
}
