import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza un ejercicio de plantilla `trazo`: dibuja la guía (SVG path),
/// captura el trazo del dedo y calcula una precisión aproximada (fracción de
/// puntos del usuario que caen dentro de la tolerancia respecto a la guía).
class TrazoWidget extends StatefulWidget {
  final Instancia instancia;

  /// Se llama al terminar cada trazo con las métricas acumuladas.
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const TrazoWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<TrazoWidget> createState() => _TrazoWidgetState();
}

class _TrazoWidgetState extends State<TrazoWidget>
    with SingleTickerProviderStateMixin {
  late final Path _guia;
  late final List<Offset> _muestrasGuia; // en coords del viewBox
  late final double _vbW;
  late final double _vbH;
  late final double _tolerancia;

  // Guía DINÁMICA: un punto animado recorre los sub-trazos UNO A UNO, en orden de
  // escritura (primero el paso 1 entero, luego el 2…). Solo se ve el movimiento
  // del trazo ACTUAL (la estela no salta de un trazo a otro) y solo su número, así
  // no se solapan (feedback de Saulo). Cada sub-trazo va en su propia lista.
  late final List<List<Offset>> _trazos;
  late final AnimationController _anim;

  // Trazos del usuario: UNA lista por cada vez que baja el dedo/lápiz (entre
  // `onPanStart` y `onPanEnd`). Antes era una sola lista plana y el pintor unía
  // todos los puntos, así que al levantar y volver a bajar (letras de varios
  // trazos: E, F, T…) dibujaba una línea del final de un trazo al inicio del
  // siguiente. Guardándolos separados, cada trazo se pinta solo (feedback Saulo).
  final List<List<Offset>> _trazosUsuario = []; // en coords del viewBox
  Iterable<Offset> get _puntosUsuario => _trazosUsuario.expand((t) => t);
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    // Cast tolerante: una instancia malformada no debe tumbar la tablet.
    final gp = render['guide_path'];
    // parseSvgPathData LANZA si el path no es vacío pero está mal formado; sin
    // proteger, tumbaría la tablet en initState. Ante un path inválido, guía vacía.
    Path guia;
    try {
      guia = (gp is String && gp.isNotEmpty) ? parseSvgPathData(gp) : Path();
    } catch (_) {
      guia = Path();
    }
    _guia = guia;
    _tolerancia = (render['tolerancia_px'] as num?)?.toDouble() ?? 24.0;
    final vb = (render['viewbox'] as String? ?? '0 0 300 140').split(' ');
    _vbW = (vb.length > 2 ? double.tryParse(vb[2]) : null) ?? 300;
    _vbH = (vb.length > 3 ? double.tryParse(vb[3]) : null) ?? 140;
    _trazos = _muestrearPorTrazo(_guia, paso: 3.0);
    _muestrasGuia = [for (final t in _trazos) ...t];
    // Duración proporcional al recorrido total (palabras largas → más lento).
    final segs = (2.2 + _muestrasGuia.length / 80).clamp(2.2, 7.0);
    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (segs * 1000).round()),
    )..repeat();
  }

  /// Muestrea cada sub-trazo por separado (una lista de puntos por contorno), en
  /// orden de escritura. Así la animación va trazo a trazo sin unir unos con otros.
  List<List<Offset>> _muestrearPorTrazo(Path path, {double paso = 3.0}) {
    final trazos = <List<Offset>>[];
    for (final metric in path.computeMetrics()) {
      final pts = <Offset>[];
      double d = 0;
      while (d <= metric.length) {
        final t = metric.getTangentForOffset(d);
        if (t != null) pts.add(t.position);
        d += paso;
      }
      if (pts.length >= 2) trazos.add(pts);
    }
    return trazos;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Escala/offset para encajar el viewBox dentro del área disponible.
  double _escala(Size size) =>
      (size.width / _vbW).clamp(0.0, size.height / _vbH);
  Offset _offset(Size size, double escala) => Offset(
        (size.width - _vbW * escala) / 2,
        (size.height - _vbH * escala) / 2,
      );

  Offset _aViewBox(Offset local, Size size) {
    final e = _escala(size);
    final o = _offset(size, e);
    return Offset((local.dx - o.dx) / e, (local.dy - o.dy) / e);
  }

  double _distanciaMinima(Offset p) {
    double min = double.infinity;
    for (final g in _muestrasGuia) {
      final d = (p - g).distance;
      if (d < min) min = d;
    }
    return min;
  }

  void _limpiar() {
    HapticFeedback.selectionClick();
    setState(() => _trazosUsuario.clear());
    // Vuelve a dejar la métrica "sin trazo" para no arrastrar el intento erróneo.
    widget.onMetricas({
      'precision': null,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
      'puntos_capturados': 0,
    });
  }

  void _emitirMetricas() {
    final puntos = _puntosUsuario.toList();
    if (puntos.isEmpty) return;
    int dentro = 0;
    for (final p in puntos) {
      if (_distanciaMinima(p) <= _tolerancia) dentro++;
    }
    final precision = dentro / puntos.length;
    widget.onMetricas({
      'precision': double.parse(precision.toStringAsFixed(3)),
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
      'puntos_capturados': puntos.length,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Móvil vertical (viewport estrecho/bajo): el lienzo es a pantalla completa
    // y se auto-escala, así que NUNCA se recorta ni se sale. Aquí solo aliviamos
    // la tipografía del enunciado para que no coma la altura del área de dibujo
    // (ni se corte al envolver). NO se envuelve en scroll: robaría los gestos de
    // trazo. El aspecto en tablet (ancho) queda idéntico.
    return LayoutBuilder(
      builder: (context, c) {
        final estrecho = c.maxWidth < 520 || c.maxHeight < 640;
        return _contenido(estrecho);
      },
    );
  }

  Widget _contenido(bool estrecho) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: estrecho ? 8 : 12),
          child: Text(
            widget.instancia.render['instruccion'] as String? ??
                'Sigue la línea con el dedo o el lápiz',
            style:
                TextStyle(fontSize: estrecho ? 20 : 26, color: TrazoColors.ink),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                key: const ValueKey('trazo-lienzo'),
                onPanStart: (d) {
                  HapticFeedback
                      .selectionClick(); // confirma que empezó a trazar
                  // Nuevo sub-trazo: NO se une con el anterior.
                  setState(() => _trazosUsuario
                      .add([_aViewBox(d.localPosition, size)]));
                },
                onPanUpdate: (d) => setState(() {
                  if (_trazosUsuario.isNotEmpty) {
                    _trazosUsuario.last.add(_aViewBox(d.localPosition, size));
                  }
                }),
                onPanEnd: (_) => _emitirMetricas(),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF4),
                    border: Border.all(color: TrazoColors.bordeControl, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CustomPaint(
                    painter: _TrazoPainter(
                      guia: _guia,
                      trazosUsuario: _trazosUsuario,
                      trazos: _trazos,
                      t: _anim,
                      vbW: _vbW,
                      vbH: _vbH,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
        // Rehacer el trazo: un temblor o un gesto erróneo no arruina el intento.
        // Objetivo táctil amplio y centrado: es la acción de rescate, justo para
        // manos que tiemblan, así que tiene que ser fácil de acertar y de ver.
        Padding(
          padding: EdgeInsets.only(top: estrecho ? 8 : 12),
          child: Center(
            child: OutlinedButton.icon(
              onPressed: _trazosUsuario.isEmpty ? null : _limpiar,
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text('Empezar de nuevo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: TrazoColors.sageDark,
                side: const BorderSide(color: TrazoColors.bordeControl, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                minimumSize: const Size(0, 56),
                textStyle:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrazoPainter extends CustomPainter {
  final Path guia;
  final List<List<Offset>> trazosUsuario; // un trazo del usuario por pen-down
  final List<List<Offset>>
      trazos; // puntos por sub-trazo de la GUÍA, en orden de escritura
  final Animation<double> t; // 0..1 en bucle
  final double vbW;
  final double vbH;

  _TrazoPainter({
    required this.guia,
    required this.trazosUsuario,
    required this.trazos,
    required this.t,
    required this.vbW,
    required this.vbH,
  }) : super(repaint: t);

  int get _totalPuntosUsuario =>
      trazosUsuario.fold(0, (a, t) => a + t.length);

  /// La guía en PUNTITOS (como un cuadernillo de caligrafía) para repasar encima.
  Path _puntitos(Path fuente, {double punto = 2.5, double hueco = 11}) {
    final dest = Path();
    for (final m in fuente.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final fin = math.min(d + punto, m.length);
        dest.addPath(m.extractPath(d, fin), Offset.zero);
        d += punto + hueco;
      }
    }
    return dest;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final escala = (size.width / vbW).clamp(0.0, size.height / vbH);
    final dx = (size.width - vbW * escala) / 2;
    final dy = (size.height - vbH * escala) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(escala);

    // Guía en PUNTITOS (cuadernillo de caligrafía): el mayor repasa encima de
    // los puntos. Se dibuja primero un trazo continuo muy tenue (para no perder
    // el recorrido) y encima los puntos, más marcados, en 'sand' con contraste.
    canvas.drawPath(
      guia,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = TrazoColors.sand.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      _puntitos(guia),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = TrazoColors.sand,
    );

    // GUÍA DINÁMICA PASO A PASO: se anima UN sub-trazo cada vez (paso 1 entero,
    // pausa, paso 2…). Solo se ve la estela del trazo ACTUAL (no se une con otros)
    // y solo su número, en su punto de arranque.
    if (trazos.isNotEmpty) {
      // Reparte el tiempo entre los sub-trazos (por su longitud) + una pausa entre
      // cada uno, para que se entienda dónde empieza cada trazo.
      const pausa = 0.35; // fracción de "peso" de pausa por trazo
      final pesos = [for (final s in trazos) s.length.toDouble() + 1];
      final total = pesos.fold(0.0, (a, b) => a + b) * (1 + pausa);
      double acum = 0;
      int actual = 0;
      double localP = 0; // 0..1 dentro del trazo (o >1 = en pausa)
      final tt = t.value * total;
      for (var i = 0; i < trazos.length; i++) {
        final trazo = pesos[i];
        final pausaI = pesos[i] * pausa;
        if (tt < acum + trazo) {
          actual = i;
          localP = (tt - acum) / trazo;
          break;
        }
        if (tt < acum + trazo + pausaI) {
          actual = i;
          localP = 1.0; // pausa: trazo completo mostrado
          break;
        }
        acum += trazo + pausaI;
        actual = i;
        localP = 1.0;
      }
      final pts = trazos[actual];
      final cabeza =
          (localP * (pts.length - 1)).floor().clamp(0, pts.length - 1);
      // Estela del trazo actual (hasta la cabeza), desvaneciéndose.
      const largoEstela = 22;
      for (var k = 0; k < largoEstela; k++) {
        final idx = cabeza - k;
        if (idx < 0) break;
        final alpha = (1 - k / largoEstela) * 0.9;
        canvas.drawCircle(pts[idx], 6.5 - k * 0.16,
            Paint()..color = TrazoColors.coralDark.withValues(alpha: alpha));
      }
      // Cabeza: el "lápiz" que escribe.
      canvas.drawCircle(pts[cabeza], 12,
          Paint()..color = Colors.white.withValues(alpha: 0.9));
      canvas.drawCircle(pts[cabeza], 9, Paint()..color = TrazoColors.coralDark);

      // Número del trazo ACTUAL (solo ese), latiendo en su arranque. Si solo hay
      // un sub-trazo (espiral, círculo…), no se pone número: estorbaría.
      if (trazos.length > 1) {
        final ini = pts.first;
        final pulso = 0.5 + 0.5 * math.sin(t.value * 2 * math.pi * 3);
        canvas.drawCircle(
            ini,
            14 + pulso * 5,
            Paint()
              ..color =
                  TrazoColors.sageDark.withValues(alpha: 0.22 * (1 - pulso)));
        canvas.drawCircle(
            ini, 11, Paint()..color = Colors.white.withValues(alpha: 0.95));
        canvas.drawCircle(ini, 9.5, Paint()..color = TrazoColors.sage);
        final tp = TextPainter(
          text: TextSpan(
            text: '${actual + 1}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(ini.dx - tp.width / 2, ini.dy - tp.height / 2));
      }
    }

    // Trazo del usuario: CADA sub-trazo por separado (no se unen entre sí).
    final userPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = TrazoColors.coralDark;
    for (final trazo in trazosUsuario) {
      if (trazo.isEmpty) continue;
      if (trazo.length == 1) {
        // Un solo toque (punto): un puntito, para que se vea que marcó ahí.
        canvas.drawCircle(trazo.first, 3, Paint()..color = TrazoColors.coralDark);
        continue;
      }
      final path = Path()..moveTo(trazo.first.dx, trazo.first.dy);
      for (final p in trazo.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, userPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrazoPainter old) =>
      old._totalPuntosUsuario != _totalPuntosUsuario ||
      old.trazosUsuario.length != trazosUsuario.length;
}
