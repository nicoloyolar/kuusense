import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'packet.dart';
import 'type_tags.dart';

/// An EmotiBit that answered a HELLO_EMOTIBIT broadcast.
class DiscoveredEmotiBit {
  const DiscoveredEmotiBit({
    required this.address,
    required this.deviceId,
    required this.isAvailable,
    this.advertisingPort = EmotiBitPorts.advertising,
  });

  final InternetAddress address;
  final String deviceId;

  /// False if the device is already connected to another host (its HELLO_HOST
  /// reports a data port other than -1).
  final bool isAvailable;
  final int advertisingPort;

  @override
  String toString() => 'EmotiBit($deviceId @ ${address.address})';
}

enum EmotiBitConnectionStatus { connecting, connected, disconnected }

/// Host side of the EmotiBit WiFi protocol (what the EmotiBit Oscilloscope does).
///
/// Handshake (verified against EmotiBit_FeatherWing `EmotiBitWiFi.cpp`):
/// 1. Host sends `HE` to device UDP 3131; device answers `HH` with `DP,<port>,DI,<id>`.
/// 2. Host opens a TCP server (control port) and a UDP socket (data port),
///    then sends `EC` with `CP,<cp>,DP,<dp>` to device UDP 3131.
/// 3. Device connects to the host's TCP control port and replies `PO`.
/// 4. Device streams data packets over UDP to host data port.
/// 5. Host must send `PN` with `DP,<dp>` at least every 10 s or the device drops.
/// 6. Every ~5 s device sends `RD` (TL,TU) on data channel; host answers TL, TU, AK.
abstract final class EmotiBitHost {
  /// Broadcasts HELLO_EMOTIBIT and collects HELLO_HOST replies.
  ///
  /// [targets] defaults to the limited broadcast address. Pass explicit IPs
  /// for unicast discovery (useful on iOS without the multicast entitlement,
  /// or for the local simulator).
  static Future<List<DiscoveredEmotiBit>> discover({
    Duration timeout = const Duration(seconds: 2),
    List<InternetAddress>? targets,
    int advertisingPort = EmotiBitPorts.advertising,
    EmotiBitLogger? log,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final found = <String, DiscoveredEmotiBit>{};
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final text = utf8.decode(dg.data, allowMalformed: true);
      log?.call('← ${dg.address.address}:${dg.port}  ${text.trim()}');
      for (final p in EmotiBitPacket.parseAll(text)) {
        if (p.typeTag != TypeTag.helloHost) continue;
        final id = p.keyedValue(PayloadLabel.deviceId) ?? dg.address.address;
        final dp = int.tryParse(p.keyedValue(PayloadLabel.dataPort) ?? '');
        found[id] = DiscoveredEmotiBit(
          address: dg.address,
          deviceId: id,
          isAvailable: dp == null || dp == -1,
          advertisingPort: advertisingPort,
        );
      }
    });

    final hello = utf8.encode(
      EmotiBitPacket(timestamp: _now(), packetNumber: 0, typeTag: TypeTag.helloEmotibit).encode(),
    );
    final dests = targets ?? [InternetAddress('255.255.255.255')];
    // Send a few times: UDP is lossy.
    for (var i = 0; i < 3; i++) {
      for (final d in dests) {
        log?.call('→ ${d.address}:$advertisingPort  ${utf8.decode(hello).trim()}');
        socket.send(hello, d, advertisingPort);
      }
      await Future<void>.delayed(timeout ~/ 3);
    }
    await sub.cancel();
    socket.close();
    return found.values.toList();
  }

  static Future<EmotiBitConnection> connect(
    DiscoveredEmotiBit device, {
    Duration timeout = const Duration(seconds: 5),
    EmotiBitLogger? log,
  }) =>
      EmotiBitConnection._open(device, timeout, log);
}

/// A live connection to one EmotiBit.
class EmotiBitConnection {
  EmotiBitConnection._(this.device, this._control, this._data, this._adv, this._log);

  final DiscoveredEmotiBit device;
  final ServerSocket _control;
  final RawDatagramSocket _data;
  final RawDatagramSocket _adv;
  final EmotiBitLogger? _log;
  Socket? _controlClient;
  final _controlMessages = StreamController<EmotiBitPacket>.broadcast();

  /// Packets the device sends on the TCP control channel (rare; useful for
  /// diagnostics with real hardware).
  Stream<EmotiBitPacket> get controlMessages => _controlMessages.stream;

  final _packets = StreamController<EmotiBitPacket>.broadcast();
  final _status = StreamController<EmotiBitConnectionStatus>.broadcast();
  EmotiBitConnectionStatus _current = EmotiBitConnectionStatus.connecting;
  Timer? _pingTimer;
  DateTime _lastPong = DateTime.now();
  int _hostPacketNumber = 0;

  static const pingInterval = Duration(seconds: 2);
  static const pongTimeout = Duration(seconds: 10);

  /// Every packet received on the data channel (sensor data, derived metrics,
  /// battery, etc.), in arrival order.
  Stream<EmotiBitPacket> get packets => _packets.stream;
  Stream<EmotiBitConnectionStatus> get statusChanges => _status.stream;
  EmotiBitConnectionStatus get status => _current;

  int get controlPort => _control.port;
  int get dataPort => _data.port;

  static Future<EmotiBitConnection> _open(
      DiscoveredEmotiBit device, Duration timeout, EmotiBitLogger? log) async {
    final control = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final data = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final adv = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final conn = EmotiBitConnection._(device, control, data, adv, log);
    log?.call('Host: control TCP :${control.port}, datos UDP :${data.port}');
    try {
      await conn._handshake(timeout);
    } catch (_) {
      await conn.close(sendDisconnect: false);
      rethrow;
    }
    return conn;
  }

  Future<void> _handshake(Duration timeout) async {
    final accepted = Completer<Socket>();
    _control.listen((client) {
      _log?.call('Conexión TCP entrante de ${client.remoteAddress.address}:${client.remotePort}');
      if (!accepted.isCompleted &&
          client.remoteAddress.address == device.address.address) {
        accepted.complete(client);
      } else {
        client.destroy();
      }
    });

    _adv.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _adv.receive();
      if (dg == null) return;
      final text = utf8.decode(dg.data, allowMalformed: true);
      if (_current == EmotiBitConnectionStatus.connecting) _log?.call('← ${text.trim()}');
      for (final p in EmotiBitPacket.parseAll(text)) {
        if (p.typeTag == TypeTag.pong) _lastPong = DateTime.now();
      }
    });

    _data.listen(_onData);

    // Re-send EC until the device opens the control connection.
    final ec = _packet(TypeTag.emotibitConnect, [
      PayloadLabel.controlPort, '${_control.port}',
      PayloadLabel.dataPort, '${_data.port}',
    ]);
    _log?.call('→ ${device.address.address}:${device.advertisingPort}  ${ec.toString()}');
    final resend = Timer.periodic(const Duration(milliseconds: 500), (_) => _sendAdv(ec));
    _sendAdv(ec);
    try {
      _controlClient = await accepted.future.timeout(timeout);
    } on TimeoutException {
      throw EmotiBitException('El EmotiBit ${device.deviceId} no abrió la conexión de control');
    } finally {
      resend.cancel();
    }

    _controlClient!.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        _log?.call('Control ← $line');
        final p = EmotiBitPacket.tryParse(line);
        if (p != null && !_controlMessages.isClosed) _controlMessages.add(p);
      },
      onDone: () {
        _log?.call('El EmotiBit cerró la conexión de control');
        _setStatus(EmotiBitConnectionStatus.disconnected);
      },
      onError: (_) => _setStatus(EmotiBitConnectionStatus.disconnected),
    );

    _lastPong = DateTime.now();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (DateTime.now().difference(_lastPong) > pongTimeout) {
        _log?.call('Sin PONG por ${pongTimeout.inSeconds} s → desconectado');
        close(sendDisconnect: false);
        return;
      }
      _sendAdv(_packet(TypeTag.ping, [PayloadLabel.dataPort, '${_data.port}']));
    });
    _log?.call('Conectado a ${device.deviceId}');
    _setStatus(EmotiBitConnectionStatus.connected);
  }

  void _onData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _data.receive();
    if (dg == null) return;
    for (final p in EmotiBitPacket.parseAll(utf8.decode(dg.data, allowMalformed: true))) {
      if (p.typeTag == TypeTag.requestData) {
        _answerTimeSync(p, dg.address, dg.port);
      }
      if (!_packets.isClosed) _packets.add(p);
    }
  }

  /// Device asks for host time (TL = local, TU = UTC) every ~5 s and waits
  /// 100 ms for TL, TU and an AK carrying the RD packet number.
  void _answerTimeSync(EmotiBitPacket rd, InternetAddress addr, int port) {
    final now = DateTime.now();
    final reply = [
      _packet(TypeTag.timestampLocal, [formatEmotiBitTime(now)]),
      _packet(TypeTag.timestampUtc, [formatEmotiBitTime(now.toUtc())]),
      _packet(TypeTag.ack, ['${rd.packetNumber}', TypeTag.requestData]),
    ];
    for (final p in reply) {
      _data.send(utf8.encode(p.encode()), addr, port);
    }
  }

  /// Sends a packet over the reliable TCP control channel
  /// (e.g. user notes `UN`, `RB`/`RE` to record on the SD card, power modes).
  void sendControl(String typeTag, [List<String> payload = const []]) {
    _controlClient?.write(_packet(typeTag, payload).encode());
  }

  /// Adds a timestamped note to the device's own SD-card recording.
  void sendUserNote(String note) =>
      sendControl(TypeTag.userNote, [note.replaceAll(',', ';')]);

  Future<void> close({bool sendDisconnect = true}) async {
    if (_current == EmotiBitConnectionStatus.disconnected && _packets.isClosed) return;
    if (sendDisconnect) {
      sendControl(TypeTag.emotibitDisconnect);
      await _controlClient?.flush().catchError((_) {});
    }
    _pingTimer?.cancel();
    _controlClient?.destroy();
    await _control.close();
    _data.close();
    _adv.close();
    _setStatus(EmotiBitConnectionStatus.disconnected);
    await _packets.close();
    await _status.close();
    await _controlMessages.close();
  }

  void _sendAdv(EmotiBitPacket p) =>
      _adv.send(utf8.encode(p.encode()), device.address, device.advertisingPort);

  EmotiBitPacket _packet(String tag, List<String> payload) => EmotiBitPacket(
        timestamp: _now(),
        packetNumber: _hostPacketNumber++ & 0xFFFF,
        typeTag: tag,
        payload: payload,
      );

  void _setStatus(EmotiBitConnectionStatus s) {
    if (_current == s) return;
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }
}

/// Optional diagnostics sink: receives one human-readable line per event.
typedef EmotiBitLogger = void Function(String line);

class EmotiBitException implements Exception {
  EmotiBitException(this.message);
  final String message;
  @override
  String toString() => 'EmotiBitException: $message';
}

final _clock = Stopwatch()..start();
int _now() => _clock.elapsedMilliseconds;

/// `yyyy-MM-dd_HH-mm-ss-ffffff`, the timestamp style used in EmotiBit files.
String formatEmotiBitTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final micros = (t.millisecond * 1000 + t.microsecond).toString().padLeft(6, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}_${two(t.hour)}-${two(t.minute)}-${two(t.second)}-$micros';
}
