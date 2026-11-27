import 'dart:math';

import 'package:flutter/material.dart';

/// Minimal auto-scaling line plot for live signals.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 80,
  });
  final Iterable<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _SparkPainter(values.toList(growable: false), color),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color);
  final List<double> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    var lo = v.reduce(min);
    var hi = v.reduce(max);
    if (hi - lo < 1e-9) {
      hi += 1;
      lo -= 1;
    }
    final dx = size.width / (v.length - 1);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final y = size.height - (v[i] - lo) / (hi - lo) * size.height;
      i == 0 ? path.moveTo(0, y) : path.lineTo(i * dx, y);
    }
    // Soft fill under the line, fading down.
    final fill = Path.from(path)
      ..lineTo((v.length - 1) * dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}
