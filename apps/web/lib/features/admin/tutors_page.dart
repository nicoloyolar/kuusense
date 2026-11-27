import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/data_table.dart';
import '../common/feedback.dart';
import '../common/panel.dart';
import '../dashboard/session_cells.dart';

/// Admin maintainer of tutor accounts: create, edit, deactivate and resend
/// the access email. Tutors cannot sign up by themselves.
class TutorsPage extends StatefulWidget {
  const TutorsPage({
    super.key,
    required this.repo,
    required this.tutors,
    required this.children,
  });
  final KuusenseRepository repo;
  final List<Tutor> tutors;
  final List<Child> children;

  @override
  State<TutorsPage> createState() => _TutorsPageState();
}

enum _ActiveFilter { all, active, inactive }

class _TutorsPageState extends State<TutorsPage> {
  String _query = '';
  TutorType? _type;
  _ActiveFilter _active = _ActiveFilter.all;

  /// Download URL per photo path, fetched once.
  final _photoUrls = <String, Future<String>>{};
  Future<String>? _photoUrl(String? path) => path == null
      ? null
      : _photoUrls.putIfAbsent(path, () => repo.downloadUrl(path));

  KuusenseRepository get repo => widget.repo;

  Future<void> _create() async {
    final created = await showFormDialog<Tutor>(
      context,
      title: 'Nuevo tutor',
      icon: Icons.person_add_alt_1_rounded,
      builder: (_) => TutorDialog(repo: repo),
    );
    if (created != null && mounted) {
      showMessage(
        context,
        KuusenseEnv.testPassword.isNotEmpty
            ? 'Tutor creado. Período de pruebas: entra con ${created.email} y la contraseña de pruebas.'
            : 'Tutor creado. Le enviamos un correo a ${created.email} para que cree su contraseña.',
      );
    }
  }

  Future<void> _edit(Tutor t) => showFormDialog<Tutor>(
    context,
    title: 'Editar tutor',
    icon: Icons.edit_outlined,
    builder: (_) => TutorDialog(
      repo: repo,
      initial: t,
      photoUrl: _photoUrl(t.photoPath),
    ),
  );

  Future<void> _toggleActive(Tutor t) async {
    if (t.active) {
      final ok = await confirmDialog(
        context,
        title: 'Desactivar a ${t.displayName}',
        message:
            'No podrá entrar a la app ni ver a sus NNA hasta que lo vuelvas a activar. '
            'Sus vínculos y sesiones se conservan.',
        confirmLabel: 'Desactivar',
        destructive: true,
        icon: Icons.person_off_outlined,
      );
      if (!ok || !mounted) return;
    }
    await runWithFeedback(context, () => repo.setTutorActive(t.uid, !t.active));
  }

  Future<void> _resend(Tutor t) async {
    final ok = await runWithFeedback(
      context,
      () => repo.resendTutorAccess(t.email),
    );
    if (ok && mounted) {
      showMessage(context, 'Correo de acceso enviado a ${t.email}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childCount = <String, int>{};
    for (final c in widget.children) {
      for (final uid in c.tutorUids) {
        childCount[uid] = (childCount[uid] ?? 0) + 1;
      }
    }
    final q = _query.trim().toLowerCase();
    final rows = widget.tutors.where((t) {
      if (_type != null && t.type != _type) return false;
      if (_active == _ActiveFilter.active && !t.active) return false;
      if (_active == _ActiveFilter.inactive && t.active) return false;
      return q.isEmpty ||
          t.displayName.toLowerCase().contains(q) ||
          t.email.contains(q);
    }).toList();
    final activeCount = widget.tutors.where((t) => t.active).length;

    return KuuPageBody(
      children: [
        KuuPageHeader(
          title: 'Tutores',
          subtitle:
              '$activeCount activos de ${widget.tutors.length}. '
              'Familiares, docentes y terapeutas que usan la app; solo el administrador crea sus cuentas.',
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _create,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Nuevo tutor'),
            ),
          ],
        ),
        const SizedBox(height: KuuSpacing.lg),
        KuuDataTable<Tutor>(
          rows: rows,
          rowKey: (t) => t.uid,
          onRowTap: _edit,
          initialSort: 0,
          emptyText: widget.tutors.isEmpty
              ? 'Aún no hay tutores. Crea el primero con "Nuevo tutor".'
              : 'No hay tutores con estos filtros.',
          toolbar: KuuToolbar(
            children: [
              KuuSearchField(
                hint: 'Buscar por nombre o correo',
                onChanged: (v) => setState(() => _query = v),
              ),
              KuuFilter<TutorType?>(
                label: 'Tipo',
                value: _type,
                options: [
                  (null, 'Todos'),
                  for (final t in TutorType.values) (t, t.label),
                ],
                onChanged: (v) => setState(() => _type = v),
                width: 160,
              ),
              KuuFilter<_ActiveFilter>(
                label: 'Estado',
                value: _active,
                options: const [
                  (_ActiveFilter.all, 'Todos'),
                  (_ActiveFilter.active, 'Activos'),
                  (_ActiveFilter.inactive, 'Desactivados'),
                ],
                onChanged: (v) => setState(() => _active = v),
                width: 160,
              ),
            ],
          ),
          columns: [
            KuuColumn(
              label: 'Tutor',
              flex: 4,
              sortBy: (t) => t.displayName.toLowerCase(),
              cell: (t) => Row(
                children: [
                  Opacity(
                    opacity: t.active ? 1 : 0.5,
                    child: KuuPersonAvatar(
                      name: t.displayName,
                      photoUrl: _photoUrl(t.photoPath),
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: KuuSpacing.sm),
                  Flexible(
                    child: Text(
                      t.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            KuuColumn(
              label: 'Correo',
              flex: 4,
              sortBy: (t) => t.email,
              cell: (t) => t.email.isEmpty
                  ? const MutedText('No registrado')
                  : Text(t.email),
            ),
            KuuColumn(
              label: 'Tipo',
              flex: 2,
              sortBy: (t) => t.type.label,
              cell: (t) => Row(
                children: [
                  Icon(
                    tutorTypeIcon(t.type),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: KuuSpacing.xs),
                  Text(t.type.label),
                ],
              ),
            ),
            KuuColumn(
              label: 'NNA',
              flex: 1,
              alignEnd: true,
              sortBy: (t) => childCount[t.uid] ?? 0,
              cell: (t) => Text('${childCount[t.uid] ?? 0}'),
            ),
            KuuColumn(
              label: 'Estado',
              flex: 2,
              sortBy: (t) => t.active ? 0 : 1,
              cell: (t) => t.active
                  ? const KuuStatusBadge('Activo', color: KuuColor.stateStable)
                  : const KuuStatusBadge(
                      'Desactivado',
                      color: KuuColor.feedbackError,
                    ),
            ),
            KuuColumn(
              label: 'Creado',
              flex: 2,
              sortBy: (t) => t.createdAtMs,
              cell: (t) => MutedText(formatDate(t.createdAtMs)),
            ),
            KuuColumn(
              label: '',
              width: 56,
              alignEnd: true,
              cell: (t) => PopupMenuButton<VoidCallback>(
                tooltip: 'Acciones',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => _edit(t),
                    child: const Text('Editar'),
                  ),
                  if (t.email.isNotEmpty)
                    PopupMenuItem(
                      value: () => _resend(t),
                      child: const Text('Reenviar correo de acceso'),
                    ),
                  PopupMenuItem(
                    value: () => _toggleActive(t),
                    child: Text(t.active ? 'Desactivar' : 'Activar'),
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

/// Creates a tutor (account + profile) or edits one. Pops the saved tutor.
class TutorDialog extends StatefulWidget {
  const TutorDialog({
    super.key,
    required this.repo,
    this.initial,
    this.photoUrl,
  });
  final KuusenseRepository repo;
  final Tutor? initial;

  /// Profile photo of the tutor being edited (shown above the form).
  final Future<String>? photoUrl;

  @override
  State<TutorDialog> createState() => _TutorDialogState();
}

class _TutorDialogState extends State<TutorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.displayName ?? '',
  );
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
  late TutorType? _type = widget.initial?.type;
  bool _busy = false;

  bool get _isNew => widget.initial == null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    Tutor? saved;
    final ok = await runWithFeedback(context, () async {
      if (_isNew) {
        saved = await widget.repo.createTutor(
          email: _email.text,
          displayName: _name.text,
          type: _type!,
        );
      } else {
        await widget.repo.updateTutor(
          widget.initial!.uid,
          displayName: _name.text,
          type: _type!,
        );
        saved = widget.initial;
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isNew) ...[
            Center(
              child: ListenableBuilder(
                listenable: _name,
                builder: (_, _) => KuuPersonAvatar(
                  name: _name.text,
                  photoUrl: widget.photoUrl,
                  size: 88,
                  shadow: true,
                ),
              ),
            ),
            const SizedBox(height: KuuSpacing.lg),
          ],
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => KuuValidators.required(v, 'el nombre'),
          ),
          const SizedBox(height: KuuSpacing.md),
          TextFormField(
            controller: _email,
            enabled: _isNew,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              helperText: _isNew
                  ? 'Le enviaremos un correo para que cree su contraseña.'
                  : 'El correo de una cuenta existente no se puede cambiar.',
            ),
            validator: _isNew ? KuuValidators.email : null,
          ),
          const SizedBox(height: KuuSpacing.md),
          DropdownButtonFormField<TutorType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Tipo de tutor',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              for (final t in TutorType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _type = v),
            validator: (v) => v == null ? 'Elige el tipo de tutor' : null,
          ),
          const SizedBox(height: KuuSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(_isNew ? 'Crear tutor' : 'Guardar'),
          ),
          if (_isNew) ...[
            const SizedBox(height: KuuSpacing.sm),
            Text(
              'El tutor entra a la app móvil con este correo. Si ya tenía una cuenta en KúuSense, '
              'pide al equipo técnico que la habilite.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

IconData tutorTypeIcon(TutorType t) => switch (t) {
  TutorType.family => Icons.family_restroom_rounded,
  TutorType.teacher => Icons.school_rounded,
  TutorType.therapist => Icons.healing_rounded,
};
