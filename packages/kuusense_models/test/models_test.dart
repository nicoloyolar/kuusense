import 'dart:math';

import 'package:kuusense_models/kuusense_models.dart';
import 'package:test/test.dart';

// Must match codeChars() in firebase/firestore.rules.
final _ruleChild = RegExp(r'^N-[A-HJ-NP-Z2-9]{4}$');
final _ruleInvite = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

void main() {
  test('generated codes are accepted by the security rules', () {
    final rng = Random(1);
    for (var i = 0; i < 500; i++) {
      expect(Child.generateCode(rng), matches(_ruleChild));
      expect(Invite.generateCode(rng), matches(_ruleInvite));
    }
  });

  test('invite codes are normalized from user input', () {
    expect(Invite.normalize(' k7m-2pq '), 'K7M2PQ');
  });

  test('child round-trips without its private profile fields', () {
    final c = Child(
      id: 'c1',
      code: 'N-ABCD',
      birthYear: 2018,
      dunnQuadrant: DunnQuadrant.seeking,
      ownerUid: 'a',
      tutorUids: ['a', 'b'],
      consentConfirmedAtMs: 5,
      createdAtMs: 5,
    );
    final map = c.toMap();
    expect(map.keys, isNot(contains('displayName')));
    final back = Child.fromMap('c1', map);
    expect(back.dunnQuadrant, DunnQuadrant.seeking);
    expect(back.tutorUids, ['a', 'b']);
    expect(back.approximateAge(DateTime(2026)), 8);
  });

  test('invite expiry', () {
    final i = Invite(code: 'X', childId: 'c', createdByUid: 'a', createdAtMs: 0, expiresAtMs: 1000);
    expect(i.isExpired(DateTime.fromMillisecondsSinceEpoch(999)), isFalse);
    expect(i.isExpired(DateTime.fromMillisecondsSinceEpoch(1000)), isTrue);
  });

  test('session figures and signals.csv round-trip', () {
    const stats = SessionStats(
      heartRate: SignalRange(min: 54, mean: 65.2, max: 80),
      scrCount: 18,
      lossPercent: 0.8,
      batteryStart: 88,
      batteryEnd: 81,
    );
    final s = RecordingSession.fromMap('s', {'status': 'uploaded', 'stats': stats.toMap()});
    expect(s.stats!.heartRate!.mean, 65.2);
    expect(s.stats!.eda, isNull);
    expect(s.stats!.scrCount, 18);
    expect(RecordingSession.fromMap('s', {}).stats, isNull);

    final points = parseSignalsCsv(
      'host_epoch_ms,heart_rate,eda,temperature,motion,battery\n'
      '1000,60.0,3.0000,32.00,0.1000,90\n'
      '2000,,6.0000,,,\n',
    );
    expect(points, hasLength(2));
    expect(points.first.heartRate, 60.0);
    expect(points.last.heartRate, isNull);
    expect(points.last.eda, 6.0);
  });
}
