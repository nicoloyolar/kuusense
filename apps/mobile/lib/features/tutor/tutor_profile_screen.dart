import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

/// Tutor profile form. Shown once after sign-up ([isOnboarding]) and later
/// from the home menu to edit it.
class TutorProfileScreen extends StatefulWidget {
  const TutorProfileScreen({
    super.key,
    required this.onSave,
    this.initialName,
    this.initialType,
    this.isOnboarding = false,
    this.onSignOut,
  });

  final Future<void> Function(String name, TutorType type) onSave;
  final String? initialName;
  final TutorType? initialType;
  final bool isOnboarding;
  final VoidCallback? onSignOut;

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
    if (ok && !widget.isOnboarding) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Tu perfil' : 'Editar perfil'),
        automaticallyImplyLeading: !widget.isOnboarding,
        actions: [
          if (widget.onSignOut != null)
            TextButton(onPressed: widget.onSignOut, child: const Text('Cerrar sesión')),
        ],
      ),
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
                    if (widget.isOnboarding) ...[
                      Text('¡Hola! Cuéntanos un poco de ti', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: KuuSpacing.sm),
                      Text(
                        'Así sabrán quién eres los demás tutores del niño o niña.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: KuuSpacing.lg),
                    ],
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
                          : Text(widget.isOnboarding ? 'Continuar' : 'Guardar'),
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
