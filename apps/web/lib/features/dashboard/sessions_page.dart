import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'dash_page.dart';
import 'session_detail_page.dart';

/// Recorded sessions grouped by day, newest first, optionally filtered to
/// one NNA.
class SessionsPage extends StatelessWidget {
  const SessionsPage({
    super.key,
    required this.repo,
    required this.children,
    required this.sessions,
    required this.childFilter,
    required this.onFilter,
  });

  final KuusenseRepository repo;
  final List<Child> children;
  final List<RecordingSession> sessions;
  final String? childFilter;
  final ValueChanged<String?> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codes = {for (final c in children) c.id: c.code};
    final visible = childFilter == null
        ? sessions
        : sessions.where((s) => s.childId == childFilter).toList();

    // Group by calendar day (sessions arrive newest first).
    final groups = <DateTime, List<RecordingSession>>{};
    for (final s in visible) {
      final d = DateTime.fromMillisecondsSinceEpoch(s.startedAtMs);
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(s);
    }

    return DashPage(
      children: [
        Text(
          'Sesiones',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: KuuSpacing.xs),
        Text(
          '${visible.length} ${visible.length == 1 ? 'sesión' : 'sesiones'}'
          '${childFilter == null ? '' : ' de ${codes[childFilter] ?? ''}'}, de la más reciente a la más antigua.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: KuuSpacing.lg),
        Wrap(
          spacing: KuuSpacing.sm,
          runSpacing: KuuSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: childFilter == null,
              onSelected: (_) => onFilter(null),
            ),
            for (final c in children)
              ChoiceChip(
                label: Text(c.code),
                selected: childFilter == c.id,
                onSelected: (on) => onFilter(on ? c.id : null),
              ),
          ],
        ),
        const SizedBox(height: KuuSpacing.lg),
        if (visible.isEmpty)
          KuuSurface(
            child: Padding(
              padding: const EdgeInsets.all(KuuSpacing.xl),
              child: Column(
                children: [
                  const KuuIconTile(
                    icon: Icons.monitor_heart_rounded,
                    color: KuuColor.brandHighlight,
                    size: 64,
                    round: true,
                  ),
                  const SizedBox(height: KuuSpacing.md),
                  Text(
                    'No hay sesiones todavía',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: KuuSpacing.xs),
                  Text(
                    'Se graban desde la app móvil con el EmotiBit.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: KuuSpacing.md,
                bottom: KuuSpacing.sm,
              ),
              child: Text(
                _capitalize(formatDayHeading(entry.key)),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final s in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: KuuSpacing.md),
                child: KuuSessionTile(
                  session: s,
                  title: codes[s.childId] ?? '—',
                  compact: MediaQuery.sizeOf(context).width < 700,
                  trailingStatus: s.status == SessionStatus.uploaded
                      ? null
                      : SessionStatusIcon(status: s.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SessionDetailPage(
                        repo: repo,
                        childId: s.childId,
                        sessionId: s.id,
                        childCode: codes[s.childId] ?? '—',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        if (sessions.length >= 200)
          Text(
            'Se muestran las 200 sesiones más recientes.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Small colored icon for a session's upload state.
class SessionStatusIcon extends StatelessWidget {
  const SessionStatusIcon({super.key, required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      SessionStatus.recording => (Icons.fiber_manual_record, scheme.error),
      SessionStatus.uploading => (Icons.cloud_upload_outlined, scheme.primary),
      SessionStatus.uploaded => (Icons.cloud_done_outlined, scheme.secondary),
      SessionStatus.failed => (Icons.error_outline_rounded, scheme.error),
    };
    return Tooltip(
      message: sessionStatusLabel(status),
      child: Icon(icon, color: color),
    );
  }
}
