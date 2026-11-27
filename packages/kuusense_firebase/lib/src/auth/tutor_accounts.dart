import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../bootstrap.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';

/// Creating someone else's account with the client SDK would sign the admin
/// out, so it runs on a second, throw-away Firebase app. No Cloud Functions
/// needed.
const _secondaryAppName = 'kuusense-accounts';

Future<T> _withSecondaryAuth<T>(
    Future<T> Function(FirebaseAuth auth) action) async {
  final app =
      Firebase.apps.where((a) => a.name == _secondaryAppName).firstOrNull ??
          await Firebase.initializeApp(
              name: _secondaryAppName, options: Firebase.app().options);
  final auth = FirebaseAuth.instanceFor(app: app);
  // The new tutor's sign-in must never be stored in the admin's browser.
  if (kIsWeb) await auth.setPersistence(Persistence.NONE);
  if (KuusenseEnv.useEmulators) {
    await auth.useAuthEmulator(KuusenseEnv.emulatorHost, 9099);
  }
  await auth.setLanguageCode('es');
  try {
    return await action(auth);
  } on FirebaseAuthException catch (e) {
    throw AuthFailure(authFailureReasonFor(e.code), e.code);
  } finally {
    await auth.signOut();
  }
}

/// Creates a sign-in account (tutor or researcher) for [email] with a random password nobody
/// knows, then emails the person a link to choose their own. Returns the new
/// account's uid.
Future<String> createAccount(String email) => _withSecondaryAuth((auth) async {
      // Test builds: the shared test password, so the team can enter any
      // account (choosing a new one would break that, so no email).
      const testPassword = KuusenseEnv.testPassword;
      final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: testPassword.isNotEmpty ? testPassword : _randomPassword());
      if (testPassword.isEmpty) {
        await auth.sendPasswordResetEmail(email: email);
      }
      return cred.user!.uid;
    });

/// Emails [email] a link to choose a (new) password.
Future<void> sendAccessEmail(String email) =>
    _withSecondaryAuth((auth) => auth.sendPasswordResetEmail(email: email));

String _randomPassword() {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!#%&*';
  final r = Random.secure();
  return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
}
