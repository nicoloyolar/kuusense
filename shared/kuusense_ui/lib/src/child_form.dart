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
    this.birthDate,
    this.dunnQuadrant,
  });
  final String displayName;
  final String avatarId;

  /// Always [birthDate]'s year when [birthDate] is set.
  final int birthYear;

  /// Always set on submit. Null only as [KuuChildForm.initial] for a child
  /// registered before birth dates existed (the form then asks for it,
  /// preselecting [birthYear]).
  final DateTime? birthDate;
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

  /// Earliest selectable birth year. There is no upper age limit (adults
  /// can be registered, e.g. for tests).
  static const firstYear = 1920;

  @override
  State<KuuChildForm> createState() => _KuuChildFormState();
}

class _KuuChildFormState extends State<KuuChildForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.displayName ?? '',
  );
  late String? _avatarId = widget.initial?.avatarId;
  late DateTime? _birthDate = widget.initial?.birthDate;
  late DunnQuadrant? _dunn = widget.initial?.dunnQuadrant;
  bool _consent = false;
  bool _showErrors = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _extrasValid => _avatarId != null && (!widget.isNew || _consent);

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showErrors = true);
    if (!valid || !_extrasValid) return;
    setState(() => _busy = true);
    await widget.onSubmit(
      ChildFormData(
        displayName: _name.text.trim(),
        avatarId: _avatarId!,
        birthYear: _birthDate!.year,
        birthDate: _birthDate,
        dunnQuadrant: _dunn,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    final now = widget.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in widget.extraFields) ...[
            f,
            const SizedBox(height: KuuSpacing.md),
          ],
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
          KuuBirthDateField(
            initial: _birthDate,
            initialYear: widget.initial?.birthYear,
            today: today,
            onChanged: (d) => setState(() => _birthDate = d),
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
              const DropdownMenuItem<DunnQuadrant?>(
                value: null,
                child: Text('Sin definir'),
              ),
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
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
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
  const _ConsentBox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });
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
          color: value
              ? scheme.primary.withValues(alpha: 0.06)
              : scheme.surface,
          borderRadius: BorderRadius.circular(KuuRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(KuuRadius.md),
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(
                KuuSpacing.sm,
                KuuSpacing.md,
                KuuSpacing.md,
                KuuSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KuuRadius.md),
                border: Border.all(
                  color: border,
                  width: value || showError ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: value,
                    isError: showError,
                    onChanged: (v) => onChanged(v ?? false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
            padding: const EdgeInsets.only(
              top: KuuSpacing.xs,
              left: KuuSpacing.sm,
            ),
            child: Text(
              'Debes confirmarlo para continuar',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}

/// "8 años" from the private birth date when known, else "8 años aprox."
/// from the research birth year.
String kuuAgeLabel(Child child, ChildProfile? profile, [DateTime? now]) {
  final exact = profile?.exactAge(now);
  if (exact != null) return '$exact ${exact == 1 ? 'año' : 'años'}';
  return '${child.approximateAge(now)} años aprox.';
}

/// Form data for editing an existing child.
ChildFormData childFormDataOf(Child child, ChildProfile? profile) =>
    ChildFormData(
      displayName: profile?.displayName ?? '',
      avatarId: profile?.avatarId ?? KuuAvatar.all.first.id,
      birthYear: child.birthYear,
      birthDate: profile?.birthDateValue,
      dunnQuadrant: child.dunnQuadrant,
    );

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Date of birth as three dropdowns (day, month, year), easier than a
/// calendar for dates years back. Reports the date only when all three are
/// chosen and form a real date that is not in the future; validates as part
/// of the enclosing [Form].
class KuuBirthDateField extends StatefulWidget {
  const KuuBirthDateField({
    super.key,
    required this.onChanged,
    required this.today,
    this.initial,
    this.initialYear,
  });
  final DateTime? initial;

  /// Preselected year when only the year is known (older records).
  final int? initialYear;
  final DateTime today;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<KuuBirthDateField> createState() => _KuuBirthDateFieldState();
}

class _KuuBirthDateFieldState extends State<KuuBirthDateField> {
  late int? _day = widget.initial?.day;
  late int? _month = widget.initial?.month;
  late int? _year = widget.initial?.year ?? widget.initialYear;

  static int _daysIn(int? month, int? year) =>
      month == null ? 31 : DateTime(year ?? 2000, month + 1, 0).day;

  DateTime? get _date => _day == null || _month == null || _year == null
      ? null
      : DateTime(_year!, _month!, _day!);

  void _set({int? day, int? month, int? year}) {
    setState(() {
      _day = day ?? _day;
      _month = month ?? _month;
      _year = year ?? _year;
      // Keep the day valid for the month (e.g. 31 → 30 in April, 29 → 28).
      final max = _daysIn(_month, _year);
      if (_day != null && _day! > max) _day = max;
    });
    final d = _date;
    widget.onChanged(d == null || d.isAfter(widget.today) ? null : d);
  }

  String? _validate() {
    final d = _date;
    if (d == null) return 'Completa la fecha de nacimiento';
    if (d.isAfter(widget.today)) return 'La fecha no puede ser futura';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final d = _date;
    final age = d == null || d.isAfter(widget.today)
        ? null
        : ChildProfile(
            displayName: '',
            avatarId: '',
            birthDate: ChildProfile.formatBirthDate(d),
          ).exactAge(widget.today);
    return FormField<DateTime>(
      validator: (_) => _validate(),
      builder: (field) => InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha de nacimiento',
          prefixIcon: const Icon(Icons.cake_outlined),
          helperText: age == null
              ? 'Solo la ven los tutores y el administrador.'
              : '$age ${age == 1 ? 'año' : 'años'}',
          errorText: field.errorText,
          contentPadding: const EdgeInsets.fromLTRB(
            0,
            KuuSpacing.sm,
            KuuSpacing.sm,
            KuuSpacing.xs,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _drop<int>(
                hint: 'Día',
                value: _day,
                items: [
                  for (var i = 1; i <= _daysIn(_month, _year); i++) (i, '$i'),
                ],
                onChanged: (v) => _set(day: v),
                field: field,
              ),
            ),
            Expanded(
              flex: 5,
              child: _drop<int>(
                hint: 'Mes',
                value: _month,
                items: [for (var i = 1; i <= 12; i++) (i, _months[i - 1])],
                onChanged: (v) => _set(month: v),
                field: field,
              ),
            ),
            Expanded(
              flex: 4,
              child: _drop<int>(
                hint: 'Año',
                value: _year,
                items: [
                  for (
                    var y = widget.today.year;
                    y >= KuuChildForm.firstYear;
                    y--
                  )
                    (y, '$y'),
                ],
                onChanged: (v) => _set(year: v),
                field: field,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop<T>({
    required String hint,
    required T? value,
    required List<(T, String)> items,
    required ValueChanged<T?> onChanged,
    required FormFieldState<DateTime> field,
  }) => DropdownButtonHideUnderline(
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(KuuRadius.md),
      hint: Text(hint),
      items: [
        for (final (v, label) in items)
          DropdownMenuItem<T>(value: v, child: Text(label)),
      ],
      onChanged: (v) {
        onChanged(v);
        field.didChange(_date);
        if (field.hasError) field.validate();
      },
    ),
  );
}
