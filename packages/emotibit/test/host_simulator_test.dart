import 'dart:io';

import 'package:emotibit/emotibit.dart';
import 'package:test/test.dart';

/// End-to-end: host discovers, connects to and streams from the simulator over
/// real loopback sockets.
void main() {
  late EmotiBitSimulator sim;
  const port = 31310; // avoid clashing with a real simulator on 3131

  setUp(() async {
    sim = EmotiBitSimulator(advertisingPort: port, deviceId: 'TEST-1', seed: 1);
    await sim.start();
  });
  tearDown(() => sim.stop());

  test('a target that cannot be sent to does not stop discovery', () async {
    final found = await EmotiBitHost.discover(
      // An IPv6 address cannot be sent to from the IPv4 socket (throws).
      targets: [InternetAddress.loopbackIPv6, InternetAddress.loopbackIPv4],
      advertisingPort: port,
      timeout: const Duration(milliseconds: 600),
    );
    expect(found.map((d) => d.deviceId), ['TEST-1']);
  });

  test('discover → connect → stream → record → disconnect', () async {
    final found = await EmotiBitHost.discover(
      targets: [InternetAddress.loopbackIPv4],
      advertisingPort: port,
      timeout: const Duration(milliseconds: 600),
    );
    expect(found, hasLength(1));
    expect(found.single.deviceId, 'TEST-1');
    expect(found.single.isAvailable, isTrue);

    final conn = await EmotiBitHost.connect(found.single);
    expect(conn.status, EmotiBitConnectionStatus.connected);

    final dir = await Directory.systemTemp.createTemp('kuusense_test');
    final rec = await SessionRecorder.start(dir);
    final sub = conn.packets.listen(rec.add);
    final tags = await conn.packets
        .map((p) => p.typeTag)
        .take(200)
        .toSet();
    expect(tags, containsAll([TypeTag.eda, TypeTag.ppgGreen, TypeTag.accelZ]));

    rec.mark('estímulo A');
    await sub.cancel();
    await rec.stop();
    expect(rec.packetCount, greaterThan(100));
    final raw = await rec.rawFile.readAsLines();
    expect(EmotiBitPacket.tryParse(raw.first), isNotNull);
    expect(await rec.eventsFile.readAsString(), contains('estímulo A'));

    await conn.close();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(sim.isConnected, isFalse);
    await dir.delete(recursive: true);
  });

  test('a device that stops sending data is reported as disconnected', () async {
    final found = await EmotiBitHost.discover(
      targets: [InternetAddress.loopbackIPv4],
      advertisingPort: port,
      timeout: const Duration(milliseconds: 600),
    );
    final conn = await EmotiBitHost.connect(
      found.single,
      dataTimeout: const Duration(seconds: 1),
    );
    await conn.packets.first; // streaming
    final lost = conn.statusChanges
        .firstWhere((s) => s == EmotiBitConnectionStatus.disconnected);
    final pausedAt = DateTime.now();
    sim.pauseStreaming(); // control channel and PONGs stay alive
    await lost.timeout(const Duration(seconds: 4));
    expect(DateTime.now().difference(pausedAt), lessThan(const Duration(seconds: 3)));
    expect(conn.status, EmotiBitConnectionStatus.disconnected);
  });
}
