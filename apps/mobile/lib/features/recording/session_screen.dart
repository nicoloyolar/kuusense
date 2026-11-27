import 'dart:io';

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

  /// EDA at or below this reads as "no skin contact" (the device reports
  /// about 0.03 µS when the electrodes touch nothing).
  static const _noContactEda = 0.05;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    String fmt(double? v, [int d = 1]) =>
        v == null ? '—' : v.toStringAsFixed(d);
    final eda = c.latest[TypeTag.eda];
    final battery = c.latest[TypeTag.batteryPercent];

    return Scaffold(
      appBar: AppBar(
        title: Text(c.isRecording ? 'Grabando' : 'En vivo'),
        actions: [
          // iPhone keeps the screen on while recording; a black screen
          // saves battery and avoids accidental taps.
          if (c.isRecording && Platform.isIOS)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  opaque: true,
                  pageBuilder: (_, _, _) => _DimmedScreen(controller: c),
                ),
              ),
              icon: const Icon(Icons.dark_mode_outlined),
              tooltip: 'Oscurecer pantalla',
            ),
          if (!c.isRecording)
            IconButton(
              onPressed: c.disconnect,
              icon: const Icon(Icons.link_off_rounded),
              tooltip: 'Desconectar',
            ),
        ],
      ),
      bottomNavigationBar: _BottomAction(controller: c),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KuuSpacing.md,
          KuuSpacing.xs,
          KuuSpacing.md,
          KuuSpacing.lg,
        ),
        children: [
          if (c.isReconnecting) ...[
            _ReconnectingBanner(controller: c),
            const SizedBox(height: KuuSpacing.md),
          ],
          _HeroCard(controller: c),
          const SizedBox(height: KuuSpacing.md),
          if (eda != null && eda <= _noContactEda) ...[
            const _Hint(
              icon: Icons.touch_app_outlined,
              color: KuuColor.stateAlert,
              text:
                  'La EDA casi no marca: puede que el sensor no esté tocando bien la piel. '
                  'Ajústalo en la yema de los dedos.',
            ),
            const SizedBox(height: KuuSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'EDA',
                  value: fmt(eda, 2),
                  unit: 'µS',
                  icon: Icons.water_drop_rounded,
                  color: KuuColor.brandHighlight,
                ),
              ),
              const SizedBox(width: KuuSpacing.sm),
              Expanded(
                child: _Metric(
                  label: 'Temp.',
                  value: fmt(c.temperature),
                  unit: '°C',
                  icon: Icons.thermostat_rounded,
                  color: KuuColor.stateAlert,
                ),
              ),
              const SizedBox(width: KuuSpacing.sm),
              Expanded(
                child: _Metric(
                  label: 'Batería',
                  value: fmt(battery, 0),
                  unit: '%',
                  icon: _batteryIcon(battery),
                  color: battery != null && battery < 20
                      ? KuuColor.feedbackError
                      : KuuColor.brandSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: KuuSpacing.md),
          KuuSurface(
            child: Padding(
              padding: const EdgeInsets.all(KuuSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Señales en vivo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: KuuSpacing.md),
                  _SignalLabel(
                    color: KuuColor.brandSecondary,
                    title: 'Pulso',
                    subtitle: 'PPG infrarrojo',
                  ),
                  const SizedBox(height: KuuSpacing.xs),
                  Sparkline(
                    values: c.traces[TypeTag.ppgInfrared]!,
                    color: KuuColor.brandSecondary,
                    height: 72,
                  ),
                  const SizedBox(height: KuuSpacing.md),
                  _SignalLabel(
                    color: KuuColor.brandPrimary,
                    title: 'Actividad electrodérmica',
                    subtitle: 'EDA',
                  ),
                  const SizedBox(height: KuuSpacing.xs),
                  Sparkline(
                    values: c.traces[TypeTag.eda]!,
                    color: KuuColor.brandPrimary,
                    height: 72,
                  ),
                ],
              ),
            ),
          ),
          if (c.isRecording) ...[
            const SizedBox(height: KuuSpacing.md),
            _MarkersCard(controller: c),
          ] else ...[
            const SizedBox(height: KuuSpacing.md),
            _UploadStatus(controller: c),
          ],
        ],
      ),
    );
  }
}

IconData _batteryIcon(double? pct) => switch (pct) {
  null => Icons.battery_unknown_rounded,
  < 20 => Icons.battery_alert_rounded,
  < 50 => Icons.battery_3_bar_rounded,
  < 80 => Icons.battery_5_bar_rounded,
  _ => Icons.battery_full_rounded,
};

/// Brand gradient card: who and which device, live state, heart rate and,
/// while recording, the session clock.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final hr = c.latest[TypeTag.heartRate];
    const onBrand = KuuColor.lightSurface;
    final soft = onBrand.withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsets.all(KuuSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KuuRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KuuColor.brandHighlight, KuuColor.brandPrimary],
        ),
        boxShadow: [
          BoxShadow(
            color: KuuColor.brandPrimary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LiveDot(
                color: c.isRecording
                    ? KuuColor.statePreCrisis
                    : KuuColor.brandSecondary,
              ),
              const SizedBox(width: KuuSpacing.sm),
              Text(
                c.isReconnecting
                    ? 'Reconectando…'
                    : c.isRecording
                    ? 'Grabando'
                    : 'Conectado',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onBrand,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  c.connection?.device.deviceId ?? 'EmotiBit',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: soft),
                ),
              ),
            ],
          ),
          if (c.childLabel != null) ...[
            const SizedBox(height: KuuSpacing.xs),
            Text(
              c.childLabel!,
              style: theme.textTheme.titleLarge?.copyWith(
                color: onBrand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: KuuSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: soft, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Frecuencia cardíaca',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: soft,
                          ),
                        ),
                      ],
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: hr == null ? '—' : hr.toStringAsFixed(0),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: onBrand,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: '  bpm',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: soft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (c.isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KuuSpacing.md,
                    vertical: KuuSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: onBrand.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(KuuRadius.pill),
                  ),
                  child: Text(
                    _clock(c.elapsed),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onBrand,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pulsing dot (live indicator).
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});
  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 14,
    child: AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 6 + 8 * _anim.value,
            height: 6 + 8 * _anim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.5 * (1 - _anim.value)),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              border: Border.all(color: KuuColor.lightSurface, width: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });
  final String label, value, unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.sm + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KuuIconTile(icon: icon, color: color, size: 34, round: true),
            const SizedBox(height: KuuSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalLabel extends StatelessWidget {
  const _SignalLabel({
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final Color color;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: KuuSpacing.sm),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: KuuSpacing.xs),
        Text(
          '· $subtitle',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(KuuSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(KuuRadius.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: KuuSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// While recording: one-tap behavior markers, a free note and the latest
/// marks with undo.
class _MarkersCard extends StatelessWidget {
  const _MarkersCard({required this.controller});
  final RecordingController controller;

  Future<void> _askNote(BuildContext context) async {
    final text = TextEditingController();
    final note = await showKuuDialog<String>(
      context,
      builder: (ctx) => KuuDialog(
        icon: Icons.edit_note_rounded,
        title: 'Agregar nota',
        message: 'Lo que observaste, sin nombres ni datos que identifiquen.',
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: SessionEvent.maxNoteLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej.: se calmó con música suave',
          ),
        ),
        primaryLabel: 'Agregar',
        onPrimary: () => Navigator.pop(ctx, text.text),
        secondaryLabel: 'Cancelar',
        onSecondary: () => Navigator.pop(ctx),
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
    final scheme = theme.colorScheme;
    final startedAt = c.session?.startedAtMs ?? 0;
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Qué observas?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Toca para marcar el momento en la grabación.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: KuuSpacing.md),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - KuuSpacing.sm) / 2;
                return Wrap(
                  spacing: KuuSpacing.sm,
                  runSpacing: KuuSpacing.sm,
                  children: [
                    for (final m in BehaviorCatalog.markers)
                      SizedBox(
                        width: w,
                        child: _MarkerButton(
                          label: m.label,
                          onTap: () => c.addEvent(m.id),
                        ),
                      ),
                    SizedBox(
                      width: w,
                      child: _MarkerButton(
                        label: 'Nota',
                        icon: Icons.edit_note_rounded,
                        outlined: true,
                        onTap: () => _askNote(context),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (c.events.isNotEmpty) ...[
              const SizedBox(height: KuuSpacing.md),
              Divider(color: scheme.outlineVariant, height: 1),
              const SizedBox(height: KuuSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Marcado (${c.events.length})',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: c.undoLastEvent,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Deshacer último'),
                  ),
                ],
              ),
              for (final e in c.events.reversed.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(KuuRadius.pill),
                        ),
                        child: Text(
                          _clock(Duration(milliseconds: e.atMs - startedAt)),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: KuuSpacing.sm),
                      Expanded(
                        child: Text(
                          e.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarkerButton extends StatelessWidget {
  const _MarkerButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: outlined
          ? Colors.transparent
          : scheme.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KuuRadius.md),
        side: BorderSide(
          color: outlined
              ? scheme.outline
              : scheme.primary.withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KuuSpacing.sm,
              vertical: KuuSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Upload result after a recording (nothing while idle).
class _UploadStatus extends StatelessWidget {
  const _UploadStatus({required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    return switch (c.uploadState) {
      UploadState.idle => const SizedBox.shrink(),
      UploadState.uploading => const _Hint(
        icon: Icons.cloud_upload_outlined,
        color: KuuColor.feedbackInfo,
        text: 'Subiendo la sesión…',
      ),
      UploadState.done => const _Hint(
        icon: Icons.cloud_done_rounded,
        color: KuuColor.feedbackSuccess,
        text:
            'Sesión subida. Ya se puede ver en el historial y en la plataforma.',
      ),
      UploadState.failed => Container(
        padding: const EdgeInsets.all(KuuSpacing.md),
        decoration: BoxDecoration(
          color: KuuColor.feedbackError.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KuuRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: KuuColor.feedbackError,
                ),
                const SizedBox(width: KuuSpacing.sm),
                Expanded(
                  child: Text(
                    'No se pudo subir. Los datos siguen en el teléfono y se '
                    'reintentará solo.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if ((c.uploadError ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Text(
                  c.uploadError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: c.retryUpload,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

/// Main action pinned at the bottom: start, or stop and upload.
class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.controller});
  final RecordingController controller;

  Future<void> _start(BuildContext context) async {
    final ctx = await showSessionContextSheet(context);
    if (ctx != null) await controller.startRecording(context: ctx);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final recording = c.isRecording;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KuuSpacing.md,
            KuuSpacing.sm + 4,
            KuuSpacing.md,
            KuuSpacing.sm + 4,
          ),
          child: recording
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: KuuColor.statePreCrisis,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: c.stopRecording,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text('Detener y subir · ${_clock(c.elapsed)}'),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed:
                      c.isConnected && c.uploadState != UploadState.uploading
                      ? () => _start(context)
                      : null,
                  icon: const Icon(Icons.fiber_manual_record_rounded),
                  label: const Text('Iniciar grabación'),
                ),
        ),
      ),
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        leading: const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(
          'Reconectando con el EmotiBit…',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
        subtitle: Text(
          'La grabación sigue. Revisa que el EmotiBit esté encendido y cerca '
          'del WiFi. Se cerrará en ${_clock(controller.reconnectTimeLeft)} si no vuelve.',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

/// Black screen shown on iPhone during a recording; tap to go back.
class _DimmedScreen extends StatelessWidget {
  const _DimmedScreen({required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.scrim,
        child: Center(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (!controller.isRecording) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.of(context).maybePop();
                });
              }
              return Text(
                controller.isReconnecting
                    ? 'Reconectando…  toca para volver'
                    : 'Grabando ${_clock(controller.elapsed)}  ·  toca para volver',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _clock(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
