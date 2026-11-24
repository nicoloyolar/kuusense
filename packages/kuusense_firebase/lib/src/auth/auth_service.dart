/// Authentication contract used by the login screens of both apps.
///
/// Screens depend only on this interface. Integrating Firebase Auth means
/// writing one implementation (e.g. `FirebaseAuthService`) and passing it in
/// each app's `main.dart` instead of [NotConfiguredAuthService].
abstract interface class AuthService {
  /// Current signed-in user id, or null.
  String? get currentUserId;

  /// Name given at sign-up, if any (used to prefill the tutor profile).
  String? get currentDisplayName;

  /// Emits the user id on sign-in and null on sign-out.
  Stream<String?> get userChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}

/// Failure reasons the UI knows how to explain. Implementations map their
/// provider-specific errors (e.g. Firebase `auth/wrong-password`) to these.
enum AuthFailureReason {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  network,
  notConfigured,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason, [this.detail]);

  final AuthFailureReason reason;
  final String? detail;

  /// User-facing message in Spanish (Chile).
  String get message => switch (reason) {
        AuthFailureReason.invalidCredentials => 'Correo o contraseña incorrectos.',
        AuthFailureReason.emailAlreadyInUse => 'Ya existe una cuenta con ese correo.',
        AuthFailureReason.weakPassword => 'La contraseña es muy débil.',
        AuthFailureReason.invalidEmail => 'El correo no es válido.',
        AuthFailureReason.userDisabled => 'Esta cuenta está deshabilitada.',
        AuthFailureReason.tooManyRequests => 'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
        AuthFailureReason.network => 'Sin conexión. Revisa tu internet.',
        AuthFailureReason.notConfigured => 'El inicio de sesión aún no está disponible.',
        AuthFailureReason.unknown => 'Ocurrió un error inesperado. Inténtalo de nuevo.',
      };

  @override
  String toString() => 'AuthFailure($reason${detail == null ? '' : ': $detail'})';
}

/// Placeholder until Firebase Auth is integrated: every action fails with
/// [AuthFailureReason.notConfigured] so the screens can be built and navigated.
class NotConfiguredAuthService implements AuthService {
  const NotConfiguredAuthService();

  static const _failure = AuthFailure(AuthFailureReason.notConfigured);

  @override
  String? get currentUserId => null;

  @override
  String? get currentDisplayName => null;

  @override
  Stream<String?> get userChanges => Stream.value(null);

  @override
  Future<void> signIn({required String email, required String password}) async => throw _failure;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      throw _failure;

  @override
  Future<void> sendPasswordReset({required String email}) async => throw _failure;

  @override
  Future<void> signOut() async {}
}
