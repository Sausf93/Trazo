import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'reto_contenedor.dart';

/// Reto interactivo de GARRAFAS (decantación de líquido). El grupo mide una
/// cantidad exacta pasando agua entre garrafas de distinta capacidad y la echa
/// en una GARRAFA TAPADA (opaca): no se ve cuánta lleva, y solo al pulsar
/// "Comprobar" la app dice si hay dentro los litros justos.
///
/// Así es como lo pidió Saulo: las garrafas normales sirven para MEDIR, y hay
/// una tercera —tapada, con un "?"— que es la meta: hay que dejar en ELLA los
/// litros exactos. Interacción doble y accesible: ARRASTRAR una garrafa sobre
/// otra para verter, o TOCAR una y luego otra. No mide desempeño individual:
/// es un juego de grupo.
class RetoGarrafas {
  final String titulo;
  final String enunciado;
  final List<int> capacidades; // litros de cada garrafa de trabajo
  final List<int> iniciales; // litros de partida (vacío = todas a 0)
  final int objetivo; // litros exactos a dejar en la garrafa tapada
  final bool conGrifo; // si hay grifo/desagüe (llenar y vaciar)

  const RetoGarrafas({
    required this.titulo,
    required this.enunciado,
    required this.capacidades,
    required this.objetivo,
    List<int>? iniciales,
    this.conGrifo = true,
  }) : iniciales = iniciales ?? const [];

  /// Construye el reto desde el `render` de una Instancia del catálogo (banco).
  factory RetoGarrafas.desdeRender(Map<String, dynamic> r) {
    List<int> comoInts(dynamic v) =>
        (v as List? ?? const []).map((e) => (e as num).toInt()).toList();
    return RetoGarrafas(
      titulo: (r['titulo'] ?? '').toString(),
      enunciado: (r['enunciado'] ?? '').toString(),
      capacidades: comoInts(r['capacidades']),
      objetivo: (r['objetivo'] as num? ?? 0).toInt(),
      iniciales: comoInts(r['iniciales']),
      conGrifo: r['con_grifo'] != false,
    );
  }
}

class RetoGarrafasWidget extends StatefulWidget {
  final RetoGarrafas reto;

  /// Opcional: en el BANCO/kiosco se reporta el resultado ({resuelto, movimientos})
  /// cuando el grupo lo consigue. En la sección Retos suelta va sin métricas.
  final ValueChanged<Map<String, dynamic>>? onMetricas;
  const RetoGarrafasWidget({super.key, required this.reto, this.onMetricas});

  @override
  State<RetoGarrafasWidget> createState() => _RetoGarrafasWidgetState();
}

class _RetoGarrafasWidgetState extends State<RetoGarrafasWidget> {
  // Capacidades internas = garrafas de trabajo + la garrafa TAPADA (objetivo).
  late List<int> _caps;
  late List<int> _nivel;
  late int _idxTapada; // índice de la garrafa opaca (la última)
  int _movimientos = 0;
  int? _sel; // garrafa seleccionada (para verter por toque)
  bool _celebrado = false;
  String? _feedback; // null / 'ok' / 'no' tras pulsar Comprobar

  bool get _resuelto => _nivel[_idxTapada] == widget.reto.objetivo;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final r = widget.reto;
    final maxTrabajo =
        r.capacidades.isEmpty ? 0 : r.capacidades.reduce(math.max);
    // La tapada debe poder contener el objetivo: capacidad = la mayor de trabajo.
    final capTapada = math.max(maxTrabajo, r.objetivo);
    setState(() {
      _caps = [...r.capacidades, capTapada];
      _idxTapada = _caps.length - 1;
      final base = r.iniciales.length == r.capacidades.length
          ? List<int>.from(r.iniciales)
          : List<int>.filled(r.capacidades.length, 0);
      _nivel = [...base, 0]; // la tapada empieza vacía
      _movimientos = 0;
      _sel = null;
      _celebrado = false;
      _feedback = null;
    });
  }

  // Comprobar (a petición del grupo): NO se gana solo; se prueba y la app dice
  // si en la garrafa tapada ya están los litros justos, y se puede seguir.
  void _comprobar() {
    final ok = _resuelto;
    HapticFeedback.mediumImpact();
    setState(() {
      _feedback = ok ? 'ok' : 'no';
      if (ok && !_celebrado) {
        _celebrado = true;
        widget.onMetricas
            ?.call({'resuelto': true, 'movimientos': _movimientos});
      }
    });
  }

  void _verter(int src, int dst) {
    if (src == dst) {
      setState(() => _sel = null);
      return;
    }
    final cabe = _caps[dst] - _nivel[dst];
    final pasa = _nivel[src] < cabe ? _nivel[src] : cabe;
    if (pasa <= 0) {
      setState(() => _sel = null);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _nivel[src] -= pasa;
      _nivel[dst] += pasa;
      _movimientos++;
      _sel = null;
      _feedback = null;
    });
  }

  void _llenar(int i) {
    if (_nivel[i] == _caps[i]) return;
    HapticFeedback.selectionClick();
    setState(() {
      _nivel[i] = _caps[i];
      _movimientos++;
      _sel = null;
      _feedback = null;
    });
  }

  void _vaciar(int i) {
    if (_nivel[i] == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _nivel[i] = 0;
      _movimientos++;
      _sel = null;
      _feedback = null;
    });
  }

  void _tocar(int i) {
    if (_sel == null) {
      setState(() => _sel = i);
    } else if (_sel == i) {
      setState(() => _sel = null);
    } else {
      _verter(_sel!, i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reto;
    if (r.capacidades.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Este reto no se puede mostrar.',
              style: TextStyle(fontSize: 18, color: TrazoColors.ink)),
        ),
      );
    }
    final maxCap = _caps.reduce(math.max);
    return RetoContenedor(child: LayoutBuilder(builder: (context, outer) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: outer.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            r.enunciado,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, color: TrazoColors.ink, height: 1.25),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
              'Meta: dejar ${r.objetivo} litros exactos en la garrafa tapada (la del  ?  )',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.sageDark)),
        ),
        // Pista de USO clara (mayores): cómo se vierte de una garrafa a otra.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            _sel == null
                ? 'Mide con las garrafas y echa el agua en la tapada. Toca una garrafa y luego otra para pasar el agua.'
                : 'Ahora toca la garrafa donde quieres echar el agua.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: _sel == null
                    ? TrazoColors.bordeControl
                    : TrazoColors.coralDark,
                fontWeight: _sel == null ? FontWeight.normal : FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 300,
          child: LayoutBuilder(
            builder: (context, cons) {
              final reservaBotones = r.conGrifo ? 56.0 : 8.0;
              final altoMax =
                  (cons.maxHeight - 78 - reservaBotones).clamp(90.0, 250.0);
              return Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _caps.length; i++) ...[
                        if (i == _idxTapada) _separadorMeta(),
                        _garrafa(i, maxCap, altoMax),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_feedback != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: TrazoColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _feedback == 'ok'
                      ? TrazoColors.sageDark
                      : TrazoColors.coralDark,
                  width: 2.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _feedback == 'ok'
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: _feedback == 'ok'
                        ? TrazoColors.sageDark
                        : TrazoColors.coralDark,
                    size: 30),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                      _feedback == 'ok'
                          ? '¡Muy bien! En la garrafa tapada hay ${widget.reto.objetivo} litros exactos ($_movimientos movimientos).'
                          : 'En la garrafa tapada no hay ${widget.reto.objetivo} litros. Vaciadla y seguid probando.',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _feedback == 'ok'
                              ? TrazoColors.sageDark
                              : TrazoColors.coralDark)),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Movimientos: $_movimientos',
                  style: const TextStyle(
                      fontSize: 16, color: TrazoColors.bordeControl)),
              ElevatedButton.icon(
                onPressed: _comprobar,
                icon: const Icon(Icons.check),
                label: const Text('Comprobar la tapada'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrazoColors.sageDark,
                  foregroundColor: TrazoColors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Empezar de nuevo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TrazoColors.sageDark,
                  side: const BorderSide(
                      color: TrazoColors.bordeControl, width: 1.6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
          ),
        ),
      );
    }));
  }

  // Pequeña señal visual de que la garrafa tapada es la META (flecha + texto).
  Widget _separadorMeta() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_forward, color: TrazoColors.coralDark, size: 26),
          SizedBox(height: 4),
          SizedBox(
            width: 54,
            child: Text('aquí va\nla meta',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: TrazoColors.coralDark)),
          ),
        ],
      ),
    );
  }

  Widget _garrafa(int i, int maxCap, double altoMax) {
    final cap = _caps[i];
    final litros = _nivel[i];
    final seleccion = _sel == i;
    final tapada = i == _idxTapada;
    final altoMin = (altoMax * 0.55).clamp(80.0, 130.0);
    final alto = altoMin + (altoMax - altoMin) * (cap / maxCap);
    final ancho = (altoMax * 0.42).clamp(72.0, 104.0);

    Widget jarra(double a, double al, {bool comoFeedback = false}) =>
        _JarraPintada(
          litros: litros,
          capacidad: cap,
          seleccionada: seleccion || comoFeedback,
          opaca: tapada, // la tapada no muestra su nivel
          ancho: a,
          alto: al,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encima: los litros (o "?" en la tapada, para que no se vea).
          Text(tapada ? '?' : '$litros L',
              style: TextStyle(
                  fontSize: tapada ? 28 : 26,
                  fontWeight: FontWeight.w900,
                  color: tapada ? TrazoColors.coralDark : TrazoColors.ink)),
          const SizedBox(height: 4),
          DragTarget<int>(
            onWillAcceptWithDetails: (d) => d.data != i,
            onAcceptWithDetails: (d) => _verter(d.data, i),
            builder: (context, cand, rej) {
              final resaltar = cand.isNotEmpty;
              return Draggable<int>(
                data: i,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Opacity(
                    opacity: 0.85,
                    child: jarra(ancho * 0.8, alto * 0.8, comoFeedback: true)),
                childWhenDragging:
                    Opacity(opacity: 0.35, child: jarra(ancho, alto)),
                child: GestureDetector(
                  onTap: () => _tocar(i),
                  child: AnimatedScale(
                    scale: resaltar ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: jarra(ancho, alto),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(tapada ? 'tapada · la meta' : 'de $cap L',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: tapada ? FontWeight.w700 : FontWeight.normal,
                  color: tapada
                      ? TrazoColors.coralDark
                      : TrazoColors.bordeControl)),
          if (widget.reto.conGrifo || tapada) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // La tapada NO se llena del grifo (sería trampa): solo se vacía.
                if (!tapada && widget.reto.conGrifo)
                  _mini('Llenar', Icons.water_drop, () => _llenar(i)),
                if (!tapada && widget.reto.conGrifo) const SizedBox(width: 6),
                _mini('Vaciar', Icons.south, () => _vaciar(i)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String txt, IconData ic, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: TrazoColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TrazoColors.bordeControl, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 16, color: TrazoColors.sageDark),
            const SizedBox(width: 4),
            Text(txt,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TrazoColors.sageDark)),
          ],
        ),
      ),
    );
  }
}

/// Dibuja una garrafa con su nivel de agua (relleno azul desde abajo) y marcas
/// de litro. Si `opaca`, es la garrafa TAPADA: no se ve el nivel (sólida, con
/// un "?" en el cuerpo), para que el grupo tenga que medir de verdad.
class _JarraPintada extends StatelessWidget {
  final int litros;
  final int capacidad;
  final bool seleccionada;
  final bool opaca;
  final double ancho;
  final double alto;
  const _JarraPintada({
    required this.litros,
    required this.capacidad,
    required this.seleccionada,
    required this.ancho,
    required this.alto,
    this.opaca = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(ancho, alto),
            painter: _GarrafaPainter(
                litros: litros,
                capacidad: capacidad,
                seleccionada: seleccionada,
                opaca: opaca),
          ),
          if (opaca)
            Padding(
              padding: EdgeInsets.only(top: alto * 0.12),
              child: Text('?',
                  style: TextStyle(
                      fontSize: alto * 0.34,
                      fontWeight: FontWeight.w900,
                      color: TrazoColors.white)),
            ),
        ],
      ),
    );
  }
}

/// Silueta de GARRAFA (cuerpo + cuello) con el agua dentro. Pensada para que un
/// mayor la reconozca de un vistazo como una garrafa de agua de verdad.
class _GarrafaPainter extends CustomPainter {
  final int litros;
  final int capacidad;
  final bool seleccionada;
  final bool opaca;
  _GarrafaPainter(
      {required this.litros,
      required this.capacidad,
      required this.seleccionada,
      this.opaca = false});

  Path _silueta(double w, double h) {
    final p = Path();
    p.moveTo(w * 0.36, h * 0.03);
    p.lineTo(w * 0.36, h * 0.13);
    p.quadraticBezierTo(w * 0.10, h * 0.19, w * 0.07, h * 0.36);
    p.lineTo(w * 0.07, h * 0.90);
    p.quadraticBezierTo(w * 0.07, h * 0.985, w * 0.20, h * 0.985);
    p.lineTo(w * 0.80, h * 0.985);
    p.quadraticBezierTo(w * 0.93, h * 0.985, w * 0.93, h * 0.90);
    p.lineTo(w * 0.93, h * 0.36);
    p.quadraticBezierTo(w * 0.90, h * 0.19, w * 0.64, h * 0.13);
    p.lineTo(w * 0.64, h * 0.03);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final jug = _silueta(w, h);

    if (opaca) {
      // Garrafa TAPADA: cuerpo sólido (no se ve el agua). Tono coral suave para
      // que destaque como "la meta". Sin marcas ni nivel.
      canvas.drawPath(jug, Paint()..color = TrazoColors.coralDark);
      canvas.drawPath(
          jug,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = seleccionada ? 5 : 3
            ..strokeJoin = StrokeJoin.round
            ..color = seleccionada
                ? TrazoColors.ink
                : TrazoColors.coralDark);
      return;
    }

    canvas.drawPath(jug, Paint()..color = TrazoColors.white);
    canvas.save();
    canvas.clipPath(jug);
    final frac = capacidad == 0 ? 0.0 : (litros / capacidad).clamp(0.0, 1.0);
    final top = h * 0.985 - (h * 0.955 * frac);
    if (frac > 0) {
      canvas.drawRect(Rect.fromLTWH(0, top, w, h),
          Paint()..color = const Color(0xFF5FB6E6).withValues(alpha: 0.92));
      canvas.drawRect(Rect.fromLTWH(0, top, w, 4),
          Paint()..color = const Color(0xFF3E97C9));
    }
    final linea = Paint()
      ..color = TrazoColors.sand
      ..strokeWidth = 1.2;
    for (var l = 1; l < capacidad; l++) {
      final y = h * 0.985 - (h * 0.955 * (l / capacidad));
      canvas.drawLine(Offset(w * 0.07, y), Offset(w * 0.24, y), linea);
    }
    canvas.restore();
    canvas.drawPath(
        jug,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = seleccionada ? 5 : 2.5
          ..strokeJoin = StrokeJoin.round
          ..color =
              seleccionada ? TrazoColors.coralDark : TrazoColors.bordeControl);
  }

  @override
  bool shouldRepaint(_GarrafaPainter old) =>
      old.litros != litros ||
      old.capacidad != capacidad ||
      old.seleccionada != seleccionada ||
      old.opaca != opaca;
}
