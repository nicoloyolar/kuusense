import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import '../common/page_title.dart';

import 'dashboard_shell.dart';

/// Lets in only staff (researcher / admin). A tutor account that signs in on
/// the web sees a short explanation and can sign out.
class StaffGate extends StatefulWidget {
  const StaffGate({super.key, required this.auth});
  final AuthService auth;

  @override
  State<StaffGate> createState() => _StaffGateState();
}

class _StaffGateState extends State<StaffGate> {
  final repo = KuusenseRepository();
  late final Stream<StaffMember?> _staff = repo.watchMyStaffMembership();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StaffMember?>(
      stream: _staff,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final staff = snap.data;
        if (staff == null || !staff.active) {
          return _NoAccess(auth: widget.auth, deactivated: staff != null);
        }
        return DashboardShell(auth: widget.auth, repo: repo, staff: staff);
      },
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.auth, this.deactivated = false});
  final AuthService auth;

  /// A staff member the admin deactivated (not a tutor account).
  final bool deactivated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageTitle(
      'Sin acceso',
      child: Scaffold(
        body: KuuBrandBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(KuuSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KuusenseLogo(height: 96),
                    const SizedBox(height: KuuSpacing.lg),
                    Text(
                      deactivated
                          ? 'Tu acceso a la plataforma está desactivado'
                          : 'Tu cuenta no tiene acceso a la plataforma',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: KuuSpacing.sm),
                    Text(
                      deactivated
                          ? 'Si crees que es un error, contacta al administrador de KúuSense.'
                          : 'La plataforma es para el equipo de investigación y administración. '
                                'Si eres tutor o tutora, usa la app móvil de KúuSense.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: KuuSpacing.lg),
                    OutlinedButton(
                      onPressed: auth.signOut,
                      child: const Text('Cerrar sesión'),
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
