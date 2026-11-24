import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'features/auth/login_screen.dart';
import 'features/home/signed_in_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initKuusenseFirebase();
  runApp(KuusenseApp(auth: FirebaseAuthService()));
}

class KuusenseApp extends StatelessWidget {
  const KuusenseApp({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KúuSense',
      debugShowCheckedModeBanner: false,
      theme: KuuTheme.light(),
      darkTheme: KuuTheme.dark(),
      home: StreamBuilder<String?>(
        stream: auth.userChanges,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final uid = snap.data;
          if (uid == null) return LoginScreen(auth: auth);
          // Keyed by user so a different account never sees the previous state.
          return SignedInRoot(key: ValueKey(uid), auth: auth);
        },
      ),
    );
  }
}
