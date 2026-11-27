import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/data_table.dart';
import '../common/feedback.dart';
import '../common/panel.dart';
import '../dashboard/session_cells.dart';

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

  /// Dunn quadrant filter: a quadrant name, [_noDunn] or null (all).
  String? _dunn;
  static const _noDunn = '-';

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
              birthDate: d.birthDate!,
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
          initial: childFormDataOf(child, profile),
          onSubmit: (d) async {
            final ok = await runWithFeedback(
              ctx,
              () => repo.editChild(
                child.id,
                displayName: d.displayName,
                avatarId: d.avatarId,
                birthDate: d.birthDate!,
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
    final bySession = <String, List<RecordingSession>>{};
    for (final s in widget.sessions) {
      bySession.putIfAbsent(s.childId, () => []).add(s); // newest first
    }
    final q = _query.trim().toLowerCase();
    final rows = widget.children.where((c) {
      if (_dunn != null &&
          (_dunn == _noDunn
              ? c.dunnQuadrant != null
              : c.dunnQuadrant?.name != _dunn)) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = widget.profiles[c.id]?.displayName.toLowerCase() ?? '';
      return name.contains(q) || c.code.toLowerCase().contains(q);
    }).toList();

    return KuuPageBody(
      children: [
        KuuPageHeader(
          title: 'NNA',
          subtitle:
              '${widget.children.length} registrados. Los apodos solo los ven el administrador y sus tutores; '
              'el equipo de investigación ve el código.',
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _create,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Registrar NNA'),
            ),
          ],
        ),
        const SizedBox(height: KuuSpacing.lg),
        KuuDataTable<Child>(
          rows: rows,
          rowKey: (c) => c.id,
          onRowTap: (c) => _edit(c, widget.profiles[c.id]),
          initialSort: 0,
          minWidth: 1100,
          emptyText: widget.children.isEmpty
              ? 'Aún no hay NNA. Regístralos aquí o desde la app de un tutor.'
              : 'No hay NNA con estos filtros.',
          toolbar: KuuToolbar(
            children: [
              KuuSearchField(
                hint: 'Buscar por apodo o código',
                onChanged: (v) => setState(() => _query = v),
              ),
              KuuFilter<String?>(
                label: 'Perfil sensorial',
                value: _dunn,
                options: [
                  (null, 'Todos'),
                  for (final d in DunnQuadrant.values) (d.name, d.label),
                  (_noDunn, 'Sin definir'),
                ],
                onChanged: (v) => setState(() => _dunn = v),
                width: 220,
              ),
            ],
          ),
          columns: [
            KuuColumn(
              label: 'NNA',
              flex: 4,
              sortBy: (c) =>
                  widget.profiles[c.id]?.displayName.toLowerCase() ?? '',
              cell: (c) {
                final p = widget.profiles[c.id];
                return Row(
                  children: [
                    ChildAvatar(avatarId: p?.avatarId ?? '', size: 34),
                    const SizedBox(width: KuuSpacing.sm),
                    Flexible(
                      child: Text(
                        p?.displayName ?? 'Sin apodo',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            KuuColumn(
              label: 'Código',
              flex: 2,
              sortBy: (c) => c.code,
              cell: (c) => Text(
                c.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            KuuColumn(
              label: 'Edad',
              flex: 1,
              alignEnd: true,
              sortBy: (c) =>
                  widget.profiles[c.id]?.exactAge() ?? c.approximateAge(),
              cell: (c) => Text(
                '${widget.profiles[c.id]?.exactAge() ?? '~${c.approximateAge()}'}',
              ),
            ),
            KuuColumn(
              label: 'Perfil sensorial',
              flex: 3,
              sortBy: (c) => c.dunnQuadrant?.label ?? '~',
              cell: (c) => c.dunnQuadrant == null
                  ? const MutedText('Sin definir')
                  : Text(c.dunnQuadrant!.label),
            ),
            KuuColumn(
              label: 'Responsable',
              flex: 3,
              sortBy: (c) => tutorsById[c.ownerUid]?.displayName ?? '',
              cell: (c) => Text(tutorsById[c.ownerUid]?.displayName ?? '—'),
            ),
            KuuColumn(
              label: 'Tutores',
              flex: 1,
              alignEnd: true,
              sortBy: (c) => c.tutorUids.length,
              cell: (c) => Text('${c.tutorUids.length}'),
            ),
            KuuColumn(
              label: 'Sesiones',
              flex: 1,
              alignEnd: true,
              sortBy: (c) => bySession[c.id]?.length ?? 0,
              cell: (c) => Text('${bySession[c.id]?.length ?? 0}'),
            ),
            KuuColumn(
              label: 'Última sesión',
              flex: 2,
              sortBy: (c) => bySession[c.id]?.first.startedAtMs ?? 0,
              cell: (c) {
                final last = bySession[c.id]?.first;
                return last == null
                    ? const MutedText('—')
                    : Text(formatDate(last.startedAtMs));
              },
            ),
            KuuColumn(
              label: '',
              width: 56,
              alignEnd: true,
              cell: (c) => PopupMenuButton<VoidCallback>(
                tooltip: 'Acciones',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => _edit(c, widget.profiles[c.id]),
                    child: const Text('Editar datos'),
                  ),
                  PopupMenuItem(
                    value: () => _tutors(c),
                    child: const Text('Tutores vinculados'),
                  ),
                  PopupMenuItem(
                    value: () => _delete(
                      c,
                      widget.profiles[c.id]?.displayName ?? 'este NNA',
                      bySession[c.id]?.length ?? 0,
                    ),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
  final _photoUrls = <String, Future<String>>{};
  bool _busy = false;

  Future<String>? _photoUrl(String? path) => path == null
      ? null
      : _photoUrls.putIfAbsent(path, () => widget.repo.downloadUrl(path));

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

  void _toggle(Tutor t) {
    if (t.uid == _owner) return; // The responsible tutor always stays linked.
    setState(
      () =>
          _linked.contains(t.uid) ? _linked.remove(t.uid) : _linked.add(t.uid),
    );
  }

  void _makeOwner(Tutor t) => setState(() {
    _owner = t.uid;
    _linked.add(t.uid);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Deactivated tutors are listed only while still linked, so they can be
    // removed. Linked tutors first, the responsible one on top.
    final options =
        widget.tutors.where((t) => t.active || _linked.contains(t.uid)).toList()
          ..sort((a, b) {
            int rank(Tutor t) =>
                t.uid == _owner ? 0 : (_linked.contains(t.uid) ? 1 : 2);
            final r = rank(a).compareTo(rank(b));
            return r != 0
                ? r
                : a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  );
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Toca a un tutor para vincularlo o quitarlo. El responsable siempre queda vinculado.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: KuuSpacing.sm),
        Text(
          '${_linked.length} de ${options.length} vinculados',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: KuuSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: KuuSpacing.sm),
            itemBuilder: (_, i) => _TutorOption(
              tutor: options[i],
              photoUrl: _photoUrl(options[i].photoPath),
              linked: _linked.contains(options[i].uid),
              owner: options[i].uid == _owner,
              onTap: () => _toggle(options[i]),
              onMakeOwner: options[i].active
                  ? () => _makeOwner(options[i])
                  : null,
            ),
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

/// One tutor in the child's tutors dialog: a card that is highlighted when
/// linked, with a badge for the responsible tutor.
class _TutorOption extends StatelessWidget {
  const _TutorOption({
    required this.tutor,
    required this.photoUrl,
    required this.linked,
    required this.owner,
    required this.onTap,
    required this.onMakeOwner,
  });
  final Tutor tutor;
  final Future<String>? photoUrl;
  final bool linked;
  final bool owner;
  final VoidCallback onTap;

  /// Null when the tutor cannot become responsible (deactivated).
  final VoidCallback? onMakeOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = [
      tutor.type.label,
      if (tutor.email.isNotEmpty) tutor.email,
      if (!tutor.active) 'desactivado',
    ].join(' · ');
    return Material(
      color: linked
          ? scheme.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KuuRadius.md),
        side: BorderSide(
          color: linked
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant,
          width: linked ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: owner ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KuuSpacing.md - 4,
            vertical: KuuSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: tutor.active ? 1 : 0.5,
                    child: KuuPersonAvatar(
                      name: tutor.displayName,
                      photoUrl: photoUrl,
                      size: 42,
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: AnimatedScale(
                      scale: linked ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: KuuSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutor.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KuuSpacing.sm),
              if (owner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(KuuRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Responsable',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else if (onMakeOwner != null)
                TextButton.icon(
                  onPressed: onMakeOwner,
                  icon: const Icon(Icons.star_outline_rounded, size: 16),
                  label: const Text('Hacer responsable'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
