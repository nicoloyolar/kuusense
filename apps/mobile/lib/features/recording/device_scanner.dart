import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emotibit/emotibit.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// An EmotiBit seen on the network, and when it last answered.
class ScannedEmotiBit {
  ScannedEmotiBit(this.device, this.lastSeen);
  final DiscoveredEmotiBit device;
  final DateTime lastSeen;
}

/// Looks for EmotiBits continuously while a screen needs it (like a
/// Bluetooth device list): devices appear as they answer and disappear when
/// they stop answering. Besides the network broadcast, it also asks the last
/// device used and an optional manual IP directly, because some networks
/// (and iPhones) drop broadcasts.
class DeviceScanner extends ChangeNotifier {
  DeviceScanner({this.forgetAfter = const Duration(seconds: 12)});

  /// A device that has not answered for this long leaves the list.
  final Duration forgetAfter;
  static const _pause = Duration(milliseconds: 800);
  static final _broadcast = InternetAddress('255.255.255.255');

  final Map<String, ScannedEmotiBit> _seen = {};
  bool _running = false;
  bool _paused = false;
  int _run = 0;
  DateTime? _startedAt;
  InternetAddress? _manualIp;

  /// The device used most recently on this phone (id and IP), if any.
  LastEmotiBit? lastDevice;

  bool get isRunning => _running;

  /// How long the current search has been running (for "taking long" hints).
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Devices found, the last used one first, then by id.
  List<DiscoveredEmotiBit> get devices {
    final list = _seen.values.map((s) => s.device).toList()
      ..sort((a, b) {
        final la = a.deviceId == lastDevice?.deviceId ? 0 : 1;
        final lb = b.deviceId == lastDevice?.deviceId ? 0 : 1;
        return la != lb ? la - lb : a.deviceId.compareTo(b.deviceId);
      });
    return list;
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _paused = false;
    _startedAt = DateTime.now();
    lastDevice ??= await LastEmotiBit.load();
    notifyListeners();
    unawaited(_loop(++_run));
  }

  void stop() {
    _running = false;
    _run++;
    notifyListeners();
  }

  /// Holds the search while connecting (keeps the network quiet).
  void pause() => _paused = true;
  void resume() => _paused = false;

  /// Also asks this IP directly on every round (from "connect by IP").
  void setManualIp(String? ip) {
    final text = ip?.trim() ?? '';
    _manualIp = text.isEmpty ? null : InternetAddress.tryParse(text);
    _startedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _loop(int run) async {
    while (_running && run == _run) {
      if (!_paused) {
        final targets = <InternetAddress>{
          ?lastDevice?.address,
          ?_manualIp,
          ...await _localSubnet(),
          _broadcast,
        }.toList();
        try {
          final found = await EmotiBitHost.discover(targets: targets);
          if (!_running || run != _run) return;
          final now = DateTime.now();
          for (final d in found) {
            _seen[d.deviceId] = ScannedEmotiBit(d, now);
          }
          _seen.removeWhere((_, s) => now.difference(s.lastSeen) > forgetAfter);
          notifyListeners();
        } catch (e) {
          debugPrint('EmotiBit scan failed: $e');
        }
      }
      await Future<void>.delayed(_pause);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Every address of the phone's local networks, to ask each one directly.
  /// iOS drops broadcasts from apps without Apple's multicast entitlement,
  /// so this is how an iPhone finds the EmotiBit (also on its own hotspot,
  /// 172.20.10.0/28). Other networks are swept as /24.
  static Future<List<InternetAddress>> _localSubnet() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final out = <InternetAddress>[];
      for (final i in interfaces) {
        for (final a in i.addresses) {
          final b = a.rawAddress;
          final private =
              b[0] == 10 ||
              (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
              (b[0] == 192 && b[1] == 168);
          if (!private) continue;
          final hotspot = b[0] == 172 && b[1] == 20 && b[2] == 10;
          final last = hotspot ? 14 : 254;
          final first = hotspot ? (b[3] & 0xF0) + 1 : 1;
          for (
            var h = first;
            h <= (hotspot ? (b[3] & 0xF0) + last : last);
            h++
          ) {
            if (h == b[3]) continue;
            out.add(InternetAddress('${b[0]}.${b[1]}.${b[2]}.$h'));
          }
        }
      }
      return out;
    } catch (e) {
      debugPrint('Local network list failed: $e');
      return const [];
    }
  }
}

/// The EmotiBit last connected on this phone, kept in a small file so the
/// search can ask it directly and list it first.
class LastEmotiBit {
  const LastEmotiBit(this.deviceId, this.ip);
  final String deviceId;
  final String ip;

  InternetAddress? get address => InternetAddress.tryParse(ip);

  static Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/last_emotibit.json',
  );

  static Future<LastEmotiBit?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return LastEmotiBit(m['deviceId'] as String, m['ip'] as String);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(DiscoveredEmotiBit d) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode({'deviceId': d.deviceId, 'ip': d.address.address}),
      );
    } catch (e) {
      debugPrint('Could not remember the EmotiBit: $e');
    }
  }
}
