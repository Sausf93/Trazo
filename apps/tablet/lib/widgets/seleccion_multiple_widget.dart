import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `seleccion_multiple`: enunciado (+ imagen si la hay) y opciones
/// GRANDES apiladas a lo ancho, con texto grande y legible, que caben sin scroll.
/// Registra la elección; la corrección la resuelve el motor / la integradora.
class SeleccionMultipleWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const SeleccionMultipleWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<SeleccionMultipleWidget> createState() =>
      _SeleccionMultipleWidgetState();
}

/// Colores por su nombre en español (para series VISUALES y opciones de color).
/// Devuelve null si la palabra no es un color conocido.
Color? _colorDe(String s) {
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

/// Nombres de figura que se pintan como dibujo (series/opciones VISUALES).
const _kFiguras = {
  'círculo',
  'circulo',
  'cuadrado',
  'triángulo',
  'triangulo',
  'estrella',
  'corazón',
  'corazon',
  'rombo',
  'óvalo',
  'ovalo',
  'rectángulo',
  'rectangulo'
};
bool _esFigura(String s) => _kFiguras.contains(s.trim().toLowerCase());

/// Dibuja una figura geométrica sencilla por su nombre (para las series y
/// opciones visuales). Grande y con buen contraste para el móvil.
class _FiguraMini extends StatelessWidget {
  final String nombre;
  final double size;
  const _FiguraMini(this.nombre, {this.size = 54});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _FiguraPainter(nombre));
}

class _FiguraPainter extends CustomPainter {
  final String nombre;
  _FiguraPainter(this.nombre);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = TrazoColors.sageDark
      ..style = PaintingStyle.fill;
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    final r = math.min(w, h) / 2;
    switch (nombre.trim().toLowerCase()) {
      case 'círculo':
      case 'circulo':
        canvas.drawCircle(Offset(cx, cy), r, p);
        break;
      case 'óvalo':
      case 'ovalo':
        canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy), width: w, height: h * 0.7),
            p);
        break;
      case 'cuadrado':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy), width: w * 0.92, height: h * 0.92),
                const Radius.circular(4)),
            p);
        break;
      case 'rectángulo':
      case 'rectangulo':
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(cx, cy), width: w, height: h * 0.62),
                const Radius.circular(4)),
            p);
        break;
      case 'triángulo':
      case 'triangulo':
        canvas.drawPath(
            Path()
              ..moveTo(cx, cy - r)
              ..lineTo(cx + r, cy + r)
              ..lineTo(cx - r, cy + r)
              ..close(),
            p);
        break;
      case 'rombo':
        canvas.drawPath(
            Path()
              ..moveTo(cx, cy - r)
              ..lineTo(cx + r, cy)
              ..lineTo(cx, cy + r)
              ..lineTo(cx - r, cy)
              ..close(),
            p);
        break;
      case 'corazón':
      case 'corazon':
        final path = Path()..moveTo(cx, cy + r * 0.75);
        path.cubicTo(cx - r * 1.4, cy - r * 0.2, cx - r * 0.5, cy - r, cx,
            cy - r * 0.35);
        path.cubicTo(cx + r * 0.5, cy - r, cx + r * 1.4, cy - r * 0.2, cx,
            cy + r * 0.75);
        canvas.drawPath(path, p);
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
        canvas.drawPath(path, p);
        break;
    }
  }

  @override
  bool shouldRepaint(_FiguraPainter old) => old.nombre != nombre;
}

class _SeleccionMultipleWidgetState extends State<SeleccionMultipleWidget> {
  String? _elegida;
  final DateTime _inicio = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    // Cast tolerante: una instancia malformada del backend no debe tumbar la
    // tablet en pleno kiosco (mejor sin opciones que un crash).
    final opciones = (render['opciones'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final instruccion = render['instruccion'] as String?;
    final enunciado = render['enunciado'] as String? ??
        render['instruccion'] as String? ??
        'Elige la correcta';
    // Si vienen AMBOS y difieren (p. ej. series: instruccion='¿Qué sigue?' y
    // enunciado='rojo, azul, rojo…'), se pinta la consigna encima; si no, la
    // serie quedaba en pantalla sin ninguna pregunta que dijera qué hacer.
    final mostrarConsigna = instruccion != null &&
        instruccion.isNotEmpty &&
        instruccion != enunciado;
    final imagen = (render['imagen'] ?? '').toString();
    final serie = (render['serie'] as List?)?.map((e) => e.toString()).toList();
    final figuras =
        (render['figuras'] as List?)?.map((e) => e.toString()).toList();
    final modelo = (render['modelo'] ?? '').toString();

    final n = opciones.length;
    const gap = 14.0;
    // Se desplaza SOLO si no cabe (minHeight = alto disponible). Así en pantallas
    // altas se centra y llena, y en tablets bajas (1024x600) con 5 opciones no
    // desborda ni corta la última opción: aparece scroll de rescate. El enunciado
    // NUNCA se trunca (las adivinanzas perderían la pista y medirían injusto).
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              if (mostrarConsigna) ...[
                Text(instruccion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: TrazoColors.sageDark)),
                const SizedBox(height: 8),
              ],
              Text(enunciado,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.ink)),
              if (imagen.isNotEmpty && IlustracionResolver.tiene(imagen)) ...[
                const SizedBox(height: 12),
                Ilustracion(imagen, size: 110),
              ],
              // Serie VISUAL a continuar (fichas + "?").
              if (serie != null && serie.isNotEmpty) ...[
                const SizedBox(height: 16),
                _filaVisual(serie, conInterrogante: true),
              ],
              // Conjunto VISUAL para contar (sin "?").
              if (figuras != null && figuras.isNotEmpty) ...[
                const SizedBox(height: 16),
                _filaVisual(figuras, conInterrogante: false),
              ],
              // Modelo VISUAL grande a emparejar ("¿cuál es igual?").
              if (modelo.isNotEmpty &&
                  (_colorDe(modelo) != null || _esFigura(modelo))) ...[
                const SizedBox(height: 12),
                _ficha(modelo, size: 92),
              ],
              const SizedBox(height: 18),
              // Opciones a un tamaño táctil cómodo y estable (no gigantes).
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                _opcion(opciones[i], 66),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  /// Ficha visual de un token: círculo de color, figura dibujada o texto.
  Widget _ficha(String s, {double size = 54}) {
    final c = _colorDe(s);
    if (c != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
              color: TrazoColors.ink.withValues(alpha: 0.25), width: 2),
        ),
      );
    }
    if (_esFigura(s)) return _FiguraMini(s, size: size);
    return Text(s,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: TrazoColors.ink));
  }

  /// Fila de fichas visuales; con "?" al final si es una SERIE a continuar.
  Widget _filaVisual(List<String> tokens, {bool conInterrogante = true}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in tokens) _ficha(s),
        if (conInterrogante)
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TrazoColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: TrazoColors.sageDark, width: 2.5),
            ),
            child: const Text('?',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: TrazoColors.sageDark)),
          ),
      ],
    );
  }

  Widget _opcion(String op, double alto) {
    final sel = op == _elegida;
    final colorOp = _colorDe(op); // si la opción es un color, se pinta su ficha
    // Texto grande; si la opción es larga (un refrán, una definición), algo menor.
    final fontSize = op.length > 42
        ? 19.0
        : op.length > 22
            ? 22.0
            : 30.0;
    return Semantics(
      button: true,
      selected: sel,
      label: op,
      child: ConstrainedBox(
        // Altura ADAPTABLE: mínimo cómodo pero CRECE si el texto es largo, para
        // que un refrán o una definición se lea ENTERO (antes se cortaba con "…").
        constraints: BoxConstraints(minHeight: alto),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _elegida = op);
                widget.onMetricas({
                  'eleccion': op,
                  'tiempo_ms':
                      DateTime.now().difference(_inicio).inMilliseconds,
                });
              },
              child: Container(
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: sel ? TrazoColors.coralDark : TrazoColors.sand,
                      width: sel ? 3 : 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (sel) ...[
                      const Icon(Icons.check_circle,
                          color: TrazoColors.coralDark, size: 30),
                      const SizedBox(width: 10),
                    ],
                    if (colorOp != null) ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorOp,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: TrazoColors.ink.withValues(alpha: 0.25),
                              width: 2),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ] else if (_esFigura(op)) ...[
                      _FiguraMini(op, size: 42),
                      const SizedBox(width: 14),
                    ],
                    Flexible(
                      // Se muestra ENTERA (hasta 5 líneas envueltas): un refrán o
                      // una definición larga ya no se corta con "…".
                      child: Text(op,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                          style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                              color: TrazoColors.ink)),
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
