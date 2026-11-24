import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

/// Colors for the child's regulation state (traffic light), available in any
/// widget via `Theme.of(context).extension<KuuStateColors>()!`.
@immutable
class KuuStateColors extends ThemeExtension<KuuStateColors> {
  const KuuStateColors({required this.stable, required this.alert, required this.preCrisis});

  final Color stable;
  final Color alert;
  final Color preCrisis;

  static const standard = KuuStateColors(
    stable: KuuColor.stateStable,
    alert: KuuColor.stateAlert,
    preCrisis: KuuColor.statePreCrisis,
  );

  @override
  KuuStateColors copyWith({Color? stable, Color? alert, Color? preCrisis}) => KuuStateColors(
        stable: stable ?? this.stable,
        alert: alert ?? this.alert,
        preCrisis: preCrisis ?? this.preCrisis,
      );

  @override
  KuuStateColors lerp(KuuStateColors? other, double t) => other == null
      ? this
      : KuuStateColors(
          stable: Color.lerp(stable, other.stable, t)!,
          alert: Color.lerp(alert, other.alert, t)!,
          preCrisis: Color.lerp(preCrisis, other.preCrisis, t)!,
        );
}

/// Material theme built from the design tokens. Both apps use this so the
/// identity changes in one place (shared/design/tokens.json).
abstract final class KuuTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: KuuColor.lightBackground,
        surface: KuuColor.lightSurface,
        onSurface: KuuColor.lightOnSurface,
        muted: KuuColor.lightMuted,
        outline: KuuColor.lightOutline,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: KuuColor.darkBackground,
        surface: KuuColor.darkSurface,
        onSurface: KuuColor.darkOnSurface,
        muted: KuuColor.darkMuted,
        outline: KuuColor.darkOutline,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color muted,
    required Color outline,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      // In dark mode the navy primary lacks contrast; the turquoise leads.
      primary: isDark ? KuuColor.brandSecondary : KuuColor.brandPrimary,
      onPrimary: isDark ? KuuColor.darkBackground : Colors.white,
      secondary: isDark ? KuuColor.brandAccent : KuuColor.brandSecondary,
      onSecondary: KuuColor.lightOnSurface,
      tertiary: KuuColor.brandHighlight,
      onTertiary: KuuColor.lightOnSurface,
      error: KuuColor.feedbackError,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outline,
    );
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(KuuRadius.pill));
    final fieldRadius = BorderRadius.circular(KuuRadius.md);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: KuuFont.body,
      extensions: const [KuuStateColors.standard],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: KuuFont.body,
        bodyColor: onSurface,
        displayColor: onSurface,
      ).copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: KuuFont.heading,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: KuuFont.heading,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface.withValues(alpha: isDark ? 0.6 : 0.85),
        contentPadding: const EdgeInsets.symmetric(horizontal: KuuSpacing.md, vertical: 14),
        border: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(borderRadius: fieldRadius, borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: pill, minimumSize: const Size.fromHeight(48)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KuuRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
