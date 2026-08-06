import 'package:flutter/material.dart';
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

  final List<Offset> _puntosUsuario = []; // en coords del viewBox
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _guia = parseSvgPathData(render['guide_path'] as String);
    _tolerancia = (render['tolerancia_px'] as num?)?.toDouble() ?? 24.0;
    final vb = (render['viewbox'] as String? ?? '0 0 300 140').split(' ');
    _vbW = double.tryParse(vb[2]) ?? 300;
    _vbH = double.tryParse(vb[3]) ?? 140;
    _muestrasGuia = _muestrear(_guia, paso: 3.0);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            widget.instancia.render['instruccion'] as String? ??
                'Sigue la línea con el dedo',
            style: const TextStyle(fontSize: 22, color: TrazoColors.ink),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size =
                  Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: (d) => setState(
                    () => _puntosUsuario.add(_aViewBox(d.localPosition, size))),
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
      ],
    );
  }
}

class _TrazoPainter extends CustomPainter {
  final Path guia;
  final List<Offset> puntosUsuario;
  final double vbW;
  final double vbH;

  _TrazoPainter({
    required this.guia,
    required this.puntosUsuario,
    required this.vbW,
    required this.vbH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final escala = (size.width / vbW).clamp(0.0, size.height / vbH);
    final dx = (size.width - vbW * escala) / 2;
    final dy = (size.height - vbH * escala) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(escala);

    // Guía
    final guiaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFDCD3BE);
    canvas.drawPath(guia, guiaPaint);

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
