import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import '../recording/recording_controller.dart';
import '../recording/recording_flow.dart';
import '../history/session_detail_screen.dart';
import 'child_form_screen.dart';
import 'invite_sheet.dart';

/// One child's card: who they are, who follows them, and the actions a
/// tutor can take (record, invite, edit, leave or delete).
class ChildDetailScreen extends StatefulWidget {
  const ChildDetailScreen({
    super.key,
    required this.repo,
    required this.recording,
    required this.childId,
  });

  final KuusenseRepository repo;
  final RecordingController recording;
  final String childId;

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  late final Stream<Child?> _child = widget.repo.watchChild(widget.childId);
  late final Stream<ChildProfile?> _profile = widget.repo.watchChildProfile(
    widget.childId,
  );
  late final Stream<List<RecordingSession>> _sessions = widget.repo
      .watchSessions(widget.childId);

  /// Sessions listed before "Ver todas".
  static const _recentCount = 5;
  bool _showAll = false;

  /// Set once the tutor leaves or deletes, so the closing stream errors
  /// (access revoked) are not shown as failures.
  bool _leaving = false;

  KuusenseRepository get repo => widget.repo;

  Future<void> _edit(Child child, ChildProfile profile) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChildFormScreen(
            initial: ChildFormData(
              displayName: profile.displayName,
              avatarId: profile.avatarId,
              birthYear: child.birthYear,
              dunnQuadrant: child.dunnQuadrant,
            ),
            onSubmit: (d) => repo.editChild(
              child.id,
              displayName: d.displayName,
              avatarId: d.avatarId,
              birthYear: d.birthYear,
              dunnQuadrant: d.dunnQuadrant,
            ),
          ),
        ),
      );

  void _record(String name) {
    widget.recording.selectChild(widget.childId, name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordingFlow(controller: widget.recording),
      ),
    );
  }

  Future<void> _leave(String name) async {
    final ok = await confirmDialog(
      context,
      title: 'Dejar de acompañar a $name',
      message:
          'Ya no verás a $name en tu app. Para volver, otro tutor tendrá que invitarte.',
      confirmLabel: 'Desvincularme',
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    final done = await runWithFeedback(
      context,
      () => repo.leaveChild(widget.childId),
    );
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      setState(() => _leaving = false);
    }
  }

  Future<void> _delete(String name, int tutorCount) async {
    final others = tutorCount - 1;
    final ok = await confirmDialog(
      context,
      title: 'Eliminar a $name',
      message: [
        'Se borrarán el apodo y el avatar de $name, y nadie podrá verlo en la app.',
        if (others > 0)
          'También dejará de verlo ${others == 1 ? 'el otro tutor' : 'los otros $others tutores'}.',
        'Las grabaciones ya hechas se conservan sin datos que lo identifiquen, para la investigación.',
        'Esta acción no se puede deshacer.',
      ].join('\n\n'),
      confirmLabel: 'Eliminar',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    final done = await runWithFeedback(
      context,
      () => repo.deleteChild(widget.childId),
    );
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
    } else {
      setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Child?>(
      stream: _child,
      builder: (context, childSnap) => StreamBuilder<ChildProfile?>(
        stream: _profile,
        builder: (context, profileSnap) {
          if (_leaving) return const LoadingView();
          if (childSnap.hasError ||
              profileSnap.hasError ||
              (childSnap.connectionState == ConnectionState.active &&
                  childSnap.data == null)) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text('Ya no tienes acceso a este niño/a.'),
              ),
            );
          }
          final child = childSnap.data;
          final profile = profileSnap.data;
          if (child == null || profile == null) return const LoadingView();
          return _buildLoaded(context, child, profile);
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, Child child, ChildProfile profile) {
    final theme = Theme.of(context);
    final isOwner = child.ownerUid == repo.uid;
    final tutorCount = child.tutorUids.length;
    final name = profile.displayName;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: StreamBuilder<List<RecordingSession>>(
        stream: _sessions,
        builder: (context, sessionSnap) {
          final sessions = sessionSnap.data ?? const <RecordingSession>[];
          final monthAgo = DateTime.now()
              .subtract(const Duration(days: 30))
              .millisecondsSinceEpoch;
          final month = sessions
              .where((s) => s.startedAtMs >= monthAgo)
              .toList();
          final crises = month
              .where((s) => SessionOutcome.of(s) == SessionOutcome.crisis)
              .length;
          final shown = _showAll
              ? sessions
              : sessions.take(_recentCount).toList();
          return ListView(
            padding: const EdgeInsets.all(KuuSpacing.md),
            children: [
              // Header
              KuuSurface(
                child: Padding(
                  padding: const EdgeInsets.all(KuuSpacing.lg),
                  child: Column(
                    children: [
                      ChildAvatar(avatarId: profile.avatarId, size: 88),
                      const SizedBox(height: KuuSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KuuSpacing.xs),
                      Text(
                        '${child.approximateAge()} años aprox. · Código ${child.code}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: KuuSpacing.md),
                      Wrap(
                        spacing: KuuSpacing.sm,
                        runSpacing: KuuSpacing.sm,
                        alignment: WrapAlignment.center,
                        children: [
                          KuuPill(
                            icon: Icons.groups_rounded,
                            text: tutorCount == 1
                                ? 'Solo tú lo acompañas'
                                : '$tutorCount tutores',
                            color: theme.colorScheme.primary,
                          ),
                          if (child.dunnQuadrant != null)
                            KuuPill(
                              icon: Icons.sensors_rounded,
                              text: child.dunnQuadrant!.label,
                              color: KuuColor.brandHighlight,
                            ),
                        ],
                      ),
                      const SizedBox(height: KuuSpacing.lg),
                      FilledButton.icon(
                        icon: const Icon(Icons.watch_rounded),
                        label: const Text('Conectar EmotiBit y grabar'),
                        onPressed: () => _record(name),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KuuSpacing.md),
              // Last 30 days
              KuuSurface(
                child: Padding(
                  padding: const EdgeInsets.all(KuuSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Últimos 14 días',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: KuuSpacing.md),
                      KuuActivityBars(sessions: sessions, height: 40),
                      const SizedBox(height: KuuSpacing.sm),
                      const KuuOutcomeLegend(),
                      const SizedBox(height: KuuSpacing.md),
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
                              value:
                                  '${month.fold<int>(0, (n, s) => n + s.events.length)}',
                              label: 'Eventos (30 d)',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KuuSpacing.lg),
              // Sessions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.xs),
                child: Text(
                  'Sesiones recientes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: KuuSpacing.sm),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(KuuSpacing.md),
                  child: Text(
                    'Aún no hay sesiones. Conecta el EmotiBit para grabar la primera.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final s in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: KuuSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: KuuSpacing.xs,
                          bottom: KuuSpacing.xs,
                        ),
                        child: Text(
                          _capitalize(
                            formatDayHeading(
                              DateTime.fromMillisecondsSinceEpoch(
                                s.startedAtMs,
                              ),
                            ),
                          ),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      KuuSessionTile(
                        session: s,
                        compact: true,
                        trailingStatus: switch (s.status) {
                          SessionStatus.uploaded => null,
                          SessionStatus.recording when s.endedAtMs == null => KuuPill(
                            icon: Icons.fiber_manual_record,
                            text: 'Grabando',
                            color: theme.colorScheme.error,
                          ),
                          _ => KuuPill(
                            icon: Icons.cloud_upload_outlined,
                            text: 'Pendiente de subir',
                            color: theme.colorScheme.primary,
                          ),
                        },
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SessionDetailScreen(
                              repo: repo,
                              childId: child.id,
                              sessionId: s.id,
                              childName: name,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (sessions.length > _recentCount)
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll ? 'Ver menos' : 'Ver todas (${sessions.length})',
                  ),
                ),
              const SizedBox(height: KuuSpacing.lg),
              // Other actions
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Invitar a otro tutor'),
                onPressed: () => showInviteSheet(
                  context,
                  childName: name,
                  createInvite: () => repo.createInvite(child.id),
                ),
              ),
              const SizedBox(height: KuuSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar datos'),
                onPressed: () => _edit(child, profile),
              ),
              const SizedBox(height: KuuSpacing.lg),
              if (isOwner)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text('Eliminar a $name'),
                  onPressed: () => _delete(name, tutorCount),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Desvincularme'),
                  onPressed: () => _leave(name),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
