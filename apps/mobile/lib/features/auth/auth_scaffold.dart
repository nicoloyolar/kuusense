import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Common frame for the auth screens: brand background, logo, centered form,
/// optional back button and a help button (as in the mockups).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: KuuBrandBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.lg, vertical: KuuSpacing.md),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const KuusenseLogo(height: 120),
                          const SizedBox(height: KuuSpacing.lg),
                          Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                          if (subtitle != null) ...[
                            const SizedBox(height: KuuSpacing.sm),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: KuuSpacing.lg),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.sm, vertical: KuuSpacing.xs),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        tooltip: 'Volver',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Ayuda',
                      icon: const Icon(Icons.help_outline_rounded),
                      onPressed: () => showAuthHelp(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showAuthHelp(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Necesitas ayuda?'),
        // TODO(content): official support channel from the client.
        content: const Text(
          'Si tienes problemas para ingresar, escríbenos al canal de soporte de KúuSense.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );

/// Error line under a form; hidden when [message] is null.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: KuuSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
          const SizedBox(width: KuuSpacing.sm),
          Expanded(child: Text(message!, style: TextStyle(color: scheme.error))),
        ],
      ),
    );
  }
}

/// Primary button that shows a spinner while [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({super.key, required this.label, required this.busy, required this.onPressed});
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(label),
      );
}

/// Runs an auth action and converts failures to a user-facing message.
Future<String?> runAuthAction(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } on AuthFailure catch (e) {
    return e.message;
  } catch (_) {
    return const AuthFailure(AuthFailureReason.unknown).message;
  }
}
