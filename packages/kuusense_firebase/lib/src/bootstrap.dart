import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration, passed with `--dart-define`:
///
///   USE_EMULATORS   true (default in debug) → local Firebase emulators, project
///                   `demo-kuusense`, no real Firebase project required.
///                   false → the real project in the app's
///                   `firebase_options_<env>.dart` (today: kuusense-test).
///                   Release builds default to false: an APK or web build
///                   must never point at a developer's emulators.
///   EMULATOR_HOST   host running `firebase emulators:start`. Defaults to
///                   localhost (10.0.2.2 on the Android emulator). Use your
///                   computer's LAN IP when running on a physical phone.
///   TEST_PASSWORD   test period only (kuusense-test builds): accounts the
///                   admin creates get this password and no access email.
///                   Never pass it to a production build.
abstract final class KuusenseEnv {
  static const testPassword = String.fromEnvironment('TEST_PASSWORD');

  static const useEmulators =
      bool.fromEnvironment('USE_EMULATORS', defaultValue: !kReleaseMode);
  static const _emulatorHost = String.fromEnvironment('EMULATOR_HOST');

  static String get emulatorHost {
    if (_emulatorHost.isNotEmpty) return _emulatorHost;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }
}

/// Options for the offline demo project. Values only need to be well-formed
/// because every call goes to the local emulators.
FirebaseOptions _demoOptions() {
  final platform = kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => 'web',
        };
  return FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:$platform:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-kuusense',
    storageBucket: 'demo-kuusense.appspot.com',
    iosBundleId: 'com.kuusense.kuusenseMobile',
  );
}

/// Initializes Firebase. [productionOptions] (from `flutterfire configure`) are
/// used only with `--dart-define=USE_EMULATORS=false`.
///
/// On the web the sign-in lives only in the browser tab (it survives a
/// reload but ends when the tab or browser is closed). The mobile app keeps
/// the tutor signed in until they sign out.
Future<void> initKuusenseFirebase({FirebaseOptions? productionOptions}) async {
  if (!KuusenseEnv.useEmulators) {
    if (productionOptions == null) {
      throw StateError(
          'USE_EMULATORS=false requires productionOptions (run flutterfire configure).');
    }
    await Firebase.initializeApp(options: productionOptions);
    await _webSessionOnly();
    return;
  }
  await Firebase.initializeApp(options: _demoOptions());
  await _webSessionOnly();
  final host = KuusenseEnv.emulatorHost;
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  debugPrint('Kuusense: using Firebase emulators at $host');
}

/// Web platform: never keep the sign-in after the tab/browser is closed.
Future<void> _webSessionOnly() async {
  if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
}
