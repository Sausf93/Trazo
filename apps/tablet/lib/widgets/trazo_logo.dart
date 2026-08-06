import 'package:flutter/material.dart';

import '../theme.dart';

/// Logo de Trazo: azulejo salvia redondeado con un trazo blanco que empieza
/// tembloroso y acaba firme, rematado por un punto coral.
/// Dibujado con CustomPainter (sin dependencias ni assets).
class TrazoLogo extends StatelessWidget {
  final double size;

  const TrazoLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TrazoLogoPainter()),
    );
  }
}

class _TrazoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Azulejo salvia redondeado.
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.28),
    );
    final tilePaint = Paint()..color = TrazoColors.sage;
    canvas.drawRRect(rect, tilePaint);

    // Trazo blanco: comienza tembloroso (izquierda) y acaba firme (derecha).
    // Coordenadas relativas al lienzo 40x40 escaladas al tamaño real.
    Offset p(double x, double y) => Offset(x / 40 * w, y / 40 * h);

    final trazo = Path()
      ..moveTo(p(7, 26).dx, p(7, 26).dy)
      // tramo tembloroso
      ..cubicTo(p(9, 20).dx, p(9, 20).dy, p(10, 30).dx, p(10, 30).dy,
          p(13, 24).dx, p(13, 24).dy)
      ..cubicTo(p(15, 20).dx, p(15, 20).dy, p(16, 28).dx, p(16, 28).dy,
          p(20, 22).dx, p(20, 22).dy)
      // tramo firme
      ..cubicTo(p(24, 16).dx, p(24, 16).dy, p(27, 24).dx, p(27, 24).dy,
          p(33, 15).dx, p(33, 15).dy);

    final strokePaint = Paint()
      ..color = TrazoColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(trazo, strokePaint);

    // Punto coral al final del trazo.
    final dotPaint = Paint()..color = TrazoColors.coral;
    canvas.drawCircle(p(33, 15), w * 0.065, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
