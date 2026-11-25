import 'package:emotibit/emotibit.dart';
import 'package:test/test.dart';

EmotiBitPacket _p(int ts, int pn, String tag, List<num> values) => EmotiBitPacket(
      timestamp: ts,
      packetNumber: pn,
      typeTag: tag,
      payload: [for (final v in values) '$v'],
    );

void main() {
  test('aggregates one row per second and whole-session figures', () {
    final b = SignalPreviewBuilder();
    const t0 = 1_700_000_000_000;
    b.add(_p(100, 1, TypeTag.eda, [2.0, 4.0]), t0 + 100);
    b.add(_p(200, 2, TypeTag.heartRate, [60]), t0 + 200);
    b.add(_p(300, 3, TypeTag.thermopile, [32.0]), t0 + 300);
    b.add(_p(400, 4, TypeTag.batteryPercent, [90]), t0 + 400);
    b.add(_p(500, 5, TypeTag.accelX, [0.0, 0.2]), t0 + 500);
    // Packet 6 lost; next second.
    b.add(_p(1100, 7, TypeTag.eda, [6.0]), t0 + 1100);
    b.add(_p(1200, 8, TypeTag.scrAmplitude, [0.5]), t0 + 1200);
    b.add(_p(1300, 9, TypeTag.batteryPercent, [89]), t0 + 1300);

    final rows = b.toCsv().trim().split('\n');
    expect(rows.first, SignalPreviewBuilder.csvHeader);
    expect(rows[1], '$t0,60.0,3.0000,32.00,0.1000,90');
    expect(rows[2], '${t0 + 1000},,6.0000,,,89');

    final st = b.statsJson();
    expect(st['eda'], {'min': 2.0, 'mean': 4.0, 'max': 6.0});
    expect(st['heartRate'], {'min': 60.0, 'mean': 60.0, 'max': 60.0});
    expect(st['scrCount'], 1);
    expect(st['batteryStart'], 90);
    expect(st['batteryEnd'], 89);
    expect(st['lossPercent'], 11.11); // 1 lost of 9 numbered
  });

  test('uses T0 for temperature when the device sends it', () {
    final b = SignalPreviewBuilder()
      ..add(_p(0, 1, TypeTag.temperature0, [36.0]), 0)
      ..add(_p(0, 2, TypeTag.thermopile, [30.0]), 0);
    expect(b.statsJson()['temperature'], {'min': 36.0, 'mean': 36.0, 'max': 36.0});
  });

  test('rebuilds from a recording, mapping device time with sync.csv', () {
    const raw = '1000,1,1,EA,1,100,5.0\n2000,2,1,EA,1,100,7.0\n';
    const sync = 'host_epoch_ms,device_ms\n10000,1000\n11000,2000\n';
    final b = SignalPreviewBuilder.fromRecording(raw, sync);
    final rows = b.toCsv().trim().split('\n');
    expect(rows.skip(1), ['10000,,5.0000,,,', '11000,,7.0000,,,']);
  });

  test('host time interpolates between sync pairs and survives a reboot', () {
    final sync = [(1000, 10000), (3000, 12000), (500, 13000), (1500, 14000)];
    expect(SignalPreviewBuilder.hostTimeFor(2000, sync), 11000);
    // After the reboot the device clock restarts; first matching segment wins,
    // so a value only inside the later segment maps there.
    expect(SignalPreviewBuilder.hostTimeFor(600, sync), 13100);
  });
}
