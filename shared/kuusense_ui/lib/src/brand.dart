import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

/// Paths of brand assets bundled in this package. Drop the official files in
/// `shared/kuusense_ui/assets/brand/` with these names and every app picks them up.
abstract final class KuuAssets {
  static const package = 'kuusense_ui';

  /// Full logo (mascot + wordmark), transparent PNG.
  static const logo = 'assets/brand/logo.png';

  /// Mascot / symbol only, square, transparent PNG.
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
    return Semantics(
      label: 'KúuSense',
      image: true,
      child: Image.asset(
        symbolOnly ? KuuAssets.symbol : KuuAssets.logo,
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

/// Soft lilac/turquoise backdrop used on welcome and auth screens
/// (matches the mockups). Falls back to the theme background in dark mode.
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
                  KuuColor.lightBackground,
                  KuuColor.brandAccent.withValues(alpha: 0.35),
                  KuuColor.brandSecondary.withValues(alpha: 0.18),
                ],
        ),
      ),
      child: child,
    );
  }
}
