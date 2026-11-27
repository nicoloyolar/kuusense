import 'package:flutter/material.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// White bordered container: the base block of every panel page.
class KuuPanel extends StatelessWidget {
  const KuuPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KuuSpacing.lg),
    this.title,
    this.action,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional header shown above [child], with a divider.
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(KuuRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(
                KuuSpacing.md,
                KuuSpacing.sm,
                KuuSpacing.sm,
                KuuSpacing.sm,
              ),
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Page title row: breadcrumbs, title, subtitle and actions on the right.
class KuuPageHeader extends StatelessWidget {
  const KuuPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumbs = const [],
    this.actions = const [],
  });
  final String title;
  final String? subtitle;

  /// Earlier levels, e.g. [('Sesiones', goBack)].
  final List<(String, VoidCallback)> breadcrumbs;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: KuuSpacing.md,
      spacing: KuuSpacing.lg,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (breadcrumbs.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (label, onTap) in breadcrumbs) ...[
                    InkWell(
                      onTap: onTap,
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KuuSpacing.xs),
            ],
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: KuuSpacing.sm,
            runSpacing: KuuSpacing.sm,
            children: actions,
          ),
      ],
    );
  }
}

/// Compact KPI: label, big value, optional hint and an icon.
class KuuStatCard extends StatelessWidget {
  const KuuStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return KuuPanel(
      padding: const EdgeInsets.all(KuuSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: KuuSpacing.xs),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          KuuIconTile(icon: icon, color: color, size: 44),
        ],
      ),
    );
  }
}

/// Lays out [children] in equal columns that wrap on narrow screens.
class KuuGrid extends StatelessWidget {
  const KuuGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.maxColumns = 4,
  });
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = (c.maxWidth / minItemWidth).floor().clamp(1, maxColumns);
      final w = (c.maxWidth - KuuSpacing.md * (cols - 1)) / cols;
      return Wrap(
        spacing: KuuSpacing.md,
        runSpacing: KuuSpacing.md,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    },
  );
}

/// Small colored status label with a dot (Activo, Subida, Crisis…).
class KuuStatusBadge extends StatelessWidget {
  const KuuStatusBadge(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.sm, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(KuuRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// Search box for table toolbars.
class KuuSearchField extends StatelessWidget {
  const KuuSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.width = 300,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
      ),
    ),
  );
}

/// Compact dropdown filter for table toolbars.
class KuuFilter<T> extends StatelessWidget {
  const KuuFilter({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 200,
  });
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final (v, l) in options)
          DropdownMenuItem(
            value: v,
            child: Text(l, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => onChanged(v as T),
    ),
  );
}

/// Toolbar row above a table: filters on the left, extra on the right.
class KuuToolbar extends StatelessWidget {
  const KuuToolbar({super.key, required this.children, this.trailing});
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Wrap(
          spacing: KuuSpacing.sm,
          runSpacing: KuuSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
      ?trailing,
    ],
  );
}

/// Scrollable page body with the standard padding, using the full width.
class KuuPageBody extends StatelessWidget {
  const KuuPageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      KuuSpacing.xl,
      KuuSpacing.lg,
      KuuSpacing.xl,
      KuuSpacing.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
