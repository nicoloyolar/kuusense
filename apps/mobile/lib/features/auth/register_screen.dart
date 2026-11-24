import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'auth_scaffold.dart';

/// Tutor account creation. Tutor type (family / teacher / therapist) and the
/// child's profile are collected after sign-up, in the onboarding (Fase 0).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!valid || !_acceptedTerms) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await runAuthAction(() => widget.auth.register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        ));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    // On success the root listens to userChanges; leave the auth stack.
    if (error == null) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget passwordToggle() => IconButton(
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        );

    return AuthScaffold(
      title: 'Crear cuenta',
      subtitle: 'Para familiares, docentes y terapeutas',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Tu nombre',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => KuuValidators.required(v, 'tu nombre'),
                ),
                const SizedBox(height: KuuSpacing.md),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: KuuValidators.email,
                ),
                const SizedBox(height: KuuSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo ${KuuValidators.minPasswordLength} caracteres, con letras y números',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: passwordToggle(),
                  ),
                  validator: KuuValidators.newPassword,
                ),
                const SizedBox(height: KuuSpacing.md),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Repite la contraseña',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: KuuValidators.confirm(() => _password.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KuuSpacing.sm),
        CheckboxListTile(
          value: _acceptedTerms,
          onChanged: (v) => setState(() {
            _acceptedTerms = v ?? false;
            if (_acceptedTerms) _showTermsError = false;
          }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          // TODO(content): link to the real terms and privacy policy.
          title: const Text('Acepto los términos de uso y la política de privacidad'),
          subtitle: _showTermsError
              ? Text('Debes aceptar para continuar', style: TextStyle(color: theme.colorScheme.error))
              : null,
        ),
        AuthErrorText(_error),
        const SizedBox(height: KuuSpacing.md),
        AuthSubmitButton(label: 'Crear cuenta', busy: _busy, onPressed: _submit),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Ya tengo una cuenta'),
        ),
      ],
    );
  }
}
