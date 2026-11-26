import 'dart:io';

import 'package:emotibit/emotibit.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('kuusense_rec'));
  tearDown(() => dir.delete(recursive: true));

  test('recover closes a recording left open by a killed app', () async {
    // What a killed app leaves behind: raw.csv with a half-written last
    // line, sync.csv, and no signals.csv.
    await File('${dir.path}/raw.csv').writeAsString(
      '1000,1,2,EA,1,100,0.5,0.6\n'
      '1100,2,1,HR,1,100,70.0\n'
      '1200,3,1,B%,1,100,88\n'
      '1300,4,2,EA,1,1',
    );
    await File('${dir.path}/sync.csv').writeAsString(
      'host_epoch_ms,device_ms\n'
      '5000000,1000\n'
      '5000200,1200\n',
    );

    final r = await SessionRecorder.recover(dir);
    expect(r, isNotNull);
    expect(r!.packetCount, 3);
    expect(r.tagsSeen, containsAll([TypeTag.eda, TypeTag.heartRate]));
    expect(r.endedAtMs, 5000200);

    final raw = await File('${dir.path}/raw.csv').readAsString();
    expect(raw.endsWith('1200,3,1,B%,1,100,88\n'), isTrue);
    expect(await File('${dir.path}/signals.csv').exists(), isTrue);
    expect(await File('${dir.path}/events.csv').exists(), isTrue);
    expect(r.files.every((f) => f.existsSync()), isTrue);
  });

  test('recover returns null without raw.csv', () async {
    expect(await SessionRecorder.recover(dir), isNull);
  });
}
