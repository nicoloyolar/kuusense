import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';
import 'theme.dart';

/// Paths of brand assets bundled in this package. Drop the official files in
/// `shared/kuusense_ui/assets/brand/` with these names and every app picks them up.
abstract final class KuuAssets {
  static const package = 'kuusense_ui';

  /// Stacked logo (symbol over wordmark), transparent PNG. Extracted from
  /// the official JPG; replace with the client's PNG/SVG when available.
  static const logo = 'assets/brand/logo.png';

  /// Stacked logo for dark backgrounds (light wordmark).
  static const logoDark = 'assets/brand/logo_dark.png';

  /// Horizontal logo (symbol beside wordmark), for headers.
  static const logoHorizontal = 'assets/brand/logo_horizontal.png';
  static const logoHorizontalDark = 'assets/brand/logo_horizontal_dark.png';

  /// Brand photo (family with tablet, tagline "Tecnología para acompañar"
  /// baked in). PROVISIONAL low-res copy; replace with the original file.
  static const heroFamily = 'assets/images/hero_family.png';

  /// Symbol only, square, transparent PNG.
  static const symbol = 'assets/brand/symbol.png';
}

/// The KúuSense logo. Until the official file exists it renders a text
/// wordmark in brand colors, so screens can be built now.
class KuusenseLogo extends StatelessWidget {
  const KuusenseLogo({
    super.key,
    this.height = 96,
    this.symbolOnly = false,
    this.horizontal = false,
  });

  final double height;
  final bool symbolOnly;

  /// Symbol beside the wordmark, for headers.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = symbolOnly
        ? KuuAssets.symbol
        : horizontal
        ? (isDark ? KuuAssets.logoHorizontalDark : KuuAssets.logoHorizontal)
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
          TextSpan(
            children: [
              TextSpan(
                text: 'Kúu',
                style: style.copyWith(color: KuuColor.brandSecondary),
              ),
              TextSpan(
                text: 'Sense',
                style: style.copyWith(
                  color: isDark
                      ? KuuColor.darkOnSurface
                      : KuuColor.brandPrimary,
                ),
              ),
            ],
          ),
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

/// The brand photo with a navy fade at the top (so a light logo reads over
/// it) and, optionally, a fade into [fadeTo] at the bottom. Used by the web
/// login panel and the mobile login header so both share one look.
class KuuHeroPhoto extends StatelessWidget {
  const KuuHeroPhoto({
    super.key,
    this.alignment = const Alignment(0, 0.8),
    this.fadeTo,
  });

  /// Which part of the photo stays visible when it is cropped.
  final Alignment alignment;

  /// Page color to blend into at the bottom edge; null for no bottom fade.
  final Color? fadeTo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: KuuColor.brandPrimary),
        Image.asset(
          KuuAssets.heroFamily,
          package: KuuAssets.package,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.38, 0.6],
              colors: [
                KuuColor.brandPrimary.withValues(alpha: 0.92),
                KuuColor.brandPrimary.withValues(alpha: 0.35),
                KuuColor.brandPrimary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        if (fadeTo != null)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.65, 1],
                colors: [fadeTo!.withValues(alpha: 0), fadeTo!],
              ),
            ),
          ),
      ],
    );
  }
}

/// The light logo, for use over the brand photo or other navy surfaces.
class KuusenseLogoOnBrand extends StatelessWidget {
  const KuusenseLogoOnBrand({
    super.key,
    this.height = 96,
    this.horizontal = false,
  });
  final double height;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => Theme(
    data: KuuTheme.dark(),
    child: KuusenseLogo(height: height, horizontal: horizontal),
  );
}

/// Raised card that holds the auth forms on web and mobile.
class KuuFormCard extends StatelessWidget {
  const KuuFormCard({
    super.key,
    required this.child,
    this.padding = KuuSpacing.xl,
  });
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 6,
    shadowColor: KuuColor.brandPrimary.withValues(alpha: 0.18),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}
