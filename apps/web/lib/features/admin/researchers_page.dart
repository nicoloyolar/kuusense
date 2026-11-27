import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/data_table.dart';
import '../common/feedback.dart';
import '../common/panel.dart';
import '../dashboard/session_cells.dart';

/// Admin maintainer of researchers: create, edit their name, deactivate and
/// resend the access email. Only the researcher role; admins are managed
/// with admin tooling and never listed here.
class ResearchersPage extends StatefulWidget {
  const ResearchersPage({super.key, required this.repo});
  final KuusenseRepository repo;

  @override
  State<ResearchersPage> createState() => _ResearchersPageState();
}

enum _ActiveFilter { all, active, inactive }

class _ResearchersPageState extends State<ResearchersPage> {
  late final Stream<List<StaffMember>> _staff = widget.repo.watchStaff();
  String _query = '';
  _ActiveFilter _active = _ActiveFilter.all;

  KuusenseRepository get repo => widget.repo;

  String _name(StaffMember m) =>
      m.displayName.isNotEmpty ? m.displayName : m.email;

  Future<void> _create() async {
    final created = await showFormDialog<StaffMember>(
      context,
      title: 'Nuevo investigador',
      icon: Icons.person_add_alt_1_rounded,
      builder: (_) => _ResearcherDialog(repo: repo),
    );
    if (created != null && mounted) {
      showMessage(
        context,
        KuusenseEnv.testPassword.isNotEmpty
            ? 'Investigador creado. Período de pruebas: entra con ${created.email} y la contraseña de pruebas.'
            : 'Investigador creado. Le enviamos un correo a ${created.email} para que cree su contraseña.',
      );
    }
  }

  Future<void> _edit(StaffMember m) => showFormDialog<StaffMember>(
    context,
    title: 'Editar investigador',
    icon: Icons.edit_outlined,
    builder: (_) => _ResearcherDialog(repo: repo, initial: m),
  );

  Future<void> _toggleActive(StaffMember m) async {
    if (m.active) {
      final ok = await confirmDialog(
        context,
        title: 'Desactivar a ${_name(m)}',
        message:
            'No podrá entrar a la plataforma ni ver los datos de investigación hasta que '
            'lo vuelvas a activar. Su cuenta se conserva.',
        confirmLabel: 'Desactivar',
        destructive: true,
        icon: Icons.person_off_outlined,
      );
      if (!ok || !mounted) return;
    }
    await runWithFeedback(
      context,
      () => repo.setResearcherActive(m.uid, !m.active),
    );
  }

  Future<void> _resend(StaffMember m) async {
    final ok = await runWithFeedback(
      context,
      () => repo.resendAccessEmail(m.email),
    );
    if (ok && mounted) {
      showMessage(context, 'Correo de acceso enviado a ${m.email}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StaffMember>>(
      stream: _staff,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('No se pudo cargar el equipo.\n${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _build(context, snap.data!);
      },
    );
  }

  Widget _build(BuildContext context, List<StaffMember> staff) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final researchers = staff
        .where((m) => m.role == StaffRole.researcher)
        .toList();
    final rows = researchers.where((m) {
      if (_active == _ActiveFilter.active && !m.active) return false;
      if (_active == _ActiveFilter.inactive && m.active) return false;
      return q.isEmpty ||
          _name(m).toLowerCase().contains(q) ||
          m.email.contains(q);
    }).toList();
    final activeCount = researchers.where((m) => m.active).length;

    return KuuPageBody(
      children: [
        KuuPageHeader(
          title: 'Investigadores',
          subtitle:
              '$activeCount activos de ${researchers.length}. '
              'Ven los datos seudónimos de investigación (sesiones y señales), nunca apodos ni datos de tutores.',
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _create,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Nuevo investigador'),
            ),
          ],
        ),
        const SizedBox(height: KuuSpacing.lg),
        KuuDataTable<StaffMember>(
          rows: rows,
          rowKey: (m) => m.uid,
          onRowTap: _edit,
          initialSort: 0,
          emptyText: researchers.isEmpty
              ? 'Aún no hay investigadores. Crea el primero con "Nuevo investigador".'
              : 'No hay personas con estos filtros.',
          toolbar: KuuToolbar(
            children: [
              KuuSearchField(
                hint: 'Buscar por nombre o correo',
                onChanged: (v) => setState(() => _query = v),
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
              label: 'Persona',
              flex: 4,
              sortBy: (m) => _name(m).toLowerCase(),
              cell: (m) => Row(
                children: [
                  Opacity(
                    opacity: m.active ? 1 : 0.5,
                    child: KuuPersonAvatar(name: _name(m), size: 34),
                  ),
                  const SizedBox(width: KuuSpacing.sm),
                  Flexible(
                    child: Text(
                      _name(m),
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
              sortBy: (m) => m.email,
              cell: (m) => m.email.isEmpty
                  ? const MutedText('No registrado')
                  : Text(m.email),
            ),
            KuuColumn(
              label: 'Estado',
              flex: 2,
              sortBy: (m) => m.active ? 0 : 1,
              cell: (m) => m.active
                  ? const KuuStatusBadge('Activo', color: KuuColor.stateStable)
                  : const KuuStatusBadge(
                      'Desactivado',
                      color: KuuColor.feedbackError,
                    ),
            ),
            KuuColumn(
              label: 'Creado',
              flex: 2,
              sortBy: (m) => m.createdAtMs,
              cell: (m) => m.createdAtMs == 0
                  ? const MutedText('—')
                  : MutedText(formatDate(m.createdAtMs)),
            ),
            KuuColumn(
              label: '',
              width: 56,
              alignEnd: true,
              cell: (m) => PopupMenuButton<VoidCallback>(
                tooltip: 'Acciones',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => _edit(m),
                    child: const Text('Editar'),
                  ),
                  if (m.email.isNotEmpty)
                    PopupMenuItem(
                      value: () => _resend(m),
                      child: const Text('Reenviar correo de acceso'),
                    ),
                  PopupMenuItem(
                    value: () => _toggleActive(m),
                    child: Text(m.active ? 'Desactivar' : 'Activar'),
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

/// Creates a researcher (account + staff doc) or edits their name. Pops the
/// saved member.
class _ResearcherDialog extends StatefulWidget {
  const _ResearcherDialog({required this.repo, this.initial});
  final KuusenseRepository repo;
  final StaffMember? initial;

  @override
  State<_ResearcherDialog> createState() => _ResearcherDialogState();
}

class _ResearcherDialogState extends State<_ResearcherDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.displayName ?? '',
  );
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
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
    StaffMember? saved;
    final ok = await runWithFeedback(context, () async {
      if (_isNew) {
        saved = await widget.repo.createResearcher(
          email: _email.text,
          displayName: _name.text,
        );
      } else {
        await widget.repo.updateResearcher(
          widget.initial!.uid,
          displayName: _name.text,
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
          const SizedBox(height: KuuSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(_isNew ? 'Crear investigador' : 'Guardar'),
          ),
          if (_isNew) ...[
            const SizedBox(height: KuuSpacing.sm),
            Text(
              'Entra a esta plataforma web con este correo. Si el correo ya tiene una cuenta en '
              'KúuSense (por ejemplo, como tutor), pide al equipo técnico que le dé el acceso.',
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
