import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';

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

/// Yes/no dialog; resolves to true only when the user confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Centered spinner used while a stream has no data yet.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
