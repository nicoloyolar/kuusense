import 'package:emotibit/emotibit.dart';
import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'recording_controller.dart';
import 'session_context_sheet.dart';
import 'sparkline.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    String fmt(double? v, [int d = 1]) =>
        v == null ? '—' : v.toStringAsFixed(d);

    return Scaffold(
      appBar: AppBar(
        title: Text(c.connection?.device.deviceId ?? 'EmotiBit'),
        actions: [
          if (!c.isRecording)
            IconButton(
              onPressed: c.disconnect,
              icon: const Icon(Icons.link_off),
              tooltip: 'Desconectar',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _Metric(
                'Frec. cardíaca',
                fmt(c.latest[TypeTag.heartRate], 0),
                'bpm',
                Icons.favorite,
              ),
              _Metric(
                'EDA',
                fmt(c.latest[TypeTag.eda], 2),
                'µS',
                Icons.water_drop,
              ),
              _Metric(
                'Temperatura',
                fmt(c.temperature),
                '°C',
                Icons.thermostat,
              ),
              _Metric(
                'Batería',
                fmt(c.latest[TypeTag.batteryPercent], 0),
                '%',
                Icons.battery_std,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('PPG (infrarrojo)', style: theme.textTheme.labelLarge),
          Sparkline(
            values: c.traces[TypeTag.ppgInfrared]!,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          Text('EDA', style: theme.textTheme.labelLarge),
          Sparkline(
            values: c.traces[TypeTag.eda]!,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          _RecordingPanel(controller: c),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.unit, this.icon);
  final String label, value, unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: t.labelSmall),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: value, style: t.titleLarge),
                        TextSpan(text: ' $unit', style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({required this.controller});
  final RecordingController controller;

  Future<void> _start(BuildContext context) async {
    final ctx = await showSessionContextSheet(context);
    if (ctx != null) await controller.startRecording(context: ctx);
  }

  Future<void> _askNote(BuildContext context) async {
    final text = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar nota'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: SessionEvent.maxNoteLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Lo que observaste, sin nombres',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, text.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (note != null && note.trim().isNotEmpty) {
      controller.addEvent(BehaviorCatalog.noteId, note: note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);

    if (c.isRecording) {
      final startedAt = c.session?.startedAtMs ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fiber_manual_record, color: theme.colorScheme.error),
              const SizedBox(width: KuuSpacing.xs),
              Text(
                'Grabando  ${_clock(c.elapsed)}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: KuuSpacing.md),
          Text('¿Qué observas?', style: theme.textTheme.titleSmall),
          const SizedBox(height: KuuSpacing.sm),
          Wrap(
            spacing: KuuSpacing.sm,
            runSpacing: KuuSpacing.sm,
            children: [
              for (final m in BehaviorCatalog.markers)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => c.addEvent(m.id),
                  child: Text(m.label),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => _askNote(context),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Nota'),
              ),
            ],
          ),
          if (c.events.isNotEmpty) ...[
            const SizedBox(height: KuuSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Marcado (${c.events.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: c.undoLastEvent,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Deshacer último'),
                ),
              ],
            ),
            for (final e in c.events.reversed.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  _clock(Duration(milliseconds: e.atMs - startedAt)),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  e.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          const SizedBox(height: KuuSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: c.stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Detener y subir'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (c.uploadState) {
          UploadState.uploading => const ListTile(
            leading: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Subiendo sesión…'),
          ),
          UploadState.done => const ListTile(
            leading: Icon(Icons.cloud_done),
            title: Text('Sesión subida'),
          ),
          UploadState.failed => ListTile(
            leading: Icon(Icons.error, color: theme.colorScheme.error),
            title: const Text(
              'Error al subir; los datos siguen en el teléfono',
            ),
            subtitle: Text(c.uploadError ?? ''),
            trailing: TextButton(
              onPressed: c.retryUpload,
              child: const Text('Reintentar'),
            ),
          ),
          UploadState.idle => const SizedBox.shrink(),
        },
        FilledButton.icon(
          onPressed: c.isConnected && c.uploadState != UploadState.uploading
              ? () => _start(context)
              : null,
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Iniciar grabación'),
        ),
      ],
    );
  }
}

String _clock(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
