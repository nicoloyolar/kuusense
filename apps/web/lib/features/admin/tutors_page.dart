import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import '../dashboard/dash_page.dart';
import 'admin_widgets.dart';

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

class _TutorsPageState extends State<TutorsPage> {
  String _query = '';

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
        'Tutor creado. Le enviamos un correo a ${created.email} para que cree su contraseña.',
      );
    }
  }

  Future<void> _edit(Tutor t) => showFormDialog<Tutor>(
    context,
    title: 'Editar tutor',
    icon: Icons.edit_outlined,
    builder: (_) => TutorDialog(repo: repo, initial: t),
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
    final visible = widget.tutors
        .where(
          (t) =>
              q.isEmpty ||
              t.displayName.toLowerCase().contains(q) ||
              t.email.contains(q),
        )
        .toList();

    return DashPage(
      children: [
        AdminHeader(
          title: 'Tutores',
          subtitle:
              'Familiares, docentes y terapeutas que usan la app. '
              'Solo el administrador crea sus cuentas.',
          action: FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Nuevo tutor'),
          ),
        ),
        const SizedBox(height: KuuSpacing.lg),
        AdminSearchField(
          hint: 'Buscar por nombre o correo',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: KuuSpacing.md),
        if (widget.tutors.isEmpty)
          const AdminEmpty(
            icon: Icons.group_outlined,
            title: 'Aún no hay tutores',
            text: 'Crea el primero con "Nuevo tutor".',
          )
        else if (visible.isEmpty)
          const AdminEmpty(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            text: 'Prueba con otro nombre o correo.',
          )
        else
          KuuSurface(
            child: Column(
              children: [
                for (final (i, t) in visible.indexed) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.outline),
                  _TutorRow(
                    tutor: t,
                    childCount: childCount[t.uid] ?? 0,
                    onEdit: () => _edit(t),
                    onToggleActive: () => _toggleActive(t),
                    onResend: t.email.isEmpty ? null : () => _resend(t),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TutorRow extends StatelessWidget {
  const _TutorRow({
    required this.tutor,
    required this.childCount,
    required this.onEdit,
    required this.onToggleActive,
    required this.onResend,
  });
  final Tutor tutor;
  final int childCount;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Opacity(
      opacity: tutor.active ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KuuSpacing.md,
          vertical: KuuSpacing.sm,
        ),
        child: Row(
          children: [
            KuuIconTile(
              icon: tutorTypeIcon(tutor.type),
              color: KuuColor.brandHighlight,
              size: 44,
              round: true,
            ),
            const SizedBox(width: KuuSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tutor.displayName, style: theme.textTheme.titleMedium),
                  Text(
                    tutor.email.isEmpty ? 'Correo no registrado' : tutor.email,
                    style: muted,
                  ),
                  const SizedBox(height: KuuSpacing.xs),
                  Wrap(
                    spacing: KuuSpacing.sm,
                    runSpacing: KuuSpacing.xs,
                    children: [
                      AdminTag(tutor.type.label),
                      AdminTag(childCount == 1 ? '1 NNA' : '$childCount NNA'),
                      if (!tutor.active)
                        const AdminTag(
                          'Desactivado',
                          color: KuuColor.feedbackError,
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
                PopupMenuItem(value: onEdit, child: const Text('Editar')),
                if (onResend != null)
                  PopupMenuItem(
                    value: onResend!,
                    child: const Text('Reenviar correo de acceso'),
                  ),
                PopupMenuItem(
                  value: onToggleActive,
                  child: Text(tutor.active ? 'Desactivar' : 'Activar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Creates a tutor (account + profile) or edits one. Pops the saved tutor.
class TutorDialog extends StatefulWidget {
  const TutorDialog({super.key, required this.repo, this.initial});
  final KuusenseRepository repo;
  final Tutor? initial;

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
