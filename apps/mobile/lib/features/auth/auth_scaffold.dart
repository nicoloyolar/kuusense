import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Common frame for the auth screens: the form sits on a [KuuFormCard] (same
/// as the web login). With [photoHeader] the brand photo and the light logo
/// top the screen (login); otherwise the regular logo over the brand
/// background. Optional back button and a help button (as in the mockups).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = false,
    this.photoHeader = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;
  final bool photoHeader;

  static const _photoHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = KuuFormCard(
      padding: KuuSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
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
    );
    final bottomBar = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KuuSpacing.sm,
        vertical: KuuSpacing.xs,
      ),
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
    );

    if (photoHeader) {
      final topInset = MediaQuery.paddingOf(context).top;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // light status bar over the photo
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: _photoHeight + topInset,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Top of the photo: faces, not the baked-in tagline.
                            KuuHeroPhoto(
                              alignment: const Alignment(0, -0.7),
                              fadeTo: theme.scaffoldBackgroundColor,
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: topInset + KuuSpacing.lg,
                              ),
                              child: const Align(
                                alignment: Alignment.topCenter,
                                child: KuusenseLogoOnBrand(height: 96),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The card overlaps the photo's faded bottom edge.
                      Transform.translate(
                        offset: const Offset(0, -KuuSpacing.xl * 1.5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KuuSpacing.md,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: card,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(top: false, child: bottomBar),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: KuuBrandBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KuuSpacing.md,
                      vertical: KuuSpacing.md,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const KuusenseLogo(height: 96),
                          const SizedBox(height: KuuSpacing.lg),
                          card,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottomBar,
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Entendido'),
      ),
    ],
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
          Expanded(
            child: Text(message!, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}

/// Primary button that shows a spinner while [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
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
