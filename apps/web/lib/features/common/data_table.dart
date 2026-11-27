import 'package:flutter/material.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'panel.dart';

/// One column of a [KuuDataTable].
class KuuColumn<T> {
  const KuuColumn({
    required this.label,
    required this.cell,
    this.flex = 2,
    this.width,
    this.sortBy,
    this.alignEnd = false,
  });

  final String label;
  final Widget Function(T row) cell;

  /// Share of the free width (ignored when [width] is set).
  final int flex;

  /// Fixed width in logical pixels (e.g. for an actions column).
  final double? width;

  /// Value to sort by when the header is clicked; null = not sortable.
  final Comparable<Object?> Function(T row)? sortBy;

  /// Right-aligns numbers.
  final bool alignEnd;
}

/// The platform's standard data table: sortable headers, hover rows, row
/// click, pagination and an optional toolbar, inside a bordered panel.
/// Below [minWidth] it scrolls horizontally instead of squeezing columns.
class KuuDataTable<T> extends StatefulWidget {
  const KuuDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.toolbar,
    this.emptyText = 'No hay datos para mostrar.',
    this.pageSize = 10,
    this.minWidth = 880,
    this.initialSort,
    this.initialAscending = true,
    this.rowKey,
    this.embedded = false,
  });

  final List<KuuColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final Widget? toolbar;
  final String emptyText;
  final int pageSize;
  final double minWidth;

  /// Index of the column sorted at first (null keeps the given order).
  final int? initialSort;
  final bool initialAscending;
  final Object Function(T row)? rowKey;

  /// Inside another panel: no border of its own.
  final bool embedded;

  @override
  State<KuuDataTable<T>> createState() => _KuuDataTableState<T>();
}

/// Height of a one-line row (two-line cells may make rows taller).
const _rowHeight = 57.0;

class _KuuDataTableState<T> extends State<KuuDataTable<T>> {
  late int? _sort = widget.initialSort;
  late bool _asc = widget.initialAscending;
  int _page = 0;

  List<T> get _sorted {
    final i = _sort;
    final by = i == null ? null : widget.columns[i].sortBy;
    if (by == null) return widget.rows;
    final list = [...widget.rows]
      ..sort((a, b) {
        final c = by(a).compareTo(by(b));
        return _asc ? c : -c;
      });
    return list;
  }

  void _onSort(int i) => setState(() {
    if (_sort == i) {
      _asc = !_asc;
    } else {
      _sort = i;
      _asc = true;
    }
    _page = 0;
  });

  @override
  void didUpdateWidget(covariant KuuDataTable<T> old) {
    super.didUpdateWidget(old);
    final pages = (widget.rows.length / widget.pageSize).ceil();
    if (_page > 0 && _page >= pages) _page = (pages - 1).clamp(0, pages);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = _sorted;
    final total = rows.length;
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, total);
    final visible = rows.sublist(start.clamp(0, total), end);
    final pages = (total / widget.pageSize).ceil();

    Widget table(double width) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderRow<T>(
            columns: widget.columns,
            sort: _sort,
            ascending: _asc,
            onSort: _onSort,
            topBorder: widget.toolbar != null,
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KuuSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: KuuSpacing.sm),
                  Text(
                    widget.emptyText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final r in visible)
              _DataRow<T>(
                key: widget.rowKey == null ? null : ValueKey(widget.rowKey!(r)),
                columns: widget.columns,
                row: r,
                onTap: widget.onRowTap == null
                    ? null
                    : () => widget.onRowTap!(r),
              ),
            // Keep every page as tall as a full one, so paging never jumps.
            if (pages > 1 && visible.length < widget.pageSize)
              SizedBox(height: _rowHeight * (widget.pageSize - visible.length)),
          ],
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.toolbar != null)
          Padding(
            padding: const EdgeInsets.all(KuuSpacing.md),
            child: widget.toolbar,
          ),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= widget.minWidth
              ? table(c.maxWidth)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: table(widget.minWidth),
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KuuSpacing.md,
            vertical: KuuSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outline)),
          ),
          child: Row(
            children: [
              Text(
                total == 0
                    ? 'Sin resultados'
                    : 'Mostrando ${start + 1}–$end de $total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (pages > 1) ...[
                IconButton(
                  tooltip: 'Anterior',
                  visualDensity: VisualDensity.compact,
                  onPressed: _page == 0 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${_page + 1} de $pages',
                  style: theme.textTheme.bodySmall,
                ),
                IconButton(
                  tooltip: 'Siguiente',
                  visualDensity: VisualDensity.compact,
                  onPressed: _page >= pages - 1
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return widget.embedded
        ? content
        : KuuPanel(padding: EdgeInsets.zero, child: content);
  }
}

Widget _cellFrame<T>(KuuColumn<T> c, Widget child) {
  final aligned = Align(
    alignment: c.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
    child: child,
  );
  final padded = Padding(
    padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.md),
    child: aligned,
  );
  return c.width != null
      ? SizedBox(width: c.width, child: padded)
      : Expanded(flex: c.flex, child: padded);
}

class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.topBorder,
  });
  final bool topBorder;
  final List<KuuColumn<T>> columns;
  final int? sort;
  final bool ascending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: topBorder ? BorderSide(color: scheme.outline) : BorderSide.none,
          bottom: BorderSide(color: scheme.outline),
        ),
      ),
      child: Row(
        children: [
          for (final (i, c) in columns.indexed)
            _cellFrame(
              c,
              c.sortBy == null
                  ? Text(c.label.toUpperCase(), style: style)
                  : InkWell(
                      onTap: () => onSort(i),
                      borderRadius: BorderRadius.circular(KuuRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                c.label.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: style?.copyWith(
                                  color: sort == i ? scheme.primary : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              sort != i
                                  ? Icons.unfold_more_rounded
                                  : ascending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: sort == i
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _DataRow<T> extends StatefulWidget {
  const _DataRow({
    super.key,
    required this.columns,
    required this.row,
    this.onTap,
  });
  final List<KuuColumn<T>> columns;
  final T row;
  final VoidCallback? onTap;

  @override
  State<_DataRow<T>> createState() => _DataRowState<T>();
}

class _DataRowState<T> extends State<_DataRow<T>> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: _hover && widget.onTap != null
                ? scheme.primary.withValues(alpha: 0.04)
                : null,
            border: Border(
              bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: KuuSpacing.sm),
          child: Row(
            children: [
              for (final c in widget.columns)
                _cellFrame(
                  c,
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    child: c.cell(widget.row),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
