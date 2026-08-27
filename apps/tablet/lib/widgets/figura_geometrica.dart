import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Figuras geométricas y colores por su NOMBRE en español, compartido por los
/// widgets que pintan formas (búsqueda de figuras, encaja la pieza, series).
const kFigurasGeom = {
  'círculo', 'circulo', 'cuadrado', 'triángulo', 'triangulo', 'estrella',
  'corazón', 'corazon', 'rombo', 'óvalo', 'ovalo', 'rectángulo', 'rectangulo'
};

bool esFiguraGeom(String s) => kFigurasGeom.contains(s.trim().toLowerCase());

/// Color por su nombre en español; null si no es un color conocido.
Color? colorPorNombre(String s) {
  switch (s.trim().toLowerCase()) {
    case 'rojo':
    case 'roja':
      return const Color(0xFFD7362B);
    case 'azul':
      return const Color(0xFF2C6FB5);
    case 'verde':
      return const Color(0xFF3C9A4E);
    case 'amarillo':
    case 'amarilla':
      return const Color(0xFFF2C33D);
    case 'naranja':
      return const Color(0xFFE8802B);
    case 'morado':
    case 'morada':
    case 'violeta':
    case 'lila':
      return const Color(0xFF8A4FBE);
    case 'rosa':
      return const Color(0xFFE87AA8);
    case 'marrón':
    case 'marron':
      return const Color(0xFF8B5A2B);
    case 'negro':
    case 'negra':
      return const Color(0xFF2B2B2B);
    case 'blanco':
    case 'blanca':
      return const Color(0xFFFFFFFF);
    case 'gris':
      return const Color(0xFF9AA0A6);
  }
  return null;
}

/// Dibuja una figura geométrica (opcionalmente de un color) por su nombre. El
/// nombre puede venir sin acento ('triangulo') o como 'triángulo rojo'.
class FiguraGeometrica extends StatelessWidget {
  final String nombre;
  final double size;
  final Color? color;
  const FiguraGeometrica(this.nombre, {super.key, this.size = 54, this.color});

  @override
  Widget build(BuildContext context) {
    // Permite "triángulo rojo": separa figura y color.
    String fig = nombre.trim().toLowerCase();
    Color? col = color;
    final parts = fig.split(RegExp(r'\s+'));
    if (parts.length == 2) {
      for (final w in parts) {
        if (esFiguraGeom(w)) fig = w;
        final c = colorPorNombre(w);
        if (c != null) col = c;
      }
    }
    return CustomPaint(
        size: Size(size, size), painter: _FiguraGeomPainter(fig, col));
  }
}

class _FiguraGeomPainter extends CustomPainter {
  final String nombre;
  final Color? color;
  _FiguraGeomPainter(this.nombre, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color ?? TrazoColors.sageDark
      ..style = PaintingStyle.fill;
    final borde = Paint()
      ..color = TrazoColors.ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.03);
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    final r = math.min(w, h) / 2;
    void fs(Path path) {
      canvas.drawPath(path, p);
      canvas.drawPath(path, borde);
    }

    switch (nombre.trim().toLowerCase()) {
      case 'círculo':
      case 'circulo':
        canvas.drawCircle(Offset(cx, cy), r, p);
        canvas.drawCircle(Offset(cx, cy), r, borde);
        break;
      case 'óvalo':
      case 'ovalo':
        final rect =
            Rect.fromCenter(center: Offset(cx, cy), width: w, height: h * 0.7);
        canvas.drawOval(rect, p);
        canvas.drawOval(rect, borde);
        break;
      case 'cuadrado':
        fs(Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: w * 0.92, height: h * 0.92),
              const Radius.circular(4))));
        break;
      case 'rectángulo':
      case 'rectangulo':
        fs(Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: w, height: h * 0.62),
              const Radius.circular(4))));
        break;
      case 'triángulo':
      case 'triangulo':
        fs(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy + r)
          ..lineTo(cx - r, cy + r)
          ..close());
        break;
      case 'rombo':
        fs(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close());
        break;
      case 'corazón':
      case 'corazon':
        final path = Path()..moveTo(cx, cy + r * 0.75);
        path.cubicTo(
            cx - r * 1.4, cy - r * 0.2, cx - r * 0.5, cy - r, cx, cy - r * 0.35);
        path.cubicTo(
            cx + r * 0.5, cy - r, cx + r * 1.4, cy - r * 0.2, cx, cy + r * 0.75);
        fs(path);
        break;
      case 'estrella':
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final rr = i.isEven ? r : r * 0.42;
          final a = -math.pi / 2 + i * math.pi / 5;
          final pt = Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        fs(path);
        break;
    }
  }

  @override
  bool shouldRepaint(_FiguraGeomPainter old) =>
      old.nombre != nombre || old.color != color;
}
