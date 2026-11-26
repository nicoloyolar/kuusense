import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';

import '../children/children_home_screen.dart';
import '../common/feedback.dart';
import '../recording/recording_controller.dart';
import '../tutor/tutor_profile_screen.dart';

/// Everything after sign-in. Owns the per-user repository and recording
/// controller; asks for the tutor profile the first time.
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
        if (tutor == null) {
          return TutorProfileScreen(
            isOnboarding: true,
            initialName: widget.auth.currentDisplayName,
            onSave: (name, type) => repo.saveMyTutorProfile(displayName: name, type: type),
            onSignOut: _signOut,
          );
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
