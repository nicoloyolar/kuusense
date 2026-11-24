import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initKuusenseFirebase();
  runApp(KuusenseWeb(auth: FirebaseAuthService()));
}

class KuusenseWeb extends StatelessWidget {
  const KuusenseWeb({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KúuSense · Plataforma',
      debugShowCheckedModeBanner: false,
      theme: KuuTheme.light(),
      darkTheme: KuuTheme.dark(),
      home: StreamBuilder<String?>(
        stream: auth.userChanges,
        builder: (context, snap) {
          if (snap.data == null) return LoginScreen(auth: auth);
          // TODO(fase-0): researcher/admin home (NNA and sessions).
          return const Scaffold(body: Center(child: Text('Sesión iniciada')));
        },
      ),
    );
  }
}
