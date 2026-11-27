import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

/// KúuSense dialog standard, shared by the mobile app and the web platform:
/// blurred backdrop, soft scale-in, a tinted icon badge, centered title and
/// message, and full-width pill buttons.
///
/// - [showKuuConfirm]: yes/no questions (sign out, delete, leave…).
/// - [showKuuInfo]: a message with a single "Entendido".
/// - [KuuDialog] + [showKuuDialog]: custom content (e.g. a text field).
/// - [KuuFormDialog]: longer forms with a header and a close button.

/// What a dialog is about; sets the badge and main button colors.
enum KuuDialogTone {
  primary(KuuColor.brandPrimary),
  danger(KuuColor.feedbackError),
  warning(KuuColor.stateAlert),
  info(KuuColor.feedbackInfo),
  success(KuuColor.feedbackSuccess);

  const KuuDialogTone(this.color);
  final Color color;
}

/// Opens [builder] with the KúuSense backdrop and entrance animation.
Future<T?> showKuuDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: KuuColor.lightOnSurface.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6 * anim.value,
          sigmaY: 6 * anim.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Asks a yes/no question. Resolves to true only when confirmed.
Future<bool> showKuuConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  IconData icon = Icons.help_outline_rounded,
  KuuDialogTone tone = KuuDialogTone.primary,
}) async {
  final ok = await showKuuDialog<bool>(
    context,
    builder: (ctx) => KuuDialog(
      icon: icon,
      tone: tone,
      title: title,
      message: message,
      primaryLabel: confirmLabel,
      onPrimary: () => Navigator.of(ctx).pop(true),
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.of(ctx).pop(false),
    ),
  );
  return ok ?? false;
}

/// Shows a message with a single button.
Future<void> showKuuInfo(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'Entendido',
  IconData icon = Icons.info_outline_rounded,
  KuuDialogTone tone = KuuDialogTone.info,
}) => showKuuDialog<void>(
  context,
  builder: (ctx) => KuuDialog(
    icon: icon,
    tone: tone,
    title: title,
    message: message,
    primaryLabel: buttonLabel,
    onPrimary: () => Navigator.of(ctx).pop(),
  ),
);

/// The standard dialog card. [content] goes under the message (fields,
/// lists). The primary button fills the width; the secondary one sits
/// below it as a quieter option.
class KuuDialog extends StatelessWidget {
  const KuuDialog({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
    this.icon,
    this.tone = KuuDialogTone.primary,
    this.message,
    this.content,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  final IconData? icon;
  final KuuDialogTone tone;
  final String title;
  final String? message;
  final Widget? content;
  final String primaryLabel;

  /// Null disables the button.
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shows a spinner in the primary button and disables both.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _DialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KuuSpacing.lg,
          KuuSpacing.xl,
          KuuSpacing.lg,
          KuuSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Center(
                child: KuuIconBadge(icon: icon!, color: tone.color),
              ),
              const SizedBox(height: KuuSpacing.md),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: KuuSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: KuuSpacing.md),
              content!,
            ],
            const SizedBox(height: KuuSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tone.color,
                foregroundColor: tone == KuuDialogTone.warning
                    ? KuuColor.lightOnSurface
                    : KuuColor.lightSurface,
              ),
              onPressed: busy ? null : onPrimary,
              child: busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(primaryLabel),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: KuuSpacing.xs),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: scheme.onSurfaceVariant,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onPressed: busy ? null : onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog for longer forms: icon, title, close button and a scrollable
/// body that brings its own submit button.
class KuuFormDialog extends StatelessWidget {
  const KuuFormDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.maxWidth = 520,
  });
  final String title;
  final IconData? icon;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DialogShell(
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KuuSpacing.lg,
              KuuSpacing.lg,
              KuuSpacing.md,
              KuuSpacing.sm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  KuuIconBadge(
                    icon: icon!,
                    color: KuuColor.brandPrimary,
                    size: 44,
                  ),
                  const SizedBox(width: KuuSpacing.md),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                KuuSpacing.lg,
                KuuSpacing.sm,
                KuuSpacing.lg,
                KuuSpacing.lg,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon in a tinted circle with a soft halo.
class KuuIconBadge extends StatelessWidget {
  const KuuIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 64,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size + 16,
    height: size + 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.07),
    ),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    ),
  );
}

/// Rounded card that floats over the blurred backdrop.
class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.child, this.maxWidth = 400});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(KuuSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: KuuColor.lightOnSurface.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
