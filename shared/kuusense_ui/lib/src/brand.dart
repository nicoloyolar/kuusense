import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

/// Paths of brand assets bundled in this package. Drop the official files in
/// `shared/kuusense_ui/assets/brand/` with these names and every app picks them up.
abstract final class KuuAssets {
  static const package = 'kuusense_ui';

  /// Full logo (symbol + wordmark), transparent PNG.
  /// PROVISIONAL: extracted from a low-res image; replace with the official file.
  static const logo = 'assets/brand/logo.png';

  /// Full logo for dark backgrounds (light wordmark).
  static const logoDark = 'assets/brand/logo_dark.png';

  /// Symbol only, square, transparent PNG.
  static const symbol = 'assets/brand/symbol.png';
}

/// The KúuSense logo. Until the official file exists it renders a text
/// wordmark in brand colors, so screens can be built now.
class KuusenseLogo extends StatelessWidget {
  const KuusenseLogo({super.key, this.height = 96, this.symbolOnly = false});

  final double height;
  final bool symbolOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = symbolOnly
        ? KuuAssets.symbol
        : (isDark ? KuuAssets.logoDark : KuuAssets.logo);
    return Semantics(
      label: 'KúuSense',
      image: true,
      child: Image.asset(
        asset,
        package: KuuAssets.package,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _Wordmark(height: height),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
      fontFamily: KuuFont.heading,
      fontSize: height * 0.42,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1,
    );
    return SizedBox(
      height: height,
      child: Center(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Kúu', style: style.copyWith(color: KuuColor.brandSecondary)),
            TextSpan(
              text: 'Sense',
              style: style.copyWith(color: isDark ? KuuColor.darkOnSurface : KuuColor.brandPrimary),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Soft blue/green backdrop used on welcome and auth screens, taken from the
/// logo palette. Falls back to the theme background in dark mode.
class KuuBrandBackground extends StatelessWidget {
  const KuuBrandBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [KuuColor.darkBackground, KuuColor.darkSurface]
              : [
                  KuuColor.lightSurface,
                  KuuColor.brandHighlight.withValues(alpha: 0.12),
                  KuuColor.brandSecondary.withValues(alpha: 0.12),
                ],
        ),
      ),
      child: child,
    );
  }
}
