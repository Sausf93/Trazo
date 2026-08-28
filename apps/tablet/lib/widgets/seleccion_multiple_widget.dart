import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
  final Color? color;
  const _FiguraMini(this.nombre, {this.size = 54, this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(size, size), painter: _FiguraPainter(nombre, color));
}

class _FiguraPainter extends CustomPainter {
  final String nombre;
  final Color? color;
  _FiguraPainter(this.nombre, [this.color]);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color ?? TrazoColors.sageDark
      ..style = PaintingStyle.fill;
    // Contorno oscuro para que una figura de color claro (amarillo/blanco) no se
    // pierda sobre el fondo de la tarjeta.
    final borde = Paint()
      ..color = TrazoColors.ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.03);
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    final r = math.min(w, h) / 2;
    void fillStroke(Path path) {
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
        fillStroke(Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: w * 0.92, height: h * 0.92),
              const Radius.circular(4))));
        break;
      case 'rectángulo':
      case 'rectangulo':
        fillStroke(Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: w, height: h * 0.62),
              const Radius.circular(4))));
        break;
      case 'triángulo':
      case 'triangulo':
        fillStroke(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy + r)
          ..lineTo(cx - r, cy + r)
          ..close());
        break;
      case 'rombo':
        fillStroke(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close());
        break;
      case 'corazón':
      case 'corazon':
        final path = Path()..moveTo(cx, cy + r * 0.75);
        path.cubicTo(cx - r * 1.4, cy - r * 0.2, cx - r * 0.5, cy - r, cx,
            cy - r * 0.35);
        path.cubicTo(cx + r * 0.5, cy - r, cx + r * 1.4, cy - r * 0.2, cx,
            cy + r * 0.75);
        fillStroke(path);
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
        fillStroke(path);
        break;
    }
  }

  @override
  bool shouldRepaint(_FiguraPainter old) =>
      old.nombre != nombre || old.color != color;
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
    // Degradación de la imagen para GNOSIAS: 'silueta' (contorno negro) o
    // 'borroso'. Reconocer un objeto con información incompleta.
    final degradado = (render['degradado'] ?? '').toString().toLowerCase();
    final serie = (render['serie'] as List?)?.map((e) => e.toString()).toList();
    final figuras =
        (render['figuras'] as List?)?.map((e) => e.toString()).toList();
    final modelo = (render['modelo'] ?? '').toString();
    // Modelo de VARIAS fichas (fila) para "replicar la figura con sus colores".
    final modeloFila =
        (render['modelo_fila'] as List?)?.map((e) => e.toString()).toList();
    // Opciones VISUALES: cada opción es una fila de fichas (colores/figuras).
    // Se empareja por índice con `opciones` (el texto sigue siendo la elección).
    final opcionesFiguras = (render['opciones_figuras'] as List?)
        ?.map((e) => (e as List? ?? const []).map((x) => x.toString()).toList())
        .toList();

    // ¿Es una actividad VISUAL de verdad (series/figuras/modelo)? Solo en esas se
    // pintan círculos de color / figuras DELANTE de las opciones. En una pregunta
    // normal, una opción que sea "rojo" o "naranja" (color, fruta…) NO debe llevar
    // círculo: confundía en muchas actividades (feedback de Saulo).
    final esVisualAct = (serie != null && serie.isNotEmpty) ||
        (figuras != null && figuras.isNotEmpty) ||
        (modelo.isNotEmpty && _parseFicha(modelo).esVisual) ||
        (modeloFila != null && modeloFila.isNotEmpty) ||
        (opcionesFiguras != null && opcionesFiguras.isNotEmpty);

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
                _imagenQuiza(imagen, degradado),
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
              if (modelo.isNotEmpty && _parseFicha(modelo).esVisual) ...[
                const SizedBox(height: 12),
                _ficha(modelo, size: 92),
              ],
              // Modelo de VARIAS fichas (replicar la figura con sus colores).
              if (modeloFila != null && modeloFila.isNotEmpty) ...[
                const SizedBox(height: 14),
                _marcoModelo(_filaVisual(modeloFila,
                    conInterrogante: false, size: 60)),
              ],
              const SizedBox(height: 18),
              // Opciones a un tamaño táctil cómodo y estable (no gigantes).
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                (opcionesFiguras != null && i < opcionesFiguras.length)
                    ? _opcionVisual(opciones[i], opcionesFiguras[i])
                    : _opcion(opciones[i], 66, esVisualAct),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  /// Ficha visual de un token: círculo de color, figura dibujada (con su color
  /// si el token es "círculo rojo"), o texto. Devuelve null en `figura`/`color`
  /// según lo que sea, para que las opciones lo pinten igual.
  ({String? figura, Color? color, bool esVisual}) _parseFicha(String s) {
    final t = s.trim().toLowerCase();
    // "círculo rojo" / "rojo círculo": figura + color.
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 2) {
      String? fig;
      Color? col;
      for (final w in parts) {
        if (_esFigura(w)) fig = w;
        final c = _colorDe(w);
        if (c != null) col = c;
      }
      if (fig != null && col != null) {
        return (figura: fig, color: col, esVisual: true);
      }
    }
    final c = _colorDe(t);
    if (c != null) return (figura: null, color: c, esVisual: true);
    if (_esFigura(t)) return (figura: t, color: null, esVisual: true);
    return (figura: null, color: null, esVisual: false);
  }

  Widget _circuloColor(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
              color: TrazoColors.ink.withValues(alpha: 0.25), width: 2),
        ),
      );

  /// Ficha visual de un token: figura de color, círculo de color, figura o texto.
  Widget _ficha(String s, {double size = 54}) {
    final f = _parseFicha(s);
    if (f.figura != null) return _FiguraMini(f.figura!, size: size, color: f.color);
    if (f.color != null) return _circuloColor(f.color!, size);
    return Text(s,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: TrazoColors.ink));
  }

  /// Fila de fichas visuales; con "?" al final si es una SERIE a continuar.
  Widget _filaVisual(List<String> tokens,
      {bool conInterrogante = true, double size = 54}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in tokens) _ficha(s, size: size),
        if (conInterrogante)
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TrazoColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: TrazoColors.sageDark, width: 2.5),
            ),
            child: Text('?',
                style: TextStyle(
                    fontSize: size * 0.55,
                    fontWeight: FontWeight.w900,
                    color: TrazoColors.sageDark)),
          ),
      ],
    );
  }

  /// La imagen tal cual, en SILUETA (contorno negro) o BORROSA, para gnosias.
  Widget _imagenQuiza(String id, String degradado) {
    final img = Ilustracion(id, size: 130);
    switch (degradado) {
      case 'silueta':
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(
              Color(0xFF2B2B2B), BlendMode.srcATop),
          child: img,
        );
      case 'borroso':
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
          child: img,
        );
      default:
        return Ilustracion(id, size: 110);
    }
  }

  /// Marco suave alrededor del modelo a copiar (lo separa de las opciones).
  Widget _marcoModelo(Widget hijo) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: TrazoColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TrazoColors.sageDark, width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Modelo',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.sageDark)),
          const SizedBox(height: 6),
          hijo,
        ]),
      );

  /// Opción cuyo contenido es una FILA de fichas (colores/figuras). La elección
  /// registrada sigue siendo el texto `key` (para la autocorrección).
  Widget _opcionVisual(String key, List<String> tokens) {
    final sel = key == _elegida;
    return Semantics(
      button: true,
      selected: sel,
      label: key,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _elegida = key);
              widget.onMetricas({
                'eleccion': key,
                'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
              });
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? TrazoColors.coralDark : TrazoColors.bordeControl,
                    width: sel ? 3 : 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sel) ...[
                    const Icon(Icons.check_circle,
                        color: TrazoColors.coralDark, size: 28),
                    const SizedBox(width: 10),
                  ],
                  Flexible(child: _filaVisual(tokens, conInterrogante: false)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _opcion(String op, double alto, [bool visual = false]) {
    final sel = op == _elegida;
    // Ficha (color/figura) DELANTE solo en actividades visuales; en preguntas
    // normales una opción "rojo"/"naranja" va como texto, sin círculo.
    final fop = visual
        ? _parseFicha(op)
        : (figura: null, color: null, esVisual: false);
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
                      color: sel ? TrazoColors.coralDark : TrazoColors.bordeControl,
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
                    if (fop.figura != null) ...[
                      _FiguraMini(fop.figura!, size: 42, color: fop.color),
                      const SizedBox(width: 14),
                    ] else if (fop.color != null) ...[
                      _circuloColor(fop.color!, 40),
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
