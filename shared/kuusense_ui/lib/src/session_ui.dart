import 'package:flutter/material.dart';
import 'package:kuusense_models/kuusense_models.dart';

import 'format.dart';
import 'generated/tokens.g.dart';
import 'theme.dart';

/// Visual building blocks for sessions and follow-up, shared by the mobile
/// app and the web platform so both look the same.

// ------------------------------------------------------------------ outcome

/// How a session went, from the events marked in it (traffic-light colors).
/// Until the AI model exists this is derived only from the tutor's marks.
enum SessionOutcome {
  calm('Tranquila'),
  mild('Episodio leve'),
  crisis('Crisis');

  const SessionOutcome(this.label);
  final String label;

  static const _mildKinds = {
    'restless',
    'coversEars',
    'repetitiveMovement',
    'crying',
  };

  static SessionOutcome of(RecordingSession s) {
    final kinds = s.events.map((e) => e.kind).toSet();
    if (kinds.contains('crisisStart')) return crisis;
    if (kinds.any(_mildKinds.contains)) return mild;
    return calm;
  }

  Color color(BuildContext context) {
    final state = Theme.of(context).extension<KuuStateColors>()!;
    return switch (this) {
      calm => state.stable,
      mild => state.alert,
      crisis => state.preCrisis,
    };
  }
}

IconData kuuPlaceIcon(SessionPlace? p) => switch (p) {
  SessionPlace.home => Icons.home_rounded,
  SessionPlace.school => Icons.school_rounded,
  SessionPlace.therapy => Icons.psychology_rounded,
  SessionPlace.other || null => Icons.place_rounded,
};

IconData kuuEventIcon(String kind) => switch (kind) {
  'crisisStart' => Icons.bolt_rounded,
  'crisisEnd' || 'calmed' => Icons.spa_rounded,
  'strategyApplied' => Icons.lightbulb_rounded,
  'crying' => Icons.water_drop_rounded,
  'coversEars' => Icons.hearing_disabled_rounded,
  BehaviorCatalog.noteId => Icons.edit_note_rounded,
  _ => Icons.flag_rounded,
};

Color kuuEventColor(BuildContext context, String kind) {
  final scheme = Theme.of(context).colorScheme;
  final state = Theme.of(context).extension<KuuStateColors>()!;
  return switch (kind) {
    'crisisStart' || 'crying' => state.preCrisis,
    'crisisEnd' || 'calmed' => state.stable,
    'strategyApplied' => scheme.secondary,
    BehaviorCatalog.noteId => scheme.onSurfaceVariant,
    _ => state.alert,
  };
}

// ------------------------------------------------------------------ surfaces

/// White rounded surface with a soft brand-tinted shadow; lifts on hover
/// (web) when tappable.
class KuuSurface extends StatefulWidget {
  const KuuSurface({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<KuuSurface> createState() => _KuuSurfaceState();
}

class _KuuSurfaceState extends State<KuuSurface> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lifted = _hover && widget.onTap != null;
    final radius = BorderRadius.circular(KuuRadius.lg);
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(
              alpha: lifted ? 0 : 0.7,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: KuuColor.brandPrimary.withValues(
                alpha: lifted ? 0.16 : 0.06,
              ),
              blurRadius: lifted ? 28 : 16,
              offset: Offset(0, lifted ? 12 : 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Icon on a soft tinted square (or circle).
class KuuIconTile extends StatelessWidget {
  const KuuIconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    this.round = false,
  });
  final IconData icon;
  final Color color;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
      ),
      borderRadius: BorderRadius.circular(round ? size : KuuRadius.md),
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// Small tinted pill with an icon and text.
/// Warns that a session has missing data: connection drops and/or it ended
/// by itself. Empty when the session is complete.
class KuuDataGapsNote extends StatelessWidget {
  const KuuDataGapsNote({super.key, required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (!s.isIncomplete && s.gaps.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final lines = [
      if (s.isIncomplete) sessionEndReasonLabel(s.endReason),
      if (s.gaps.isNotEmpty) sessionGapsSummary(s.gaps),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: KuuSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: KuuSpacing.xs),
          Expanded(
            child: Text(
              lines.join('\n'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks a session that ended by itself (device lost or app closed).
class KuuIncompletePill extends StatelessWidget {
  const KuuIncompletePill({super.key, required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: sessionEndReasonLabel(session.endReason),
    child: KuuPill(
      icon: Icons.warning_amber_rounded,
      text: 'Incompleta',
      color: Theme.of(context).colorScheme.error,
    ),
  );
}

class KuuPill extends StatelessWidget {
  const KuuPill({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.md, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(KuuRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: KuuSpacing.xs),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Colored tag with the outcome of a session.
class KuuOutcomeBadge extends StatelessWidget {
  const KuuOutcomeBadge({super.key, required this.outcome});
  final SessionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final color = outcome.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KuuSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KuuRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: KuuSpacing.xs),
          Text(
            outcome.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// "Última sesión: …" strip with the outcome color.
class KuuLastOutcome extends StatelessWidget {
  const KuuLastOutcome({super.key, required this.outcome});
  final SessionOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = outcome?.color(context) ?? theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KuuSpacing.md,
        vertical: KuuSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KuuRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: KuuSpacing.sm),
          Expanded(
            child: Text(
              outcome == null
                  ? 'Aún sin sesiones'
                  : 'Última sesión: ${outcome!.label.toLowerCase()}',
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

/// A big number with a label under it.
class KuuFigure extends StatelessWidget {
  const KuuFigure({
    super.key,
    required this.value,
    required this.label,
    this.highlight = false,
  });
  final String value, label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = theme.extension<KuuStateColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: highlight ? state.preCrisis : null,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Legend of the traffic-light outcome colors.
class KuuOutcomeLegend extends StatelessWidget {
  const KuuOutcomeLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: KuuSpacing.md,
      children: [
        for (final o in SessionOutcome.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: o.color(context),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: KuuSpacing.xs),
              Text(o.label, style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ activity

/// One bar per day (last [days] days): height = sessions that day, color =
/// the worst outcome of the day.
class KuuActivityBars extends StatelessWidget {
  const KuuActivityBars({
    super.key,
    required this.sessions,
    this.days = 14,
    this.height = 44,
  });
  final List<RecordingSession> sessions;
  final int days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final counts = List.filled(days, 0);
    final worst = List<SessionOutcome?>.filled(days, null);
    for (final s in sessions) {
      final d = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(s.startedAtMs),
      );
      final i = days - 1 - today.difference(d).inDays;
      if (i < 0 || i >= days) continue;
      counts[i]++;
      final o = SessionOutcome.of(s);
      if (worst[i] == null || o.index > worst[i]!.index) worst[i] = o;
    }
    final maxCount = counts.fold<int>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Tooltip(
                message: counts[i] == 0
                    ? 'Sin sesiones'
                    : '${counts[i]} ${counts[i] == 1 ? 'sesión' : 'sesiones'} · ${worst[i]!.label}',
                child: Container(
                  height: counts[i] == 0
                      ? 6
                      : 10 + (height - 10) * counts[i] / maxCount,
                  decoration: BoxDecoration(
                    color:
                        worst[i]?.color(context) ??
                        theme.colorScheme.outline.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ session list item

/// A session in a list: outcome stripe, time and duration, place, context,
/// events and outcome. [title] is the child's code (web) or nickname.
class KuuSessionTile extends StatelessWidget {
  const KuuSessionTile({
    super.key,
    required this.session,
    required this.onTap,
    this.title,
    this.compact = false,
    this.trailingStatus,
  });

  final RecordingSession session;
  final VoidCallback onTap;

  /// Shown above the context line; null shows only the context.
  final String? title;

  /// Phone layout: badges go under the text instead of on the right.
  final bool compact;

  /// Optional extra widget (e.g. upload state icon).
  final Widget? trailingStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    final outcome = SessionOutcome.of(s);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final badges = Wrap(
      spacing: KuuSpacing.sm,
      runSpacing: KuuSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (s.events.isNotEmpty)
          KuuPill(
            icon: Icons.flag_rounded,
            text: '${s.events.length} eventos',
            color: theme.colorScheme.primary,
          ),
        KuuOutcomeBadge(outcome: outcome),
        if (s.isIncomplete) KuuIncompletePill(session: s),
        ?trailingStatus,
      ],
    );

    return KuuSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.md),
        child: Row(
          children: [
            Container(
              width: 5,
              height: compact ? 72 : 56,
              decoration: BoxDecoration(
                color: outcome.color(context),
                borderRadius: BorderRadius.circular(KuuRadius.pill),
              ),
            ),
            const SizedBox(width: KuuSpacing.md),
            SizedBox(
              width: compact ? 60 : 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(s.startedAtMs),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // Short and scaled down so it never wraps to two lines.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatDurationShort(s.duration),
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: KuuSpacing.md),
              KuuIconTile(
                icon: kuuPlaceIcon(s.context.place),
                color: KuuColor.brandHighlight,
                size: 44,
              ),
            ],
            const SizedBox(width: KuuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title!,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (title != null) const SizedBox(height: 2),
                  Text(
                    contextSummary(s.context),
                    style: title == null ? theme.textTheme.bodyMedium : muted,
                  ),
                  if (compact) ...[
                    const SizedBox(height: KuuSpacing.sm),
                    badges,
                  ],
                ],
              ),
            ),
            if (!compact) ...[const SizedBox(width: KuuSpacing.md), badges],
            const SizedBox(width: KuuSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ timeline

/// Marked events: a bar with each event at its moment, then the sequence as
/// a vertical stepper with the minute of each event.
class KuuEventTimeline extends StatelessWidget {
  const KuuEventTimeline({super.key, required this.session});
  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = [...session.events]
      ..sort((a, b) => a.atMs.compareTo(b.atMs));
    final total = session.duration.inMilliseconds;
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KuuSpacing.lg),
        child: Column(
          children: [
            KuuIconTile(
              icon: Icons.spa_rounded,
              color: theme.extension<KuuStateColors>()!.stable,
              size: 56,
              round: true,
            ),
            const SizedBox(height: KuuSpacing.md),
            Text(
              'Sesión tranquila: no se marcaron eventos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0) ...[
          _TimelineBar(
            events: events,
            startMs: session.startedAtMs,
            totalMs: total,
          ),
          const SizedBox(height: KuuSpacing.lg),
        ],
        for (final (i, e) in events.indexed)
          _EventRow(
            event: e,
            offset: Duration(milliseconds: e.atMs - session.startedAtMs),
            last: i == events.length - 1,
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.offset,
    required this.last,
  });
  final SessionEvent event;
  final Duration offset;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = kuuEventColor(context, event.kind);
    final isNote = event.kind == BehaviorCatalog.noteId;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                formatOffset(offset),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(kuuEventIcon(event.kind), size: 14, color: color),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outline.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KuuSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: KuuSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNote ? 'Nota' : event.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isNote && (event.note ?? '').isNotEmpty)
                    Text(
                      event.note!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.events,
    required this.startMs,
    required this.totalMs,
  });
  final List<SessionEvent> events;
  final int startMs, totalMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, c) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.outline.withValues(alpha: 0.5),
                          theme.colorScheme.outline,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(KuuRadius.pill),
                    ),
                  ),
                  for (final e in events)
                    Positioned(
                      left:
                          ((e.atMs - startMs) / totalMs).clamp(0.0, 1.0) *
                          (c.maxWidth - 14),
                      child: Tooltip(
                        message:
                            '${formatOffset(Duration(milliseconds: e.atMs - startMs))} · ${e.label}',
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: kuuEventColor(context, e.kind),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Row(
          children: [
            Text('Inicio', style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(
              formatOffset(Duration(milliseconds: totalMs)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
