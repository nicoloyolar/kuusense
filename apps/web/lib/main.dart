import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'features/auth/login_screen.dart';
import 'features/dashboard/staff_gate.dart';
import 'firebase_options_test.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initKuusenseFirebase(
    productionOptions: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(KuusenseWeb(auth: FirebaseAuthService()));
}

class KuusenseWeb extends StatelessWidget {
  const KuusenseWeb({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KúuSense',
      debugShowCheckedModeBanner: false,
      theme: KuuTheme.light(),
      // Light only until the brand defines a dark mode (KuuTheme.dark() is kept).
      themeMode: ThemeMode.light,
      home: StreamBuilder<String?>(
        stream: auth.userChanges,
        builder: (context, snap) {
          final uid = snap.data;
          if (uid == null) return LoginScreen(auth: auth);
          // Keyed by user so a different account never sees the previous state.
          return StaffGate(key: ValueKey(uid), auth: auth);
        },
      ),
    );
  }
}
