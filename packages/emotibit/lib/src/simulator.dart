import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'packet.dart';
import 'type_tags.dart';

/// A fake EmotiBit that speaks the device side of the WiFi protocol and
/// streams synthetic physiology. Lets the whole platform be developed and
/// tested without hardware.
///
/// Sampling rates are approximations of EmotiBit defaults (EDA ~15 Hz,
/// PPG/IMU ~25 Hz, temperature ~7.5 Hz); adjust if the real device differs.
class EmotiBitSimulator {
  EmotiBitSimulator({
    this.deviceId = 'SIM-0001',
    this.advertisingPort = EmotiBitPorts.advertising,
    this.bindAddress,
    this.heartRateBpm = 72,
    int? seed,
  }) : _rng = Random(seed);

  final String deviceId;
  final int advertisingPort;
  final InternetAddress? bindAddress;
  double heartRateBpm;
  final Random _rng;

  RawDatagramSocket? _adv;
  RawDatagramSocket? _data;
  Socket? _control;
  InternetAddress? _hostIp;
  int _hostDataPort = -1;
  int _controlPort = -1;
  DateTime _lastPing = DateTime.now();
  final _clock = Stopwatch()..start();
  int _pn = 0; // data packets
  int _advPn = 0; // advertising replies (separate counter, like the firmware)
  int _syncPn = 0; // time-sync requests (separate counter, like the firmware)
  final _timers = <Timer>[];

  bool get isConnected => _control != null;

  /// Stream of log lines (for the CLI).
  final _log = StreamController<String>.broadcast();
  Stream<String> get log => _log.stream;

  Future<void> start() async {
    _adv = await RawDatagramSocket.bind(bindAddress ?? InternetAddress.anyIPv4, advertisingPort);
    _adv!.listen((e) {
      if (e != RawSocketEvent.read) return;
      final dg = _adv!.receive();
      if (dg == null) return;
      for (final p in EmotiBitPacket.parseAll(utf8.decode(dg.data, allowMalformed: true))) {
        _onAdvertising(p, dg);
      }
    });
    _timers.add(Timer.periodic(const Duration(seconds: 1), (_) {
      if (isConnected && DateTime.now().difference(_lastPing) > const Duration(seconds: 10)) {
        _log.add('Sin PING por 10 s → desconectando');
        _disconnect();
      }
    }));
    _log.add('Simulador $deviceId escuchando en UDP ${_adv!.port}');
  }

  Future<void> _onAdvertising(EmotiBitPacket p, Datagram dg) async {
    switch (p.typeTag) {
      case TypeTag.helloEmotibit:
        _sendTo(_adv!, dg.address, dg.port, TypeTag.helloHost,
            [PayloadLabel.dataPort, '$_hostDataPort', PayloadLabel.deviceId, deviceId],
            dataLength: 0); // Real firmware sends dataLength 0 here.
      case TypeTag.emotibitConnect:
        final cp = int.tryParse(p.keyedValue(PayloadLabel.controlPort) ?? '');
        final dp = int.tryParse(p.keyedValue(PayloadLabel.dataPort) ?? '');
        if (cp == null || dp == null) return;
        if (!isConnected) {
          try {
            await _connect(dg.address, cp, dp);
          } catch (e) {
            _log.add('No se pudo conectar al host: $e');
            return;
          }
        }
        _lastPing = DateTime.now();
        _sendTo(_adv!, dg.address, dg.port, TypeTag.pong, [PayloadLabel.dataPort, '$_hostDataPort']);
      case TypeTag.ping:
        final dp = int.tryParse(p.keyedValue(PayloadLabel.dataPort) ?? '');
        if (isConnected && dg.address.address == _hostIp?.address && dp == _hostDataPort) {
          _lastPing = DateTime.now();
          _sendTo(_adv!, dg.address, dg.port, TypeTag.pong, [PayloadLabel.dataPort, '$_hostDataPort']);
        }
    }
  }

  Future<void> _connect(InternetAddress host, int controlPort, int dataPort) async {
    _control = await Socket.connect(host, controlPort, timeout: const Duration(seconds: 2));
    _hostIp = host;
    _controlPort = controlPort;
    _hostDataPort = dataPort;
    _data = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _control!.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        final p = EmotiBitPacket.tryParse(line);
        if (p == null) return;
        _log.add('Control ← ${p.typeTag} ${p.payload.join(",")}');
        if (p.typeTag == TypeTag.emotibitDisconnect) _disconnect();
      },
      onDone: _disconnect,
      onError: (_) => _disconnect(),
    );
    _log.add('Conectado a ${host.address} (CP $_controlPort, DP $_hostDataPort)');
    _startStreaming();
  }

  void _disconnect() {
    if (!isConnected) return;
    for (final t in _streamTimers) {
      t.cancel();
    }
    _streamTimers.clear();
    _control?.destroy();
    _control = null;
    _data?.close();
    _data = null;
    _hostDataPort = -1;
    _controlPort = -1;
    _log.add('Desconectado');
  }

  // ---------------------------------------------------------------- signals
  final _streamTimers = <Timer>[];
  final _pending = StringBuffer();
  double _eda = 2.0;
  double _scr = 0;
  final _ppgPhase = <String, double>{}; // cardiac phase 0..1 per channel
  double _temp = 33.5;
  double _battery = 100;

  void _startStreaming() {
    const tick = Duration(milliseconds: 100); // device flushes ~10x/s
    var t = 0;
    _streamTimers.add(Timer.periodic(tick, (_) {
      t++;
      _emit(TypeTag.eda, 15 / 10, _nextEda);
      _emit(TypeTag.ppgInfrared, 25 / 10, () => _nextPpg(TypeTag.ppgInfrared, 1.0));
      _emit(TypeTag.ppgRed, 25 / 10, () => _nextPpg(TypeTag.ppgRed, 0.6));
      _emit(TypeTag.ppgGreen, 25 / 10, () => _nextPpg(TypeTag.ppgGreen, 0.3));
      for (final tag in [TypeTag.accelX, TypeTag.accelY, TypeTag.accelZ]) {
        _emit(tag, 25 / 10, () => (tag == TypeTag.accelZ ? 1.0 : 0.0) + _noise(0.02));
      }
      for (final tag in [TypeTag.gyroX, TypeTag.gyroY, TypeTag.gyroZ]) {
        _emit(tag, 25 / 10, () => _noise(1.5));
      }
      _emit(TypeTag.temperature0, 7.5 / 10, () => _temp += _noise(0.01));
      if (t % 10 == 0) {
        _queue(TypeTag.heartRate, [(heartRateBpm + _noise(2)).toStringAsFixed(1)]);
        _queue(TypeTag.interBeatInterval, [(60000 / heartRateBpm + _noise(20)).toStringAsFixed(0)]);
      }
      if (t % 50 == 0) {
        _battery = max(0, _battery - 0.05);
        _queue(TypeTag.batteryPercent, [_battery.round().toString()]);
      }
      if (t % 51 == 0) _queue(TypeTag.requestData, [TypeTag.timestampLocal, TypeTag.timestampUtc]);
      _flush();
    }));
  }

  final _carry = <String, double>{};
  void _emit(String tag, double samplesPerTick, double Function() gen) {
    final acc = (_carry[tag] ?? 0) + samplesPerTick;
    final n = acc.floor();
    _carry[tag] = acc - n;
    if (n == 0) return;
    _queue(tag, [for (var i = 0; i < n; i++) gen().toStringAsFixed(4)]);
  }

  double _nextEda() {
    if (_rng.nextDouble() < 0.01) _scr += 0.3 + _rng.nextDouble() * 0.5; // phasic response
    _scr *= 0.93;
    _eda += (2.0 - _eda) * 0.001 + _noise(0.002);
    return _eda + _scr;
  }

  double _nextPpg(String tag, double gain) {
    // Simple systolic peak + dicrotic notch shape.
    final p = _ppgPhase[tag] = ((_ppgPhase[tag] ?? 0) + heartRateBpm / 60 / 25) % 1.0;
    final wave = exp(-pow((p - 0.15) / 0.06, 2)) + 0.35 * exp(-pow((p - 0.45) / 0.08, 2));
    return 50000 + gain * 8000 * wave + _noise(150);
  }

  double _noise(double s) => (_rng.nextDouble() * 2 - 1) * s;

  void _queue(String tag, List<String> payload) {
    _pending.write(EmotiBitPacket(
      timestamp: _clock.elapsedMilliseconds,
      packetNumber: (tag == TypeTag.requestData ? _syncPn++ : _pn++) & 0xFFFF,
      typeTag: tag,
      payload: payload,
    ).encode());
  }

  void _flush() {
    if (_pending.isEmpty || _data == null || _hostIp == null) return;
    _data!.send(utf8.encode(_pending.toString()), _hostIp!, _hostDataPort);
    _pending.clear();
  }

  void _sendTo(RawDatagramSocket s, InternetAddress a, int port, String tag, List<String> payload,
      {int? dataLength}) {
    s.send(
      utf8.encode(EmotiBitPacket(
        timestamp: _clock.elapsedMilliseconds,
        packetNumber: _advPn++ & 0xFFFF,
        typeTag: tag,
        payload: payload,
        dataLength: dataLength,
      ).encode()),
      a,
      port,
    );
  }

  Future<void> stop() async {
    _disconnect();
    for (final t in _timers) {
      t.cancel();
    }
    _adv?.close();
    await _log.close();
  }
}
