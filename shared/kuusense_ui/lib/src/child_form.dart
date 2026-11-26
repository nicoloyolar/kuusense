import 'package:flutter/material.dart';
import 'package:kuusense_models/kuusense_models.dart';

import 'avatars.dart';
import 'generated/tokens.g.dart';
import 'validators.dart';

/// What the child (NNA) form collects. Same fields in the mobile app and the
/// web platform.
class ChildFormData {
  const ChildFormData({
    required this.displayName,
    required this.avatarId,
    required this.birthYear,
    this.dunnQuadrant,
  });
  final String displayName;
  final String avatarId;
  final int birthYear;
  final DunnQuadrant? dunnQuadrant;
}

/// Registers a child (with the consent confirmation) or edits one. Used by
/// the tutor app and by the admin's NNA maintainer, so both stay identical.
///
/// [extraFields] go first, inside the same form (e.g. the web's "tutor
/// responsable" selector), so their validators run with the rest.
/// [onSubmit] returns whether saving worked; the caller shows errors and
/// closes the screen.
class KuuChildForm extends StatefulWidget {
  const KuuChildForm({
    super.key,
    required this.onSubmit,
    this.initial,
    this.extraFields = const [],
    this.now,
  });

  /// Null when registering a new child.
  final ChildFormData? initial;
  final Future<bool> Function(ChildFormData data) onSubmit;
  final List<Widget> extraFields;

  /// Clock override for tests.
  final DateTime? now;

  bool get isNew => initial == null;

  /// Children are 5–14 years old; leave margin on both sides.
  static const minAge = 2;
  static const maxAge = 18;

  @override
  State<KuuChildForm> createState() => _KuuChildFormState();
}

class _KuuChildFormState extends State<KuuChildForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.displayName ?? '');
  late String? _avatarId = widget.initial?.avatarId;
  late int? _birthYear = widget.initial?.birthYear;
  late DunnQuadrant? _dunn = widget.initial?.dunnQuadrant;
  bool _consent = false;
  bool _showErrors = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<int> get _years {
    final year = (widget.now ?? DateTime.now()).year;
    final years = [
      for (var y = year - KuuChildForm.minAge; y >= year - KuuChildForm.maxAge; y--) y,
    ];
    final current = widget.initial?.birthYear;
    if (current != null && !years.contains(current)) years.add(current);
    return years;
  }

  bool get _extrasValid => _avatarId != null && (!widget.isNew || _consent);

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showErrors = true);
    if (!valid || !_extrasValid) return;
    setState(() => _busy = true);
    await widget.onSubmit(ChildFormData(
      displayName: _name.text.trim(),
      avatarId: _avatarId!,
      birthYear: _birthYear!,
      dunnQuadrant: _dunn,
    ));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    final now = widget.now ?? DateTime.now();

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in widget.extraFields) ...[f, const SizedBox(height: KuuSpacing.md)],
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Apodo o nombre visible',
              helperText: 'Puedes usar un apodo amigable.',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => KuuValidators.required(v, 'el apodo'),
          ),
          const SizedBox(height: KuuSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: _birthYear,
            decoration: const InputDecoration(
              labelText: 'Año de nacimiento',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
            items: [
              for (final y in _years)
                DropdownMenuItem(value: y, child: Text('$y  (${now.year - y} años aprox.)')),
            ],
            onChanged: (v) => setState(() => _birthYear = v),
            validator: (v) => v == null ? 'Elige el año de nacimiento' : null,
          ),
          const SizedBox(height: KuuSpacing.md),
          DropdownButtonFormField<DunnQuadrant?>(
            initialValue: _dunn,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Perfil sensorial (cuadrante de Dunn)',
              helperText: 'Opcional. Se puede completar más adelante.',
              prefixIcon: Icon(Icons.sensors_rounded),
            ),
            items: [
              const DropdownMenuItem<DunnQuadrant?>(value: null, child: Text('Sin definir')),
              for (final q in DunnQuadrant.values)
                DropdownMenuItem<DunnQuadrant?>(value: q, child: Text(q.label)),
            ],
            onChanged: (v) => setState(() => _dunn = v),
          ),
          const SizedBox(height: KuuSpacing.lg),
          Text('Elige un avatar', style: theme.textTheme.titleMedium),
          const SizedBox(height: KuuSpacing.sm),
          AvatarPicker(
            selectedId: _avatarId,
            onChanged: (id) => setState(() => _avatarId = id),
          ),
          if (_showErrors && _avatarId == null)
            Padding(
              padding: const EdgeInsets.only(top: KuuSpacing.sm),
              child: Text('Elige un avatar', style: errorStyle),
            ),
          if (widget.isNew) ...[
            const SizedBox(height: KuuSpacing.lg),
            _ConsentBox(
              value: _consent,
              showError: _showErrors && !_consent,
              onChanged: (v) => setState(() => _consent = v),
            ),
          ],
          const SizedBox(height: KuuSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(widget.isNew ? 'Registrar' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}

/// The consent confirmation as a bordered, tappable card, so it clearly
/// reads as something to check (and turns red when it is missing).
class _ConsentBox extends StatelessWidget {
  const _ConsentBox({required this.value, required this.showError, required this.onChanged});
  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = showError
        ? scheme.error
        : value
            ? scheme.primary
            : scheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: value ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
          borderRadius: BorderRadius.circular(KuuRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(KuuRadius.md),
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(KuuSpacing.sm, KuuSpacing.md, KuuSpacing.md, KuuSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KuuRadius.md),
                border: Border.all(color: border, width: value || showError ? 2 : 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: value,
                    isError: showError,
                    onChanged: (v) => onChanged(v ?? false),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: KuuSpacing.xs),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consentimiento',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Confirmo que cuento con el consentimiento de la madre, padre o '
                            'cuidador/a para registrar a este niño/a en KúuSense.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: KuuSpacing.xs, left: KuuSpacing.sm),
            child: Text(
              'Debes confirmarlo para continuar',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
