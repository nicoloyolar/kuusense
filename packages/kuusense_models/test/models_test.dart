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
}
