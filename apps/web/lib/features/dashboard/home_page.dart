import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/data_table.dart';
import '../common/panel.dart';
import 'session_cells.dart';

/// Overview: key figures, the latest sessions and a summary per NNA.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.children,
    required this.sessions,
    required this.profiles,
    required this.onOpenSession,
    required this.onOpenChild,
    required this.onAllSessions,
  });

  final List<Child> children;
  final List<RecordingSession> sessions; // newest first
  final Map<String, ChildProfile> profiles;
  final ValueChanged<RecordingSession> onOpenSession;
  final ValueChanged<String> onOpenChild;
  final VoidCallback onAllSessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int daysAgo(int d) =>
        now.subtract(Duration(days: d)).millisecondsSinceEpoch;
    final week = sessions.where((s) => s.startedAtMs >= daysAgo(7)).toList();
    final month = sessions.where((s) => s.startedAtMs >= daysAgo(30)).toList();
    final hours = month.fold<Duration>(Duration.zero, (d, s) => d + s.duration);
    final crisesWeek = week
        .where((s) => SessionOutcome.of(s) == SessionOutcome.crisis)
        .length;
    final recording = sessions
        .where((s) => s.status == SessionStatus.recording)
        .length;
    final codes = {for (final c in children) c.id: c.code};

    final byChild = <String, List<RecordingSession>>{};
    for (final s in sessions) {
      byChild.putIfAbsent(s.childId, () => []).add(s);
    }

    final recent = KuuPanel(
      title: 'Sesiones recientes',
      action: TextButton(
        onPressed: onAllSessions,
        child: const Text('Ver todas'),
      ),
      padding: EdgeInsets.zero,
      child: _EmbeddedTable<RecordingSession>(
        rows: sessions.take(10).toList(),
        onRowTap: onOpenSession,
        emptyText: 'Aún no hay sesiones grabadas.',
        columns: [
          KuuColumn(
            label: 'NNA',
            flex: 3,
            cell: (s) => ChildCell(
              code: codes[s.childId] ?? '—',
              profile: profiles[s.childId],
            ),
          ),
          KuuColumn(label: 'Fecha', flex: 3, cell: (s) => SessionWhenCell(s)),
          KuuColumn(
            label: 'Duración',
            flex: 2,
            cell: (s) => Text(formatDuration(s.duration)),
          ),
          KuuColumn(
            label: 'Resultado',
            flex: 3,
            cell: (s) => SessionOutcomeBadge(s),
          ),
          KuuColumn(
            label: 'Estado',
            flex: 3,
            cell: (s) => SessionStateBadge(s),
          ),
        ],
      ),
    );

    final perChild = KuuPanel(
      title: 'Resumen por NNA',
      padding: EdgeInsets.zero,
      child: _EmbeddedTable<Child>(
        rows: children,
        onRowTap: (c) => onOpenChild(c.id),
        emptyText: 'Aún no hay NNA registrados.',
        columns: [
          KuuColumn(
            label: 'NNA',
            flex: 4,
            cell: (c) => ChildCell(code: c.code, profile: profiles[c.id]),
          ),
          KuuColumn(
            label: 'Sesiones 30 d',
            flex: 2,
            alignEnd: true,
            cell: (c) => Text(
              '${(byChild[c.id] ?? []).where((s) => s.startedAtMs >= daysAgo(30)).length}',
            ),
          ),
          KuuColumn(
            label: 'Última',
            flex: 2,
            cell: (c) {
              final last = byChild[c.id]?.first;
              return last == null
                  ? const MutedText('—')
                  : Text(formatDate(last.startedAtMs));
            },
          ),
        ],
      ),
    );

    return KuuPageBody(
      children: [
        const KuuPageHeader(
          title: 'Inicio',
          subtitle: 'Resumen de la actividad registrada en KúuSense.',
        ),
        const SizedBox(height: KuuSpacing.lg),
        KuuGrid(
          children: [
            KuuStatCard(
              label: 'NNA en seguimiento',
              value: '${children.length}',
              icon: Icons.diversity_1_rounded,
              color: KuuColor.brandPrimary,
            ),
            KuuStatCard(
              label: 'Sesiones (7 días)',
              value: '${week.length}',
              hint: recording > 0 ? '$recording grabando ahora' : null,
              icon: Icons.monitor_heart_rounded,
              color: KuuColor.brandHighlight,
            ),
            KuuStatCard(
              label: 'Horas registradas (30 días)',
              value: (hours.inMinutes / 60).toStringAsFixed(1),
              icon: Icons.schedule_rounded,
              color: KuuColor.brandSecondary,
            ),
            KuuStatCard(
              label: 'Crisis (7 días)',
              value: '$crisesWeek',
              icon: Icons.bolt_rounded,
              color: KuuColor.statePreCrisis,
            ),
          ],
        ),
        const SizedBox(height: KuuSpacing.lg),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 1100
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: recent),
                    const SizedBox(width: KuuSpacing.md),
                    Expanded(flex: 2, child: perChild),
                  ],
                )
              : Column(
                  children: [
                    recent,
                    const SizedBox(height: KuuSpacing.md),
                    perChild,
                  ],
                ),
        ),
      ],
    );
  }
}

/// A table without its own panel border (it sits inside a titled panel).
class _EmbeddedTable<T> extends StatelessWidget {
  const _EmbeddedTable({
    required this.rows,
    required this.columns,
    required this.onRowTap,
    required this.emptyText,
  });
  final List<T> rows;
  final List<KuuColumn<T>> columns;
  final ValueChanged<T> onRowTap;
  final String emptyText;

  @override
  Widget build(BuildContext context) => KuuDataTable<T>(
    columns: columns,
    rows: rows,
    onRowTap: onRowTap,
    emptyText: emptyText,
    minWidth: 480,
    embedded: true,
  );
}
