import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'auth_scaffold.dart';
import 'forgot_password_screen.dart';

/// Tutor login (email + password). Navigation after a successful sign-in is
/// driven by [AuthService.userChanges] at the app root, not by this screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await runAuthAction(
      () => widget.auth.signIn(
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Te damos la bienvenida',
      subtitle: 'Ingresa con tu cuenta de tutor',
      photoHeader: true,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
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
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: KuuValidators.password,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ForgotPasswordScreen(
                  auth: widget.auth,
                  initialEmail: _email.text.trim(),
                ),
              ),
            ),
            child: const Text('¿Olvidaste tu contraseña?'),
          ),
        ),
        AuthErrorText(_error),
        const SizedBox(height: KuuSpacing.md),
        AuthSubmitButton(label: 'Ingresar', busy: _busy, onPressed: _submit),
        const SizedBox(height: KuuSpacing.md),
        Text(
          'Las cuentas de tutor las crea el equipo de KúuSense. Si es tu primera vez, '
          'usa el enlace del correo que te llegó para crear tu contraseña.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        // Planned (REQUISITOS CU-6, P3): sign in with fingerprint / Face ID.
      ],
    );
  }
}
