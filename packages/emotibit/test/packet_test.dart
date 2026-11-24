import 'package:emotibit/emotibit.dart';
import 'package:test/test.dart';

void main() {
  test('parses a data packet', () {
    final p = EmotiBitPacket.tryParse('12345,7,3,EA,1,100,0.1,0.2,0.3')!;
    expect(p.timestamp, 12345);
    expect(p.packetNumber, 7);
    expect(p.typeTag, TypeTag.eda);
    expect(p.values, [0.1, 0.2, 0.3]);
  });

  test('HELLO_HOST payload is read even when dataLength is 0', () {
    final p = EmotiBitPacket.tryParse('100,1,0,HH,1,100,DP,-1,DI,MD-V5-0000123')!;
    expect(p.dataLength, 0);
    expect(p.keyedValue(PayloadLabel.deviceId), 'MD-V5-0000123');
    expect(p.keyedValue(PayloadLabel.dataPort), '-1');
  });

  test('splits multi-packet datagrams and skips garbage', () {
    final ps = EmotiBitPacket.parseAll('1,1,1,EA,1,100,2.0\nnot a packet\n2,2,1,HR,1,100,70\n');
    expect(ps.map((p) => p.typeTag), [TypeTag.eda, TypeTag.heartRate]);
  });

  test('encode round-trips', () {
    const p = EmotiBitPacket(timestamp: 5, packetNumber: 9, typeTag: 'EC', payload: ['CP', '1', 'DP', '2']);
    expect(p.encode(), '5,9,4,EC,1,100,CP,1,DP,2\n');
    expect(EmotiBitPacket.tryParse(p.encode())!.payload, p.payload);
  });

  test('packet without payload', () {
    expect(const EmotiBitPacket(timestamp: 1, packetNumber: 2, typeTag: 'HE').encode(), '1,2,0,HE,1,100\n');
  });
}
