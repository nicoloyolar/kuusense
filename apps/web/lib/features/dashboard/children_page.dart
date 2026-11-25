import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Home of the platform: summary figures and one card per NNA (pseudonymous
/// code only, never names) in a responsive grid (3 / 2 / 1 columns).
class ChildrenPage extends StatelessWidget {
  const ChildrenPage({
    super.key,
    required this.children,
    required this.sessions,
    required this.onOpen,
  });
  final List<Child> children;
  final List<RecordingSession> sessions;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byChild = <String, List<RecordingSession>>{};
    for (final s in sessions) {
      byChild.putIfAbsent(s.childId, () => []).add(s); // newest first
    }
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final lastWeek = sessions.where((s) => s.startedAtMs >= weekAgo).toList();
    final crisesWeek = lastWeek
        .where((s) => SessionOutcome.of(s) == SessionOutcome.crisis)
        .length;
    final markedEvents = sessions.fold<int>(0, (n, s) => n + s.events.length);

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth.clamp(0.0, 1280.0) - KuuSpacing.lg * 2;
        final columns = width >= 1000 ? 3 : (width >= 640 ? 2 : 1);
        final statColumns = width >= 900 ? 4 : 2;
        double cell(int cols) => (width - KuuSpacing.lg * (cols - 1)) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: KuuSpacing.xl),
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Niños, niñas y adolescentes',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: KuuSpacing.xs),
                  Text(
                    'Cada NNA aparece solo con su código. Los nombres quedan en manos de sus tutores.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: KuuSpacing.lg),
                  Wrap(
                    spacing: KuuSpacing.lg,
                    runSpacing: KuuSpacing.lg,
                    children: [
                      for (final s in [
                        _StatData(
                          'NNA en seguimiento',
                          '${children.length}',
                          Icons.diversity_1_rounded,
                          KuuColor.brandPrimary,
                        ),
                        _StatData(
                          'Sesiones esta semana',
                          '${lastWeek.length}',
                          Icons.monitor_heart_rounded,
                          KuuColor.brandHighlight,
                        ),
                        _StatData(
                          'Crisis esta semana',
                          '$crisesWeek',
                          Icons.bolt_rounded,
                          KuuColor.statePreCrisis,
                        ),
                        _StatData(
                          'Eventos marcados',
                          '$markedEvents',
                          Icons.flag_rounded,
                          KuuColor.brandSecondary,
                        ),
                      ])
                        SizedBox(
                          width: cell(statColumns),
                          child: _StatCard(data: s),
                        ),
                    ],
                  ),
                  const SizedBox(height: KuuSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seguimiento',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const KuuOutcomeLegend(),
                    ],
                  ),
                  const SizedBox(height: KuuSpacing.md),
                  if (children.isEmpty)
                    const _Empty()
                  else
                    Wrap(
                      spacing: KuuSpacing.lg,
                      runSpacing: KuuSpacing.lg,
                      children: [
                        for (final child in children)
                          SizedBox(
                            width: cell(columns),
                            child: _ChildCard(
                              child: child,
                              sessions: byChild[child.id] ?? const [],
                              onTap: () => onOpen(child.id),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ stats

class _StatData {
  const _StatData(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.lg),
        child: Row(
          children: [
            KuuIconTile(icon: data.icon, color: data.color, size: 52),
            const SizedBox(width: KuuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ child card

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.sessions,
    required this.onTap,
  });
  final Child child;
  final List<RecordingSession> sessions;
  final VoidCallback onTap;

  static const _palette = [
    KuuColor.brandPrimary,
    KuuColor.brandHighlight,
    KuuColor.brandSecondary,
    KuuColor.brandAccent,
  ];

  Color get _tint =>
      _palette[child.code.codeUnits.fold<int>(0, (a, b) => a + b) %
          _palette.length];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final monthAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final month = sessions.where((s) => s.startedAtMs >= monthAgo).toList();
    final crises = month
        .where((s) => SessionOutcome.of(s) == SessionOutcome.crisis)
        .length;
    final last = sessions.isEmpty ? null : sessions.first;
    final lastOutcome = last == null ? null : SessionOutcome.of(last);

    return KuuSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KuuIconTile(
                  icon: Icons.face_rounded,
                  color: _tint,
                  size: 56,
                  round: true,
                ),
                const SizedBox(width: KuuSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            child.code,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (child.isDemo) ...[
                            const SizedBox(width: KuuSpacing.sm),
                            const KuuDemoBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${child.approximateAge()} años aprox.',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: KuuSpacing.md),
            Wrap(
              spacing: KuuSpacing.sm,
              runSpacing: KuuSpacing.sm,
              children: [
                KuuPill(
                  icon: Icons.sensors_rounded,
                  text:
                      child.dunnQuadrant?.label ?? 'Perfil sensorial pendiente',
                  color: _tint,
                ),
              ],
            ),
            const SizedBox(height: KuuSpacing.lg),
            Text('Actividad · últimos 14 días', style: muted),
            const SizedBox(height: KuuSpacing.sm),
            KuuActivityBars(sessions: sessions),
            const SizedBox(height: KuuSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: KuuFigure(
                    value: '${month.length}',
                    label: 'Sesiones (30 d)',
                  ),
                ),
                Expanded(
                  child: KuuFigure(
                    value: '$crises',
                    label: 'Crisis (30 d)',
                    highlight: crises > 0,
                  ),
                ),
                Expanded(
                  child: KuuFigure(
                    value: last == null
                        ? '—'
                        : formatDate(last.startedAtMs).substring(0, 5),
                    label: 'Última',
                  ),
                ),
              ],
            ),
            const SizedBox(height: KuuSpacing.md),
            KuuLastOutcome(outcome: lastOutcome),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.xl),
        child: Column(
          children: [
            const KuuIconTile(
              icon: Icons.diversity_1_rounded,
              color: KuuColor.brandPrimary,
              size: 64,
              round: true,
            ),
            const SizedBox(height: KuuSpacing.md),
            Text(
              'Aún no hay NNA registrados',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: KuuSpacing.xs),
            Text(
              'Los tutores los registran desde la app móvil.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
