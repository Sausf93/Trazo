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

class _TrazoWidgetState extends State<TrazoWidget> {
  late final Path _guia;
  late final List<Offset> _muestrasGuia; // en coords del viewBox
  late final double _vbW;
  late final double _vbH;
  late final double _tolerancia;

  // Guía tipo cuadernillo: cada sub-trazo se numera en su orden de escritura y
  // una flecha corta marca por dónde arranca. Imprescindible para mayores que
  // nunca aprendieron a escribir (apunte de Laura): siguen los números 1, 2, 3…
  late final List<(Offset, double)>
      _inicios; // por sub-trazo: posición + ángulo inicial

  final List<Offset> _puntosUsuario = []; // en coords del viewBox
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    // Cast tolerante: una instancia malformada no debe tumbar la tablet.
    final gp = render['guide_path'];
    _guia = (gp is String && gp.isNotEmpty) ? parseSvgPathData(gp) : Path();
    _tolerancia = (render['tolerancia_px'] as num?)?.toDouble() ?? 24.0;
    final vb = (render['viewbox'] as String? ?? '0 0 300 140').split(' ');
    _vbW = (vb.length > 2 ? double.tryParse(vb[2]) : null) ?? 300;
    _vbH = (vb.length > 3 ? double.tryParse(vb[3]) : null) ?? 140;
    _muestrasGuia = _muestrear(_guia, paso: 3.0);
    _inicios = _iniciosTrazos(_guia);
  }

  /// Inicio y dirección inicial de cada sub-trazo, EN ORDEN de escritura (1, 2,
  /// 3…). Estilo cuadernillo: el badge numerado se coloca un poco DENTRO del
  /// trazo (no en el vértice exacto) para que dos trazos que arrancan del mismo
  /// punto —p. ej. el palo y la barra alta de la E— no se solapen.
  List<(Offset, double)> _iniciosTrazos(Path path) {
    final res = <(Offset, double)>[];
    for (final metric in path.computeMetrics()) {
      final len = metric.length;
      if (len < 4) continue; // tramo insignificante
      final o = math.min(14.0, len * 0.3);
      final t = metric.getTangentForOffset(o) ?? metric.getTangentForOffset(0);
      if (t != null) res.add((t.position, t.angle));
    }
    return res;
  }

  List<Offset> _muestrear(Path path, {double paso = 3.0}) {
    final puntos = <Offset>[];
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final t = metric.getTangentForOffset(d);
        if (t != null) puntos.add(t.position);
        d += paso;
      }
    }
    return puntos;
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
    setState(() => _puntosUsuario.clear());
    // Vuelve a dejar la métrica "sin trazo" para no arrastrar el intento erróneo.
    widget.onMetricas({
      'precision': null,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
      'puntos_capturados': 0,
    });
  }

  void _emitirMetricas() {
    if (_puntosUsuario.isEmpty) return;
    int dentro = 0;
    for (final p in _puntosUsuario) {
      if (_distanciaMinima(p) <= _tolerancia) dentro++;
    }
    final precision = dentro / _puntosUsuario.length;
    widget.onMetricas({
      'precision': double.parse(precision.toStringAsFixed(3)),
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
      'puntos_capturados': _puntosUsuario.length,
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
                  setState(() =>
                      _puntosUsuario.add(_aViewBox(d.localPosition, size)));
                },
                onPanUpdate: (d) => setState(
                    () => _puntosUsuario.add(_aViewBox(d.localPosition, size))),
                onPanEnd: (_) => _emitirMetricas(),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF4),
                    border: Border.all(color: TrazoColors.sand, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: CustomPaint(
                    painter: _TrazoPainter(
                      guia: _guia,
                      puntosUsuario: _puntosUsuario,
                      inicios: _inicios,
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
              onPressed: _puntosUsuario.isEmpty ? null : _limpiar,
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text('Empezar de nuevo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: TrazoColors.sageDark,
                side: const BorderSide(color: TrazoColors.sand, width: 1.5),
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
  final List<Offset> puntosUsuario;
  final List<(Offset, double)> inicios; // por sub-trazo, en orden de escritura
  final double vbW;
  final double vbH;

  _TrazoPainter({
    required this.guia,
    required this.puntosUsuario,
    required this.inicios,
    required this.vbW,
    required this.vbH,
  });

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

    // Por cada sub-trazo, EN ORDEN de escritura: una flecha corta que sale del
    // inicio (el sentido) y un badge numerado (1, 2, 3…) como en el cuadernillo.
    final flechaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = TrazoColors.coralDark;
    for (var i = 0; i < inicios.length; i++) {
      final (pos, ang) = inicios[i];
      final dir = Offset(math.cos(ang), math.sin(ang));
      final perp = Offset(-dir.dy, dir.dx);
      // Flecha que arranca del badge y apunta hacia donde va el trazo.
      final tip = pos + dir * 20;
      final a = tip - dir * 11 + perp * 6.5;
      final b = tip - dir * 11 - perp * 6.5;
      canvas.drawPath(
        Path()
          ..moveTo(pos.dx + dir.dx * 9, pos.dy + dir.dy * 9)
          ..lineTo(tip.dx, tip.dy)
          ..moveTo(a.dx, a.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(b.dx, b.dy),
        flechaPaint,
      );
      // Badge numerado: disco verde con halo blanco y el número del trazo.
      canvas.drawCircle(
          pos, 12, Paint()..color = Colors.white.withValues(alpha: 0.95));
      canvas.drawCircle(pos, 10, Paint()..color = TrazoColors.sage);
      canvas.drawCircle(
        pos,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = TrazoColors.sageDark,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    // Trazo del usuario
    if (puntosUsuario.length > 1) {
      final userPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = TrazoColors.coralDark;
      final path = Path()
        ..moveTo(puntosUsuario.first.dx, puntosUsuario.first.dy);
      for (final p in puntosUsuario.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, userPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrazoPainter old) =>
      old.puntosUsuario.length != puntosUsuario.length;
}
