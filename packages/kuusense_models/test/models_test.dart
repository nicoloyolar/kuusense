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

  test('private profile keeps the full birth date and gives the exact age', () {
    final p = ChildProfile.fromMap(
        {'displayName': 'Tomi', 'avatarId': 'sun', 'birthDate': '2018-03-14'});
    expect(p.birthDateValue, DateTime(2018, 3, 14));
    expect(p.exactAge(DateTime(2026, 3, 13)), 7);
    expect(p.exactAge(DateTime(2026, 3, 14)), 8);
    expect(p.toMap()['birthDate'], '2018-03-14');
    expect(ChildProfile.formatBirthDate(DateTime(1985, 1, 5)), '1985-01-05');
  });

  test('older profiles without a birth date and malformed dates', () {
    final old =
        ChildProfile.fromMap({'displayName': 'Tomi', 'avatarId': 'sun'});
    expect(old.exactAge(), isNull);
    expect(old.toMap().containsKey('birthDate'), isFalse);
    expect(ChildProfile.parseBirthDate('2020-02-31'), isNull);
    expect(ChildProfile.parseBirthDate('14-03-2018'), isNull);
  });

  test('invite expiry', () {
    final i = Invite(
        code: 'X',
        childId: 'c',
        createdByUid: 'a',
        createdAtMs: 0,
        expiresAtMs: 1000);
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
    final s = RecordingSession.fromMap(
        's', {'status': 'uploaded', 'stats': stats.toMap()});
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

  test('session end reason and gaps round-trip; old sessions stay complete',
      () {
    final s = RecordingSession.fromMap('s', {
      'status': 'uploaded',
      'endReason': 'deviceLost',
      'gaps': [
        {'fromMs': 1000, 'toMs': 4000},
      ],
    });
    expect(s.endReason, SessionEndReason.deviceLost);
    expect(s.isIncomplete, isTrue);
    expect(s.gaps.single.duration, const Duration(seconds: 3));
    final back = RecordingSession.fromMap('s', s.toMap());
    expect(back.endReason, SessionEndReason.deviceLost);
    expect(back.gaps.single.toMs, 4000);

    final old = RecordingSession.fromMap('s', {'status': 'uploaded'});
    expect(old.endReason, isNull);
    expect(old.isIncomplete, isFalse);
    expect(old.gaps, isEmpty);
    expect(old.toMap().containsKey('endReason'), isFalse);
    expect(
      RecordingSession.fromMap('s', {'endReason': 'stopped'}).isIncomplete,
      isFalse,
    );
  });

  test('tutors created before email/active existed read as active', () {
    final old = Tutor.fromMap(
        'u', {'displayName': 'Ana', 'type': 'teacher', 'createdAtMs': 1});
    expect(old.active, isTrue);
    expect(old.email, '');
    final t = Tutor(
        uid: 'u',
        displayName: 'Ana',
        type: TutorType.family,
        createdAtMs: 1,
        email: 'a@b.cl',
        active: false);
    final back = Tutor.fromMap('u', t.toMap());
    expect(back.email, 'a@b.cl');
    expect(back.active, isFalse);
  });
}
