import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Login for researchers and admins. There is no self sign-up on the web:
/// these accounts are created by an admin (to confirm with the client).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(KuuSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _LoginForm(auth: auth, showLogo: !wide),
              ),
            ),
          );
          if (!wide) return KuuBrandBackground(child: SafeArea(child: form));
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 4, child: form),
            ],
          );
        },
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KuuBrandBackground(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.xl * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const KuusenseLogo(height: 140),
            const SizedBox(height: KuuSpacing.xl),
            Text(
              'Plataforma de investigación y seguimiento',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: KuuSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Sesiones, señales fisiológicas y evolución de cada NNA, '
                'en un solo lugar y con acceso seguro.',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.auth, required this.showLogo});
  final AuthService auth;
  final bool showLogo;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
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
    String? error;
    try {
      await widget.auth.signIn(email: _email.text.trim(), password: _password.text);
    } on AuthFailure catch (e) {
      error = e.message;
    } catch (_) {
      error = const AuthFailure(AuthFailureReason.unknown).message;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showLogo) ...[
              const KuusenseLogo(height: 100),
              const SizedBox(height: KuuSpacing.lg),
            ],
            Text('Iniciar sesión', style: theme.textTheme.headlineSmall),
            const SizedBox(height: KuuSpacing.xs),
            Text(
              'Acceso para equipo de investigación y administración',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: KuuSpacing.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
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
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: KuuValidators.password,
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ForgotPasswordDialog(auth: widget.auth, initialEmail: _email.text.trim()),
                ),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: KuuSpacing.md),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Ingresar'),
            ),
            const SizedBox(height: KuuSpacing.lg),
            Text(
              '¿No tienes cuenta? Solicítala al administrador de KúuSense.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.auth, required this.initialEmail});
  final AuthService auth;
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
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
    try {
      await widget.auth.sendPasswordReset(email: _email.text.trim());
      _sent = true;
    } on AuthFailure catch (e) {
      _error = e.message;
    } catch (_) {
      _error = const AuthFailure(AuthFailureReason.unknown).message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_sent ? 'Revisa tu correo' : 'Recuperar contraseña'),
      content: SizedBox(
        width: 380,
        child: _sent
            ? Text('Si existe una cuenta para ${_email.text.trim()}, te enviamos un enlace '
                'para crear una nueva contraseña.')
            : Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Te enviaremos un enlace a tu correo.'),
                  const SizedBox(height: KuuSpacing.md),
                  TextFormField(
                    controller: _email,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    validator: KuuValidators.email,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: KuuSpacing.md),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ]),
              ),
      ),
      actions: _sent
          ? [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              TextButton(onPressed: _busy ? null : _submit, child: const Text('Enviar enlace')),
            ],
    );
  }
}
