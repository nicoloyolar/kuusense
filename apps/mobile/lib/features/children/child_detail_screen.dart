import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import '../recording/recording_controller.dart';
import '../recording/recording_flow.dart';
import 'avatars.dart';
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
  late final Stream<ChildProfile?> _profile = widget.repo.watchChildProfile(widget.childId);

  /// Set once the tutor leaves or deletes, so the closing stream errors
  /// (access revoked) are not shown as failures.
  bool _leaving = false;

  KuusenseRepository get repo => widget.repo;

  Future<void> _edit(Child child, ChildProfile profile) => Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChildFormScreen(
            initial: ChildFormData(
              displayName: profile.displayName,
              avatarId: profile.avatarId,
              birthYear: child.birthYear,
            ),
            onSubmit: (d) async {
              await repo.updateChildProfile(
                  child.id, ChildProfile(displayName: d.displayName, avatarId: d.avatarId));
              if (d.birthYear != child.birthYear) {
                await repo.updateChild(child.id,
                    birthYear: d.birthYear, dunnQuadrant: child.dunnQuadrant);
              }
            },
          ),
        ),
      );

  void _record(String name) {
    widget.recording.selectChild(widget.childId, name);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordingFlow(controller: widget.recording)),
    );
  }

  Future<void> _leave(String name) async {
    final ok = await confirmDialog(
      context,
      title: 'Dejar de acompañar a $name',
      message: 'Ya no verás a $name en tu app. Para volver, otro tutor tendrá que invitarte.',
      confirmLabel: 'Desvincularme',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    final done = await runWithFeedback(context, () => repo.leaveChild(widget.childId));
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
        if (others > 0) 'También dejará de verlo ${others == 1 ? 'el otro tutor' : 'los otros $others tutores'}.',
        'Las grabaciones ya hechas se conservan sin datos que lo identifiquen, para la investigación.',
        'Esta acción no se puede deshacer.',
      ].join('\n\n'),
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _leaving = true);
    final done = await runWithFeedback(context, () => repo.deleteChild(widget.childId));
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
          if (childSnap.hasError || profileSnap.hasError ||
              (childSnap.connectionState == ConnectionState.active && childSnap.data == null)) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Ya no tienes acceso a este niño/a.')),
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
      body: ListView(
        padding: const EdgeInsets.all(KuuSpacing.lg),
        children: [
          Center(child: ChildAvatar(avatarId: profile.avatarId, size: 96)),
          const SizedBox(height: KuuSpacing.md),
          Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: KuuSpacing.xs),
          Text(
            '${child.approximateAge()} años aprox. · Código ${child.code}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: KuuSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: Text(tutorCount == 1 ? 'Solo tú lo acompañas' : '$tutorCount tutores lo acompañan'),
              subtitle: Text(isOwner ? 'Eres el/la responsable de este perfil' : 'Te uniste con un código'),
            ),
          ),
          const SizedBox(height: KuuSpacing.lg),
          FilledButton.icon(
            icon: const Icon(Icons.watch_rounded),
            label: const Text('Conectar EmotiBit y grabar'),
            onPressed: () => _record(name),
          ),
          const SizedBox(height: KuuSpacing.sm),
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
          const SizedBox(height: KuuSpacing.xl),
          if (isOwner)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('Eliminar a $name'),
              onPressed: () => _delete(name, tutorCount),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Desvincularme'),
              onPressed: () => _leave(name),
            ),
        ],
      ),
    );
  }
}
