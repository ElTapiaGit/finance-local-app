import 'package:flutter/material.dart';

/// Pintor personalizado para trazar un borde circular punteado.
class DottedCircleBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  const DottedCircleBorderPainter({
    required this.color,
    this.strokeWidth = 1.8,
    this.dashCount = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const double pi = 3.141592653589793;
    final circumference = 2 * pi * radius;
    final dashLength = circumference / (dashCount * 2);
    final dashAngle = dashLength / radius;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * 2 * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DottedCircleBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

