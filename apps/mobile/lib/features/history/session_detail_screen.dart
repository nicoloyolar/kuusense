import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// One past session for the tutor: how it went, key figures, the marked
/// events on a timeline and the context. Same pieces as the web platform.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.repo,
    required this.childId,
    required this.sessionId,
    required this.childName,
  });

  final KuusenseRepository repo;
  final String childId;
  final String sessionId;
  final String childName;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final Stream<RecordingSession?> _session = widget.repo.watchSession(
    widget.childId,
    widget.sessionId,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Sesión de ${widget.childName}')),
      body: StreamBuilder<RecordingSession?>(
        stream: _session,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudo cargar la sesión.'));
          }
          final s = snap.data;
          if (s == null) {
            return snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const Center(child: Text('La sesión no existe.'));
          }
          final heading = formatDayHeading(
            DateTime.fromMillisecondsSinceEpoch(s.startedAtMs),
          );
          final crises = s.events.where((e) => e.kind == 'crisisStart').length;
          final ctx = s.context;
          return ListView(
            padding: const EdgeInsets.all(KuuSpacing.md),
            children: [
              KuuSurface(
                child: Padding(
                  padding: const EdgeInsets.all(KuuSpacing.md),
                  child: Row(
                    children: [
                      KuuIconTile(
                        icon: kuuPlaceIcon(ctx.place),
                        color: KuuColor.brandPrimary,
                        size: 52,
                        round: true,
                      ),
                      const SizedBox(width: KuuSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${heading[0].toUpperCase()}${heading.substring(1)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${formatTime(s.startedAtMs)}${s.endedAtMs == null ? '' : ' a ${formatTime(s.endedAtMs!)}'}'
                              ' · ${contextSummary(ctx)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: KuuSpacing.sm),
                            Wrap(
                              spacing: KuuSpacing.sm,
                              runSpacing: KuuSpacing.sm,
                              children: [
                                KuuOutcomeBadge(outcome: SessionOutcome.of(s)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              KuuDataGapsNote(session: s),
              const SizedBox(height: KuuSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _FigureCard(
                      icon: Icons.timer_outlined,
                      value: formatDuration(s.duration),
                      label: 'Duración',
                      color: KuuColor.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: KuuSpacing.md),
                  Expanded(
                    child: _FigureCard(
                      icon: Icons.flag_rounded,
                      value: '${s.events.length}',
                      label: 'Eventos',
                      color: KuuColor.brandHighlight,
                    ),
                  ),
                  const SizedBox(width: KuuSpacing.md),
                  Expanded(
                    child: _FigureCard(
                      icon: Icons.bolt_rounded,
                      value: '$crises',
                      label: 'Crisis',
                      color: KuuColor.statePreCrisis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KuuSpacing.md),
              _Section(
                title: 'Línea de tiempo',
                icon: Icons.timeline_rounded,
                child: KuuEventTimeline(session: s),
              ),
              const SizedBox(height: KuuSpacing.md),
              _Section(
                title: 'Contexto',
                icon: Icons.info_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field('Lugar', ctx.place?.label ?? 'Sin registrar'),
                    _Field('Actividad', ctx.activity?.label ?? 'Sin registrar'),
                    _Field(
                      'Presentes',
                      ctx.present.isEmpty
                          ? 'Sin registrar'
                          : ctx.present.map((t) => t.label).join(', '),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FigureCard extends StatelessWidget {
  const _FigureCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => KuuSurface(
    child: Padding(
      padding: const EdgeInsets.all(KuuSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KuuIconTile(icon: icon, color: color, size: 36),
          const SizedBox(height: KuuSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: KuuFigure(value: value, label: label),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: KuuSpacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KuuSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: KuuSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
