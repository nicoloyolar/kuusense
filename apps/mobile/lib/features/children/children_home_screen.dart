import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import '../recording/recording_controller.dart';
import '../tutor/tutor_profile_screen.dart';
import 'child_detail_screen.dart';
import 'child_form_screen.dart';
import 'join_with_code_screen.dart';

/// Tutor home: the children (NNA) this tutor follows.
class ChildrenHomeScreen extends StatefulWidget {
  const ChildrenHomeScreen({
    super.key,
    required this.repo,
    required this.recording,
    required this.tutor,
    required this.onSignOut,
  });

  final KuusenseRepository repo;
  final RecordingController recording;
  final Tutor tutor;
  final VoidCallback onSignOut;

  @override
  State<ChildrenHomeScreen> createState() => _ChildrenHomeScreenState();
}

class _ChildrenHomeScreenState extends State<ChildrenHomeScreen> {
  late final Stream<List<Child>> _children = widget.repo.watchMyChildren();

  KuusenseRepository get repo => widget.repo;

  Future<void> _open(String childId) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChildDetailScreen(
        repo: repo,
        recording: widget.recording,
        childId: childId,
      ),
    ),
  );

  Future<void> _register() async {
    String? newId;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChildFormScreen(
          onSubmit: (d) async {
            final child = await repo.registerChild(
              displayName: d.displayName,
              avatarId: d.avatarId,
              birthYear: d.birthYear,
              dunnQuadrant: d.dunnQuadrant,
              consentConfirmed: true,
            );
            newId = child.id;
          },
        ),
      ),
    );
    if (ok == true && newId != null && mounted) await _open(newId!);
  }

  Future<void> _join() async {
    String? childId;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => JoinWithCodeScreen(
          onJoin: (code) async => childId = await repo.acceptInvite(code),
        ),
      ),
    );
    if (ok == true && childId != null && mounted) await _open(childId!);
  }

  void _showAddOptions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.child_care_rounded),
            title: const Text('Registrar un niño/a'),
            onTap: () {
              Navigator.pop(ctx);
              _register();
            },
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key_rounded),
            title: const Text('Tengo un código de invitación'),
            onTap: () {
              Navigator.pop(ctx);
              _join();
            },
          ),
        ],
      ),
    ),
  );

  void _editProfile() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TutorProfileScreen(
        initialName: widget.tutor.displayName,
        initialType: widget.tutor.type,
        onSave: (name, type) =>
            repo.saveMyTutorProfile(displayName: name, type: type),
      ),
    ),
  );

  Future<void> _confirmSignOut() async {
    final ok = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres cerrar tu sesión en este teléfono?',
      confirmLabel: 'Cerrar sesión',
      icon: Icons.logout_rounded,
    );
    if (ok) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const KuusenseLogo(height: 30, horizontal: true),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_rounded),
            onSelected: (v) =>
                v == 'profile' ? _editProfile() : _confirmSignOut(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Editar mi perfil')),
              PopupMenuItem(value: 'signout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Child>>(
        stream: _children,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('children stream: ${snap.error}');
            return const Center(
              child: Text(genericErrorMessage, textAlign: TextAlign.center),
            );
          }
          final children = snap.data;
          if (children == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (children.isEmpty) {
            return _EmptyState(
              tutorName: widget.tutor.displayName,
              onRegister: _register,
              onJoin: _join,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              KuuSpacing.md,
              KuuSpacing.sm,
              KuuSpacing.md,
              96,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KuuSpacing.xs,
                  0,
                  KuuSpacing.xs,
                  KuuSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${widget.tutor.displayName}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: KuuSpacing.xs),
                    Text(
                      'Así van las últimas dos semanas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: KuuSpacing.sm),
                    const KuuOutcomeLegend(),
                  ],
                ),
              ),
              for (final c in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: KuuSpacing.md),
                  child: _ChildCard(
                    repo: repo,
                    child: c,
                    onTap: () => _open(c.id),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
    );
  }
}

/// One child: avatar and nickname, activity of the last 14 days, figures
/// of the last 30 days and how the last session went.
class _ChildCard extends StatefulWidget {
  const _ChildCard({
    required this.repo,
    required this.child,
    required this.onTap,
  });
  final KuusenseRepository repo;
  final Child child;
  final VoidCallback onTap;

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  late final Stream<ChildProfile?> _profile = widget.repo.watchChildProfile(
    widget.child.id,
  );
  late final Stream<List<RecordingSession>> _sessions = widget.repo
      .watchSessions(widget.child.id);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return StreamBuilder<ChildProfile?>(
      stream: _profile,
      builder: (context, profileSnap) => StreamBuilder<List<RecordingSession>>(
        stream: _sessions,
        builder: (context, sessionSnap) {
          final p = profileSnap.data;
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
          final last = sessions.isEmpty ? null : sessions.first; // newest first
          return KuuSurface(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(KuuSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ChildAvatar(avatarId: p?.avatarId ?? '', size: 56),
                      const SizedBox(width: KuuSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p?.displayName ?? '…',
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${widget.child.approximateAge()} años aprox.',
                              style: muted,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: KuuSpacing.md),
                  KuuActivityBars(sessions: sessions, height: 36),
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
                          value: last == null
                              ? '—'
                              : formatDate(last.startedAtMs).substring(0, 5),
                          label: 'Última',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KuuSpacing.md),
                  KuuLastOutcome(
                    outcome: last == null ? null : SessionOutcome.of(last),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.tutorName,
    required this.onRegister,
    required this.onJoin,
  });
  final String tutorName;
  final VoidCallback onRegister;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KuuSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.diversity_1_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: KuuSpacing.md),
              Text(
                'Hola, $tutorName',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: KuuSpacing.sm),
              const Text(
                'Todavía no acompañas a ningún niño/a. Regístralo, o únete con el código '
                'que te compartió otro tutor.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KuuSpacing.lg),
              FilledButton.icon(
                icon: const Icon(Icons.child_care_rounded),
                label: const Text('Registrar un niño/a'),
                onPressed: onRegister,
              ),
              const SizedBox(height: KuuSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.vpn_key_rounded),
                label: const Text('Tengo un código de invitación'),
                onPressed: onJoin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
