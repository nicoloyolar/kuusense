import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/feedback.dart';

/// Creates an invite for [childName] and shows the code to share.
Future<void> showInviteSheet(
  BuildContext context, {
  required String childName,
  required Future<Invite> Function() createInvite,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(childName: childName, createInvite: createInvite),
    );

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.childName, required this.createInvite});
  final String childName;
  final Future<Invite> Function() createInvite;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late final Future<Invite> _invite = widget.createInvite();

  static String _expiry(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}-${two(t.month)} a las ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KuuSpacing.lg, 0, KuuSpacing.lg, KuuSpacing.lg),
        child: FutureBuilder<Invite>(
          future: _invite,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text(genericErrorMessage, style: TextStyle(color: theme.colorScheme.error));
            }
            final invite = snap.data;
            if (invite == null) {
              return const Padding(
                padding: EdgeInsets.all(KuuSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Invitar a otro tutor', style: theme.textTheme.titleLarge),
                const SizedBox(height: KuuSpacing.sm),
                Text(
                  'Comparte este código con la persona que también acompaña a ${widget.childName}. '
                  'Debe ingresarlo en su app, en "Tengo un código de invitación".',
                ),
                const SizedBox(height: KuuSpacing.lg),
                SelectableText(
                  invite.code,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: KuuSpacing.sm),
                Text(
                  'Sirve una sola vez y vence el ${_expiry(invite.expiresAtMs)}.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: KuuSpacing.lg),
                FilledButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar código'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: invite.code));
                    messenger.showSnackBar(const SnackBar(content: Text('Código copiado')));
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
