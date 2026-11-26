import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

const genericErrorMessage = 'No se pudo completar la acción. Revisa tu conexión e inténtalo de nuevo.';

/// User-facing message for an error thrown by the repository or auth.
String errorMessage(Object error) => switch (error) {
      InviteFailure e => e.message,
      AuthFailure e => e.message,
      _ => genericErrorMessage,
    };

/// Runs [action]; on failure shows a snack bar and returns false.
Future<bool> runWithFeedback(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } catch (e, st) {
    debugPrint('action failed: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    return false;
  }
}

/// Yes/no dialog with the KúuSense standard ([showKuuConfirm]); resolves to
/// true only when the user confirms. [destructive] paints it as a danger.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  IconData? icon,
}) =>
    showKuuConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon ?? (destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
      tone: destructive ? KuuDialogTone.danger : KuuDialogTone.primary,
    );

/// Centered spinner used while a stream has no data yet.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
