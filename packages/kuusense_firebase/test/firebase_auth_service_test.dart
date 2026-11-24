import 'package:flutter_test/flutter_test.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';

void main() {
  test('Firebase Auth error codes map to user-facing reasons', () {
    expect(authFailureReasonFor('invalid-credential'), AuthFailureReason.invalidCredentials);
    expect(authFailureReasonFor('user-not-found'), AuthFailureReason.invalidCredentials);
    expect(authFailureReasonFor('email-already-in-use'), AuthFailureReason.emailAlreadyInUse);
    expect(authFailureReasonFor('network-request-failed'), AuthFailureReason.network);
    expect(authFailureReasonFor('something-new'), AuthFailureReason.unknown);
  });

  test('invite failures have Spanish messages', () {
    for (final r in InviteFailureReason.values) {
      expect(InviteFailure(r).message, isNotEmpty);
    }
  });
}
