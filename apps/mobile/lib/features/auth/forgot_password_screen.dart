import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'auth_scaffold.dart';

/// Sends a password-reset email. (The mockup also mentions SMS codes; email
/// is what Firebase Auth supports out of the box.)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.auth,
    this.initialEmail = '',
  });
  final AuthService auth;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await runAuthAction(
      () => widget.auth.sendPasswordReset(email: _email.text.trim()),
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
        _sent = error == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthScaffold(
        title: 'Revisa tu correo',
        subtitle:
            'Si existe una cuenta para ${_email.text.trim()}, te enviamos un enlace para '
            'crear una nueva contraseña.',
        showBack: true,
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Volver a ingresar'),
          ),
        ],
      );
    }
    return AuthScaffold(
      title: 'Recuperar contraseña',
      subtitle: 'Te enviaremos un enlace a tu correo',
      showBack: true,
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: KuuValidators.email,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        AuthErrorText(_error),
        const SizedBox(height: KuuSpacing.lg),
        AuthSubmitButton(
          label: 'Enviar enlace',
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
