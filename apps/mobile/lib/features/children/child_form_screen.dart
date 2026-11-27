import 'package:flutter/material.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

export 'package:kuusense_ui/kuusense_ui.dart' show ChildFormData;

/// Registers a new child or edits one, with the shared [KuuChildForm]
/// (same form as the web platform). Pops `true` once saved.
class ChildFormScreen extends StatelessWidget {
  const ChildFormScreen({
    super.key,
    required this.onSubmit,
    this.initial,
    this.now,
  });

  /// Null when registering a new child.
  final ChildFormData? initial;
  final Future<void> Function(ChildFormData data) onSubmit;

  /// Clock override for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(initial == null ? 'Registrar niño/a' : 'Editar datos'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KuuSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: KuuChildForm(
                initial: initial,
                now: now,
                onSubmit: (data) async {
                  final ok = await runWithFeedback(
                    context,
                    () => onSubmit(data),
                  );
                  if (ok && context.mounted) Navigator.of(context).pop(true);
                  return ok;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
