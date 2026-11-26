import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';

import '../children/children_home_screen.dart';
import '../common/feedback.dart';
import '../recording/recording_controller.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Everything after sign-in. Owns the per-user repository and recording
/// controller. Accounts without an active tutor profile (created by an admin
/// on the web platform) see a short explanation.
class SignedInRoot extends StatefulWidget {
  const SignedInRoot({super.key, required this.auth});
  final AuthService auth;

  @override
  State<SignedInRoot> createState() => _SignedInRootState();
}

class _SignedInRootState extends State<SignedInRoot> {
  final repo = KuusenseRepository();
  late final recording = RecordingController(repo);
  late final Stream<Tutor?> _tutor = repo.watchMyTutorProfile();

  @override
  void initState() {
    super.initState();
    // Recover and upload sessions left on the phone (no internet, app closed).
    recording.startUploads();
  }

  @override
  void dispose() {
    recording.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    Navigator.of(context).popUntil((r) => r.isFirst);
    await recording.disconnect();
    await widget.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tutor?>(
      stream: _tutor,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(genericErrorMessage, textAlign: TextAlign.center),
                  TextButton(onPressed: _signOut, child: const Text('Cerrar sesión')),
                ],
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) return const LoadingView();
        final tutor = snap.data;
        if (tutor == null || !tutor.active) {
          return _NotEnabled(deactivated: tutor != null, onSignOut: _signOut);
        }
        return ChildrenHomeScreen(
          repo: repo,
          recording: recording,
          tutor: tutor,
          onSignOut: _signOut,
        );
      },
    );
  }
}

class _NotEnabled extends StatelessWidget {
  const _NotEnabled({required this.deactivated, required this.onSignOut});
  final bool deactivated;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: KuuBrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KuuSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KuusenseLogo(height: 96),
                    const SizedBox(height: KuuSpacing.lg),
                    Text(
                      deactivated ? 'Tu cuenta está desactivada' : 'Tu cuenta no está habilitada',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: KuuSpacing.sm),
                    Text(
                      'Contacta al administrador de KúuSense para que habilite tu cuenta de tutor.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: KuuSpacing.lg),
                    OutlinedButton(onPressed: onSignOut, child: const Text('Cerrar sesión')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
