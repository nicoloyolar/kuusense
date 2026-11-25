import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Asks for the session context before recording starts. Returns the chosen
/// context (possibly empty if the tutor skips it), or null if dismissed.
Future<SessionContext?> showSessionContextSheet(BuildContext context) =>
    showModalBottomSheet<SessionContext>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SessionContextSheet(),
    );

class _SessionContextSheet extends StatefulWidget {
  const _SessionContextSheet();

  @override
  State<_SessionContextSheet> createState() => _SessionContextSheetState();
}

class _SessionContextSheetState extends State<_SessionContextSheet> {
  SessionPlace? _place;
  SessionActivity? _activity;
  final Set<TutorType> _present = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: KuuSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: KuuSpacing.sm),
          Wrap(
            spacing: KuuSpacing.sm,
            runSpacing: KuuSpacing.sm,
            children: chips,
          ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KuuSpacing.lg,
          0,
          KuuSpacing.lg,
          KuuSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Antes de grabar', style: theme.textTheme.headlineSmall),
            const SizedBox(height: KuuSpacing.xs),
            Text(
              'Cuéntanos el contexto. Es opcional y ayuda a entender las señales.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            section('¿Dónde?', [
              for (final p in SessionPlace.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _place == p,
                  onSelected: (on) => setState(() => _place = on ? p : null),
                ),
            ]),
            section('¿Qué está haciendo?', [
              for (final a in SessionActivity.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _activity == a,
                  onSelected: (on) => setState(() => _activity = on ? a : null),
                ),
            ]),
            section('¿Quiénes están presentes?', [
              for (final t in TutorType.values)
                FilterChip(
                  label: Text(t.label),
                  selected: _present.contains(t),
                  onSelected: (on) =>
                      setState(() => on ? _present.add(t) : _present.remove(t)),
                ),
            ]),
            const SizedBox(height: KuuSpacing.lg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                SessionContext(
                  place: _place,
                  activity: _activity,
                  present: _present.toList(),
                ),
              ),
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Comenzar grabación'),
            ),
            const SizedBox(height: KuuSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, const SessionContext()),
              child: const Text('Omitir y comenzar'),
            ),
          ],
        ),
      ),
    );
  }
}
