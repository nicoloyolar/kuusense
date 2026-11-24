import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

/// A tutor enters the code another tutor shared to follow the same child.
class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key, required this.onJoin});

  /// Links the tutor; throws [InviteFailure] for bad codes.
  final Future<void> Function(String code) onJoin;

  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (Invite.normalize(_code.text).length != Invite.codeLength) {
      setState(() => _error = 'El código tiene ${Invite.codeLength} caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      await widget.onJoin(_code.text);
    } catch (e) {
      error = errorMessage(e);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme con un código')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(KuuSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pide el código a otro tutor del niño/a. Lo encuentra en la ficha del niño/a, '
                    'en "Invitar a otro tutor".',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: KuuSpacing.lg),
                  TextField(
                    controller: _code,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: Invite.codeLength,
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (old, value) => value.copyWith(text: value.text.toUpperCase()),
                      ),
                    ],
                    style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 6),
                    decoration: InputDecoration(labelText: 'Código', errorText: _error),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: KuuSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Unirme'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
