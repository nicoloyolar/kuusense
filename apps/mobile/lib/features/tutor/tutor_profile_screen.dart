import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

/// The tutor edits their own name and type (the account and email are
/// managed by an admin on the web platform).
class TutorProfileScreen extends StatefulWidget {
  const TutorProfileScreen({
    super.key,
    required this.onSave,
    this.initialName,
    this.initialType,
  });

  final Future<void> Function(String name, TutorType type) onSave;
  final String? initialName;
  final TutorType? initialType;

  @override
  State<TutorProfileScreen> createState() => _TutorProfileScreenState();
}

class _TutorProfileScreenState extends State<TutorProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late TutorType? _type = widget.initialType;
  bool _showTypeError = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showTypeError = _type == null);
    if (!valid || _type == null) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(context, () => widget.onSave(_name.text.trim(), _type!));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
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
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: '¿Cómo quieres que te llamen?',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => KuuValidators.required(v, 'tu nombre'),
                    ),
                    const SizedBox(height: KuuSpacing.md),
                    Text('Soy…', style: theme.textTheme.titleMedium),
                    const SizedBox(height: KuuSpacing.sm),
                    RadioGroup<TutorType>(
                      groupValue: _type,
                      onChanged: (v) => setState(() {
                        _type = v;
                        _showTypeError = false;
                      }),
                      child: Column(
                        children: [
                          for (final t in TutorType.values)
                            RadioListTile<TutorType>(
                              value: t,
                              title: Text(t.label),
                              secondary: Icon(_iconFor(t)),
                              contentPadding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                    if (_showTypeError)
                      Text('Elige una opción', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: KuuSpacing.lg),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Guardar'),
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

  static IconData _iconFor(TutorType t) => switch (t) {
        TutorType.family => Icons.family_restroom_rounded,
        TutorType.teacher => Icons.school_rounded,
        TutorType.therapist => Icons.healing_rounded,
      };
}
