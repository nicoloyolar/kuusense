import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import '../dashboard/dash_page.dart';
import 'admin_widgets.dart';

/// Admin maintainer of children (NNA): register them for a tutor, edit them
/// with the same form as the app, choose which tutors follow them, delete.
class ChildrenAdminPage extends StatefulWidget {
  const ChildrenAdminPage({
    super.key,
    required this.repo,
    required this.children,
    required this.profiles,
    required this.tutors,
    required this.sessions,
  });
  final KuusenseRepository repo;
  final List<Child> children;
  final Map<String, ChildProfile> profiles;
  final List<Tutor> tutors;
  final List<RecordingSession> sessions;

  @override
  State<ChildrenAdminPage> createState() => _ChildrenAdminPageState();
}

class _ChildrenAdminPageState extends State<ChildrenAdminPage> {
  String _query = '';

  KuusenseRepository get repo => widget.repo;
  List<Tutor> get _activeTutors =>
      widget.tutors.where((t) => t.active).toList();

  Future<void> _create() async {
    if (_activeTutors.isEmpty) {
      showMessage(context, 'Primero crea un tutor en la sección Tutores.');
      return;
    }
    String? ownerUid;
    await showFormDialog<void>(
      context,
      title: 'Registrar NNA',
      icon: Icons.child_care_rounded,
      builder: (ctx) => KuuChildForm(
        extraFields: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tutor responsable',
              helperText: 'Podrá ver al NNA en la app y grabar sus sesiones.',
              prefixIcon: Icon(Icons.supervisor_account_outlined),
            ),
            items: [
              for (final t in _activeTutors)
                DropdownMenuItem(value: t.uid, child: Text(_tutorLabel(t))),
            ],
            onChanged: (v) => ownerUid = v,
            validator: (v) => v == null ? 'Elige el tutor responsable' : null,
          ),
        ],
        onSubmit: (d) async {
          final ok = await runWithFeedback(
            ctx,
            () => repo.registerChild(
              displayName: d.displayName,
              avatarId: d.avatarId,
              birthYear: d.birthYear,
              dunnQuadrant: d.dunnQuadrant,
              consentConfirmed: true,
              ownerUid: ownerUid,
            ),
          );
          if (ok && ctx.mounted) Navigator.of(ctx).pop();
          return ok;
        },
      ),
    );
  }

  Future<void> _edit(Child child, ChildProfile? profile) =>
      showFormDialog<void>(
        context,
        title: 'Editar ${child.code}',
        icon: Icons.edit_outlined,
        builder: (ctx) => KuuChildForm(
          initial: ChildFormData(
            displayName: profile?.displayName ?? '',
            avatarId: profile?.avatarId ?? KuuAvatar.all.first.id,
            birthYear: child.birthYear,
            dunnQuadrant: child.dunnQuadrant,
          ),
          onSubmit: (d) async {
            final ok = await runWithFeedback(
              ctx,
              () => repo.editChild(
                child.id,
                displayName: d.displayName,
                avatarId: d.avatarId,
                birthYear: d.birthYear,
                dunnQuadrant: d.dunnQuadrant,
              ),
            );
            if (ok && ctx.mounted) Navigator.of(ctx).pop();
            return ok;
          },
        ),
      );

  Future<void> _tutors(Child child) => showFormDialog<void>(
    context,
    title: 'Tutores de ${child.code}',
    icon: Icons.supervisor_account_outlined,
    builder: (_) =>
        _ChildTutorsDialog(repo: repo, child: child, tutors: widget.tutors),
  );

  Future<void> _delete(Child child, String name, int sessionCount) async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar a $name (${child.code})',
      message:
          'Sus tutores dejarán de verlo en la app. '
          '${sessionCount == 0 ? '' : 'Sus $sessionCount sesiones se conservan como datos de investigación, sin nombre. '}'
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    await runWithFeedback(context, () => repo.deleteChild(child.id));
  }

  String _tutorLabel(Tutor t) => '${t.displayName} · ${t.type.label}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tutorsById = {for (final t in widget.tutors) t.uid: t};
    final sessionCount = <String, int>{};
    for (final s in widget.sessions) {
      sessionCount[s.childId] = (sessionCount[s.childId] ?? 0) + 1;
    }
    final q = _query.trim().toLowerCase();
    final visible = widget.children.where((c) {
      if (q.isEmpty) return true;
      final name = widget.profiles[c.id]?.displayName.toLowerCase() ?? '';
      return name.contains(q) || c.code.toLowerCase().contains(q);
    }).toList();

    return DashPage(
      children: [
        AdminHeader(
          title: 'Gestión de NNA',
          subtitle:
              'Registra NNA para un tutor y elige quiénes lo acompañan. '
              'Los apodos solo los ven el administrador y los tutores; el equipo de investigación ve el código.',
          action: FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar NNA'),
          ),
        ),
        const SizedBox(height: KuuSpacing.lg),
        AdminSearchField(
          hint: 'Buscar por apodo o código',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: KuuSpacing.md),
        if (widget.children.isEmpty)
          const AdminEmpty(
            icon: Icons.diversity_1_rounded,
            title: 'Aún no hay NNA registrados',
            text: 'Regístralos aquí o desde la app móvil de un tutor.',
          )
        else if (visible.isEmpty)
          const AdminEmpty(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            text: 'Prueba con otro apodo o código.',
          )
        else
          KuuSurface(
            child: Column(
              children: [
                for (final (i, c) in visible.indexed) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.outline),
                  _ChildRow(
                    child: c,
                    profile: widget.profiles[c.id],
                    owner: tutorsById[c.ownerUid],
                    sessionCount: sessionCount[c.id] ?? 0,
                    onEdit: () => _edit(c, widget.profiles[c.id]),
                    onTutors: () => _tutors(c),
                    onDelete: () => _delete(
                      c,
                      widget.profiles[c.id]?.displayName ?? 'este NNA',
                      sessionCount[c.id] ?? 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.child,
    required this.profile,
    required this.owner,
    required this.sessionCount,
    required this.onEdit,
    required this.onTutors,
    required this.onDelete,
  });
  final Child child;
  final ChildProfile? profile;
  final Tutor? owner;
  final int sessionCount;
  final VoidCallback onEdit;
  final VoidCallback onTutors;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final others = child.tutorUids.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KuuSpacing.md,
        vertical: KuuSpacing.sm,
      ),
      child: Row(
        children: [
          ChildAvatar(avatarId: profile?.avatarId ?? '', size: 44),
          const SizedBox(width: KuuSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: profile?.displayName ?? 'Sin apodo',
                        style: theme.textTheme.titleMedium,
                      ),
                      TextSpan(
                        text: '   ${child.code}',
                        style: muted?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${child.approximateAge()} años aprox. · '
                  'Responsable: ${owner?.displayName ?? 'tutor no encontrado'}'
                  '${others > 0 ? ' y $others más' : ''}',
                  style: muted,
                ),
                const SizedBox(height: KuuSpacing.xs),
                Wrap(
                  spacing: KuuSpacing.sm,
                  runSpacing: KuuSpacing.xs,
                  children: [
                    AdminTag(
                      child.dunnQuadrant?.label ?? 'Perfil sensorial pendiente',
                    ),
                    AdminTag(
                      sessionCount == 1 ? '1 sesión' : '$sessionCount sesiones',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Acciones',
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: onEdit, child: const Text('Editar datos')),
              PopupMenuItem(
                value: onTutors,
                child: const Text('Tutores vinculados'),
              ),
              PopupMenuItem(value: onDelete, child: const Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chooses the tutors that follow a child and which one is responsible.
class _ChildTutorsDialog extends StatefulWidget {
  const _ChildTutorsDialog({
    required this.repo,
    required this.child,
    required this.tutors,
  });
  final KuusenseRepository repo;
  final Child child;
  final List<Tutor> tutors;

  @override
  State<_ChildTutorsDialog> createState() => _ChildTutorsDialogState();
}

class _ChildTutorsDialogState extends State<_ChildTutorsDialog> {
  late String _owner = widget.child.ownerUid;
  late final Set<String> _linked = {...widget.child.tutorUids};
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => widget.repo.setChildTutors(
        widget.child.id,
        ownerUid: _owner,
        tutorUids: _linked.toList(),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Deactivated tutors are listed only while still linked, so they can be removed.
    final options = widget.tutors
        .where((t) => t.active || _linked.contains(t.uid))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Marca quiénes acompañan a este NNA y elige al responsable. '
          'El responsable siempre queda vinculado.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: KuuSpacing.md),
        RadioGroup<String>(
          groupValue: _owner,
          onChanged: (v) => setState(() {
            _owner = v!;
            _linked.add(v);
          }),
          child: Column(
            children: [
              for (final t in options)
                Row(
                  children: [
                    Checkbox(
                      value: _linked.contains(t.uid),
                      onChanged: t.uid == _owner
                          ? null
                          : (v) => setState(
                              () => v!
                                  ? _linked.add(t.uid)
                                  : _linked.remove(t.uid),
                            ),
                    ),
                    Expanded(
                      child: Text(
                        '${t.displayName} · ${t.type.label}${t.active ? '' : ' (desactivado)'}',
                      ),
                    ),
                    Text('Responsable', style: theme.textTheme.bodySmall),
                    Radio<String>(value: t.uid, enabled: t.active),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: KuuSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
