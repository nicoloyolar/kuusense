import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kuusense_firebase/kuusense_firebase.dart';
import 'package:kuusense_ui/kuusense_ui.dart';

/// Per-second charts of a session (heart rate, EDA, skin temperature and
/// movement) read from its `signals.csv`, with the marked events as vertical
/// lines and the session figures as headline numbers.
class SignalsCard extends StatefulWidget {
  const SignalsCard({super.key, required this.repo, required this.session});
  final KuusenseRepository repo;
  final RecordingSession session;

  /// Whether there is anything to show for [s].
  static bool hasContent(RecordingSession s) =>
      s.files.containsKey(StoragePaths.signalsFile) || s.stats != null;

  @override
  State<SignalsCard> createState() => _SignalsCardState();
}

class _SignalsCardState extends State<SignalsCard> {
  late Future<List<SignalPoint>> _points = widget.repo.loadSignals(widget.session);
  String? _loadedPath;

  @override
  void didUpdateWidget(SignalsCard old) {
    super.didUpdateWidget(old);
    // Reload only when the file itself changes (the session doc updates often).
    final path = widget.session.files[StoragePaths.signalsFile];
    if (path != _loadedPath) {
      _loadedPath = path;
      _points = widget.repo.loadSignals(widget.session);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadedPath = widget.session.files[StoragePaths.signalsFile];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.session;
    final st = s.stats;
    return KuuSurface(
      child: Padding(
        padding: const EdgeInsets.all(KuuSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: KuuSpacing.sm),
                Text('Señales',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (st != null)
                  Text(
                    _quality(st),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: KuuSpacing.md),
            FutureBuilder<List<SignalPoint>>(
              future: _points,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(KuuSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return _Note('No se pudieron cargar las señales: ${snap.error}');
                }
                final points = snap.data!;
                if (points.isEmpty) {
                  return const _Note('Esta sesión no tiene resumen de señales.');
                }
                final start = s.startedAtMs;
                final end = max(s.endedAtMs ?? points.last.atMs, points.last.atMs + 1000);
                final events = [for (final e in s.events) e.atMs];
                Widget row(String label, String figure, Color color, double? Function(SignalPoint) pick,
                        {String? detail}) =>
                    _SignalRow(
                      label: label,
                      figure: figure,
                      detail: detail,
                      color: color,
                      points: points,
                      pick: pick,
                      startMs: start,
                      endMs: end,
                      events: events,
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    row('Frecuencia cardíaca', _range(st?.heartRate, 0, 'lpm'), KuuColor.statePreCrisis,
                        (p) => p.heartRate),
                    row('Sudoración (EDA)', _range(st?.eda, 1, 'µS'), KuuColor.brandPrimary, (p) => p.eda,
                        detail: st == null ? null : '${st.scrCount} respuestas detectadas'),
                    row('Temperatura de la piel', _range(st?.temperature, 1, '°C'), KuuColor.brandAccent,
                        (p) => p.temperature),
                    row('Movimiento', 'intensidad (g)', KuuColor.brandSecondary, (p) => p.motion),
                    _TimeAxis(startMs: start, endMs: end),
                    if (events.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: KuuSpacing.sm),
                        child: Text(
                          'Las líneas verticales son los eventos marcados.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _n(double v, int digits) => v.toStringAsFixed(digits).replaceAll('.', ',');

  static String _range(SignalRange? r, int digits, String unit) => r == null
      ? '—'
      : '${_n(r.mean, digits)} $unit prom. · ${_n(r.min, digits)}–${_n(r.max, digits)}';

  static String _quality(SessionStats st) {
    final parts = ['${_n(st.lossPercent, 1)} % paquetes perdidos'];
    if (st.batteryStart != null && st.batteryEnd != null) {
      parts.add('batería ${_n(st.batteryStart!, 0)} → ${_n(st.batteryEnd!, 0)} %');
    }
    return parts.join(' · ');
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.figure,
    required this.color,
    required this.points,
    required this.pick,
    required this.startMs,
    required this.endMs,
    required this.events,
    this.detail,
  });

  final String label, figure;
  final String? detail;
  final Color color;
  final List<SignalPoint> points;
  final double? Function(SignalPoint) pick;
  final int startMs, endMs;
  final List<int> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: KuuSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: KuuSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(figure, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              if (detail != null) Text('· $detail', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: KuuSpacing.xs),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: _LinePainter(
                points: points,
                pick: pick,
                startMs: startMs,
                endMs: endMs,
                events: events,
                color: color,
                grid: theme.colorScheme.outlineVariant,
                eventColor: KuuColor.stateAlert,
                labelStyle: theme.textTheme.labelSmall?.copyWith(color: muted) ?? const TextStyle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.pick,
    required this.startMs,
    required this.endMs,
    required this.events,
    required this.color,
    required this.grid,
    required this.eventColor,
    required this.labelStyle,
  });

  final List<SignalPoint> points;
  final double? Function(SignalPoint) pick;
  final int startMs, endMs;
  final List<int> events;
  final Color color, grid, eventColor;
  final TextStyle labelStyle;

  static const _labelWidth = 44.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(_labelWidth, 2, size.width - _labelWidth, size.height - 4);
    final span = max(1, endMs - startMs);
    double x(int ms) => plot.left + (ms - startMs) / span * plot.width;

    final values = [for (final p in points) ?pick(p)];
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, gridPaint);
    canvas.drawLine(plot.topLeft, plot.topRight, gridPaint..color = grid.withValues(alpha: 0.4));

    for (final e in events) {
      if (e < startMs || e > endMs) continue;
      canvas.drawLine(Offset(x(e), plot.top), Offset(x(e), plot.bottom),
          Paint()
            ..color = eventColor
            ..strokeWidth = 1.5);
    }
    if (values.isEmpty) {
      _label(canvas, 'sin datos', Offset(plot.left + 8, plot.center.dy - 6));
      return;
    }

    var lo = values.reduce(min);
    var hi = values.reduce(max);
    if (hi - lo < 1e-6) {
      hi += 0.5;
      lo -= 0.5;
    }
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final path = Path();
    int? prevMs;
    for (final p in points) {
      final v = pick(p);
      if (v == null) continue;
      // Break the line over gaps longer than a few seconds (lost connection).
      if (prevMs == null || p.atMs - prevMs > 3000) {
        path.moveTo(x(p.atMs), y(v));
      } else {
        path.lineTo(x(p.atMs), y(v));
      }
      prevMs = p.atMs;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );

    String fmt(double v) =>
        v.toStringAsFixed(v.abs() >= 100 ? 0 : v.abs() >= 10 ? 1 : 2).replaceAll('.', ',');
    _label(canvas, fmt(hi), Offset(0, plot.top - 2));
    _label(canvas, fmt(lo), Offset(0, plot.bottom - 12));
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _labelWidth - 4);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.events != events || old.color != color || old.grid != grid;
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.startMs, required this.endMs});
  final int startMs, endMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final mid = startMs + (endMs - startMs) ~/ 2;
    return Padding(
      padding: const EdgeInsets.only(left: _LinePainter._labelWidth),
      child: Row(
        children: [
          Text(formatTime(startMs), style: style),
          const Spacer(),
          Text(formatTime(mid), style: style),
          const Spacer(),
          Text(formatTime(endMs), style: style),
        ],
      ),
    );
  }
}
