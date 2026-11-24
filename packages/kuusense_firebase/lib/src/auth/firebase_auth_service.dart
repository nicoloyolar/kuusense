import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

/// [AuthService] backed by Firebase Auth (email and password).
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentDisplayName => _auth.currentUser?.displayName;

  @override
  Stream<String?> get userChanges => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        await cred.user?.updateDisplayName(displayName);
      });

  @override
  Future<void> sendPasswordReset({required String email}) => _guard(() async {
        try {
          await _auth.sendPasswordResetEmail(email: email);
        } on FirebaseAuthException catch (e) {
          // Do not reveal whether an account exists for this email.
          if (e.code != 'user-not-found') rethrow;
        }
      });

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authFailureReasonFor(e.code), e.code);
    }
  }
}

/// Maps Firebase Auth error codes to the reasons the UI can explain.
AuthFailureReason authFailureReasonFor(String code) => switch (code) {
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' ||
      'user-not-found' =>
        AuthFailureReason.invalidCredentials,
      'email-already-in-use' => AuthFailureReason.emailAlreadyInUse,
      'weak-password' => AuthFailureReason.weakPassword,
      'invalid-email' => AuthFailureReason.invalidEmail,
      'user-disabled' => AuthFailureReason.userDisabled,
      'too-many-requests' => AuthFailureReason.tooManyRequests,
      'network-request-failed' => AuthFailureReason.network,
      _ => AuthFailureReason.unknown,
    };
