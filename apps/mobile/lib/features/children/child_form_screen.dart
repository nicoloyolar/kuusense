import 'package:flutter/material.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';
import 'avatars.dart';

class ChildFormData {
  const ChildFormData({required this.displayName, required this.avatarId, required this.birthYear});
  final String displayName;
  final String avatarId;
  final int birthYear;
}

/// Registers a new child (with the consent confirmation) or edits one.
class ChildFormScreen extends StatefulWidget {
  const ChildFormScreen({super.key, required this.onSubmit, this.initial, this.now});

  /// Null when registering a new child.
  final ChildFormData? initial;
  final Future<void> Function(ChildFormData data) onSubmit;

  /// Clock override for tests.
  final DateTime? now;

  bool get isNew => initial == null;

  @override
  State<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends State<ChildFormScreen> {
  /// Children are 5–14 years old; leave margin on both sides.
  static const minAge = 2;
  static const maxAge = 18;

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.displayName ?? '');
  late String? _avatarId = widget.initial?.avatarId;
  late int? _birthYear = widget.initial?.birthYear;
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
    final years = [for (var y = year - minAge; y >= year - maxAge; y--) y];
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
    final ok = await runWithFeedback(
      context,
      () => widget.onSubmit(ChildFormData(
        displayName: _name.text.trim(),
        avatarId: _avatarId!,
        birthYear: _birthYear!,
      )),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    final now = widget.now ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'Registrar niño/a' : 'Editar datos')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KuuSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Apodo o nombre visible',
                        helperText: 'Puedes usar un apodo. No hace falta el nombre completo.',
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
                      CheckboxListTile(
                        value: _consent,
                        onChanged: (v) => setState(() => _consent = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Confirmo que cuento con el consentimiento de la madre, padre o '
                          'cuidador/a para registrar a este niño/a en KúuSense.',
                        ),
                        subtitle: _showErrors && !_consent
                            ? Text('Debes confirmarlo para continuar', style: errorStyle)
                            : null,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
