import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import '../recording/recording_controller.dart';
import '../tutor/tutor_profile_screen.dart';
import 'avatars.dart';
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

  Future<void> _open(String childId) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChildDetailScreen(repo: repo, recording: widget.recording, childId: childId),
      ));

  Future<void> _register() async {
    String? newId;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ChildFormScreen(
        onSubmit: (d) async {
          final child = await repo.registerChild(
            displayName: d.displayName,
            avatarId: d.avatarId,
            birthYear: d.birthYear,
            consentConfirmed: true,
          );
          newId = child.id;
        },
      ),
    ));
    if (ok == true && newId != null && mounted) await _open(newId!);
  }

  Future<void> _join() async {
    String? childId;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => JoinWithCodeScreen(onJoin: (code) async => childId = await repo.acceptInvite(code)),
    ));
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

  void _editProfile() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TutorProfileScreen(
          initialName: widget.tutor.displayName,
          initialType: widget.tutor.type,
          onSave: (name, type) => repo.saveMyTutorProfile(displayName: name, type: type),
        ),
      ));

  Future<void> _confirmSignOut() async {
    final ok = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Quieres cerrar tu sesión en este teléfono?',
      confirmLabel: 'Cerrar sesión',
    );
    if (ok) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis niños/as'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_rounded),
            onSelected: (v) => v == 'profile' ? _editProfile() : _confirmSignOut(),
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
            return const Center(child: Text(genericErrorMessage, textAlign: TextAlign.center));
          }
          final children = snap.data;
          if (children == null) return const Center(child: CircularProgressIndicator());
          if (children.isEmpty) {
            return _EmptyState(
              tutorName: widget.tutor.displayName,
              onRegister: _register,
              onJoin: _join,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(KuuSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.all(KuuSpacing.sm),
                child: Text('Hola, ${widget.tutor.displayName}', style: theme.textTheme.titleLarge),
              ),
              for (final c in children) _ChildTile(repo: repo, child: c, onTap: () => _open(c.id)),
              const SizedBox(height: 80),
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

class _ChildTile extends StatefulWidget {
  const _ChildTile({required this.repo, required this.child, required this.onTap});
  final KuusenseRepository repo;
  final Child child;
  final VoidCallback onTap;

  @override
  State<_ChildTile> createState() => _ChildTileState();
}

class _ChildTileState extends State<_ChildTile> {
  late final Stream<ChildProfile?> _profile = widget.repo.watchChildProfile(widget.child.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChildProfile?>(
      stream: _profile,
      builder: (context, snap) {
        final p = snap.data;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: KuuSpacing.md, vertical: KuuSpacing.sm),
            leading: ChildAvatar(avatarId: p?.avatarId ?? ''),
            title: Text(p?.displayName ?? '…'),
            subtitle: Text('${widget.child.approximateAge()} años aprox.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: widget.onTap,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tutorName, required this.onRegister, required this.onJoin});
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
              Icon(Icons.diversity_1_rounded, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: KuuSpacing.md),
              Text('Hola, $tutorName', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
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
