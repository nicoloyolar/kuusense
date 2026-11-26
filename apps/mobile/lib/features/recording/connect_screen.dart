import 'dart:math' as math;

import 'package:emotibit/emotibit.dart';
import 'package:flutter/material.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

import 'device_scanner.dart';
import 'recording_controller.dart';

/// Finds EmotiBits on the WiFi network, Bluetooth-style: a radar while it
/// searches, one card per device as they appear, tap to connect.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.controller});
  final RecordingController controller;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _scanner = DeviceScanner();
  String? _connectingId;
  String? _error;

  /// After this long with nothing found, show the help card.
  static const _slowAfter = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _scanner.start();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _connect(DiscoveredEmotiBit d) async {
    setState(() {
      _connectingId = d.deviceId;
      _error = null;
    });
    _scanner.pause();
    try {
      await widget.controller.connect(d);
    } catch (e) {
      _error = 'No pudimos conectar con ${d.deviceId}. Revisa que siga encendido y vuelve a intentarlo.';
    }
    _scanner.resume();
    if (mounted) setState(() => _connectingId = null);
  }

  Future<void> _openHelp() async {
    final ip = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _HelpSheet(),
    );
    if (ip != null && ip.trim().isNotEmpty) _scanner.setManualIp(ip);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar EmotiBit')),
      body: ListenableBuilder(
        listenable: _scanner,
        builder: (context, _) {
          final devices = _scanner.devices;
          final slow = devices.isEmpty && _scanner.elapsed > _slowAfter;
          return ListView(
            padding: const EdgeInsets.fromLTRB(KuuSpacing.lg, KuuSpacing.sm, KuuSpacing.lg, KuuSpacing.xl),
            children: [
              if (c.childLabel != null)
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.fiber_manual_record_rounded, size: 14, color: KuuColor.statePreCrisis),
                    label: Text('Sesión para ${c.childLabel}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(height: KuuSpacing.md),
              _Radar(found: devices.length),
              const SizedBox(height: KuuSpacing.md),
              Text(
                devices.isEmpty
                    ? 'Buscando EmotiBits cerca…'
                    : devices.length == 1
                        ? 'Encontramos 1 EmotiBit'
                        : 'Encontramos ${devices.length} EmotiBits',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: KuuSpacing.xs),
              Text(
                devices.isEmpty
                    ? 'Enciende el EmotiBit y conecta este teléfono a su misma red WiFi.'
                    : 'Toca el que tienes contigo para conectarlo. La búsqueda sigue activa.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (c.deviceLostMessage != null) ...[
                const SizedBox(height: KuuSpacing.md),
                _Notice(icon: Icons.link_off_rounded, color: KuuColor.stateAlert, text: c.deviceLostMessage!),
              ],
              if (_error != null) ...[
                const SizedBox(height: KuuSpacing.md),
                _Notice(icon: Icons.error_outline_rounded, color: KuuColor.feedbackError, text: _error!),
              ],
              const SizedBox(height: KuuSpacing.lg),
              for (final d in devices)
                Padding(
                  key: ValueKey(d.deviceId),
                  padding: const EdgeInsets.only(bottom: KuuSpacing.sm),
                  child: _AppearIn(
                    child: _DeviceCard(
                      device: d,
                      lastUsed: d.deviceId == _scanner.lastDevice?.deviceId,
                      connecting: _connectingId == d.deviceId,
                      enabled: _connectingId == null,
                      onTap: () => _connect(d),
                    ),
                  ),
                ),
              if (slow) ...[
                _Notice(
                  icon: Icons.tips_and_updates_outlined,
                  color: KuuColor.feedbackInfo,
                  text: 'Está tardando más de lo normal. Revisa que el EmotiBit tenga la luz encendida '
                      'y que ambos estén en la misma red WiFi de 2,4 GHz.',
                ),
                const SizedBox(height: KuuSpacing.sm),
              ],
              const SizedBox(height: KuuSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: _openHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text('¿No aparece tu EmotiBit?'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ radar

/// Pulsing rings around a sensor icon; calmer once something was found.
class _Radar extends StatefulWidget {
  const _Radar({required this.found});
  final int found;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.found > 0 ? KuuColor.brandSecondary : KuuColor.brandHighlight;
    return SizedBox(
      height: 190,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(progress: _anim.value, color: color),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, KuuColor.brandPrimary],
                ),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2)],
              ),
              child: Icon(
                widget.found > 0 ? Icons.sensors_rounded : Icons.wifi_tethering_rounded,
                color: KuuColor.lightSurface,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) / 2;
    const rings = 3;
    for (var i = 0; i < rings; i++) {
      final t = (progress + i / rings) % 1.0;
      final r = 42 + (maxR - 42) * t;
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, r, paint);
      canvas.drawCircle(center, r, Paint()..color = color.withValues(alpha: (1 - t) * 0.06));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress || old.color != color;
}

// ------------------------------------------------------------------ device card

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.lastUsed,
    required this.connecting,
    required this.enabled,
    required this.onTap,
  });
  final DiscoveredEmotiBit device;
  final bool lastUsed;
  final bool connecting;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = device.isAvailable;
    final canTap = available && enabled;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(KuuRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(KuuRadius.lg),
        onTap: canTap ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(KuuSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KuuRadius.lg),
            border: Border.all(
              color: connecting ? KuuColor.brandSecondary : theme.colorScheme.outline,
              width: connecting ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: available ? 1 : 0.5,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KuuRadius.md),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [KuuColor.brandHighlight, KuuColor.brandPrimary],
                    ),
                  ),
                  child: const Icon(Icons.watch_rounded, color: KuuColor.lightSurface, size: 28),
                ),
              ),
              const SizedBox(width: KuuSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceId,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EmotiBit · ${device.address.address}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: KuuSpacing.xs),
                    Wrap(
                      spacing: KuuSpacing.xs,
                      runSpacing: KuuSpacing.xs,
                      children: [
                        if (connecting)
                          const _StatusChip('Conectando…', KuuColor.brandSecondary)
                        else if (available)
                          const _StatusChip('Disponible', KuuColor.stateStable)
                        else
                          const _StatusChip('En uso por otro teléfono', KuuColor.stateAlert),
                        if (lastUsed) const _StatusChip('Último usado', KuuColor.brandHighlight),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KuuSpacing.sm),
              if (connecting)
                const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              else if (available)
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: KuuSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(KuuRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

/// Fades and slides a device card in when it first appears.
class _AppearIn extends StatelessWidget {
  const _AppearIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
        ),
        child: child,
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(KuuSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KuuRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: KuuSpacing.sm),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

// ------------------------------------------------------------------ help

/// Checklist for when the device does not show up, plus connect by IP.
/// Pops the IP typed, if any.
class _HelpSheet extends StatefulWidget {
  const _HelpSheet();

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  final _ip = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ip.text.trim();
    final valid = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(text);
    if (!valid) {
      setState(() => _error = 'Ingresa una IP como 172.20.10.3');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tips = [
      (Icons.power_settings_new_rounded, 'El EmotiBit está encendido y con batería (luz encendida).'),
      (Icons.wifi_rounded, 'El teléfono y el EmotiBit están en la misma red WiFi.'),
      (Icons.network_check_rounded, 'La red es de 2,4 GHz. En un hotspot de iPhone, activa "Maximizar compatibilidad".'),
      (Icons.phonelink_off_rounded, 'Ningún otro teléfono o computador está conectado a ese EmotiBit.'),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KuuSpacing.lg,
        0,
        KuuSpacing.lg,
        KuuSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿No aparece tu EmotiBit?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: KuuSpacing.md),
          for (final (icon, text) in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: KuuSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: KuuColor.brandHighlight),
                  const SizedBox(width: KuuSpacing.sm),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          const SizedBox(height: KuuSpacing.md),
          Text('Conectar por IP', style: theme.textTheme.titleMedium),
          const SizedBox(height: KuuSpacing.xs),
          Text(
            'Si conoces la IP del EmotiBit (en un hotspot aparece en la lista de dispositivos conectados), '
            'la buscaremos directamente.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: KuuSpacing.sm),
          TextField(
            controller: _ip,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '172.20.10.3',
              prefixIcon: const Icon(Icons.lan_outlined),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: KuuSpacing.md),
          FilledButton(onPressed: _submit, child: const Text('Buscar en esta IP')),
        ],
      ),
    );
  }
}
