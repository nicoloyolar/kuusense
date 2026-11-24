import 'package:emotibit/emotibit.dart';
import 'package:test/test.dart';

void main() {
  test('rate, range and packet loss', () {
    final s = EmotiBitStats();
    // 15 Hz EDA: 3 samples every 200 ms, packet #2 is missing.
    var pn = 0;
    for (var i = 0; i <= 10; i++) {
      final p = pn++;
      if (p == 2) continue;
      s.add(EmotiBitPacket(
        timestamp: 1000 + i * 200,
        packetNumber: p,
        typeTag: TypeTag.eda,
        payload: ['1.0', '2.0', '3.0'],
      ));
    }
    final eda = s.tags[TypeTag.eda]!;
    expect(eda.minValue, 1.0);
    expect(eda.maxValue, 3.0);
    expect(eda.mean, 2.0);
    expect(eda.rateHz, closeTo(13.5, 0.1)); // one packet lost → slightly under 15
    expect(s.lostPackets, 1);
    expect(s.toTable(), contains('EA'));
  });

  test('packet counter wrap-around is not loss', () {
    final s = EmotiBitStats()
      ..add(const EmotiBitPacket(timestamp: 0, packetNumber: 65535, typeTag: 'EA'))
      ..add(const EmotiBitPacket(timestamp: 1, packetNumber: 0, typeTag: 'EA'));
    expect(s.lostPackets, 0);
  });
}
