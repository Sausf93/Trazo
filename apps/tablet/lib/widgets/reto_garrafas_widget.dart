import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Reto interactivo de GARRAFAS (decantación de líquido). El grupo mide una
/// cantidad exacta pasando agua entre garrafas de distinta capacidad.
///
/// Interacción doble (accesible + como pidió Saulo): se puede ARRASTRAR una
/// garrafa sobre otra para verter, o TOCAR una y luego otra. Botones "Llenar"
/// (del grifo) y "Vaciar" cuando el reto tiene fuente de agua (`conGrifo`).
/// Es autoevaluable en el propio widget: gana cuando alguna garrafa tiene el
/// objetivo exacto. No mide desempeño individual: es un juego de grupo.
class RetoGarrafas {
  final String titulo;
  final String enunciado;
  final List<int> capacidades; // litros de cada garrafa
  final List<int> iniciales; // litros de partida (vacío = todas a 0)
  final int objetivo; // litros exactos a conseguir en alguna garrafa
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
  late List<int> _nivel;
  int _movimientos = 0;
  int? _sel; // garrafa seleccionada (para verter por toque)
  bool _celebrado = false;

  bool get _resuelto => _nivel.any((l) => l == widget.reto.objetivo);

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final r = widget.reto;
    setState(() {
      _nivel = r.iniciales.length == r.capacidades.length
          ? List<int>.from(r.iniciales)
          : List<int>.filled(r.capacidades.length, 0);
      _movimientos = 0;
      _sel = null;
      _celebrado = false;
    });
  }

  void _trasMover() {
    if (_resuelto && !_celebrado) {
      _celebrado = true;
      HapticFeedback.mediumImpact();
      widget.onMetricas
          ?.call({'resuelto': true, 'movimientos': _movimientos});
    }
  }

  void _verter(int src, int dst) {
    if (src == dst) {
      setState(() => _sel = null);
      return;
    }
    final caps = widget.reto.capacidades;
    final cabe = caps[dst] - _nivel[dst];
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
    });
    _trasMover();
  }

  void _llenar(int i) {
    final cap = widget.reto.capacidades[i];
    if (_nivel[i] == cap) return;
    HapticFeedback.selectionClick();
    setState(() {
      _nivel[i] = cap;
      _movimientos++;
      _sel = null;
    });
    _trasMover();
  }

  void _vaciar(int i) {
    if (_nivel[i] == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _nivel[i] = 0;
      _movimientos++;
      _sel = null;
    });
    _trasMover();
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
    final maxCap = r.capacidades.reduce((a, b) => a > b ? a : b);
    return Column(
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Meta: dejar ${r.objetivo} L exactos en una garrafa',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.sageDark)),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, cons) {
              // Alto de la garrafa más alta: cabe en el espacio disponible menos
              // el hueco de las etiquetas y los botones (así se encoge en móvil).
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
                      for (var i = 0; i < r.capacidades.length; i++)
                        _garrafa(i, maxCap, altoMax),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_resuelto)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: TrazoColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TrazoColors.sageDark, width: 2.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: TrazoColors.sageDark, size: 30),
                const SizedBox(width: 12),
                Text('¡Lo habéis conseguido!  ($_movimientos movimientos)',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: TrazoColors.sageDark)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Movimientos: $_movimientos',
                  style: const TextStyle(
                      fontSize: 16, color: TrazoColors.bordeControl)),
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
    );
  }

  Widget _garrafa(int i, int maxCap, double altoMax) {
    final cap = widget.reto.capacidades[i];
    final litros = _nivel[i];
    final seleccion = _sel == i;
    // Alto proporcional a la capacidad (para que se lea el tamaño relativo),
    // acotado al espacio disponible (móvil).
    final altoMin = (altoMax * 0.55).clamp(80.0, 130.0);
    final alto = altoMin + (altoMax - altoMin) * (cap / maxCap);
    final ancho = (altoMax * 0.42).clamp(72.0, 104.0);

    final jarra = _JarraPintada(
      litros: litros,
      capacidad: cap,
      seleccionada: seleccion,
      ancho: ancho,
      alto: alto,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$litros L',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: TrazoColors.ink)),
          const SizedBox(height: 4),
          // Arrastrar esta garrafa sobre otra = verter. También acepta soltar.
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
                  child: _JarraPintada(
                    litros: litros,
                    capacidad: cap,
                    seleccionada: true,
                    ancho: ancho * 0.8,
                    alto: alto * 0.8,
                  ),
                ),
                childWhenDragging:
                    Opacity(opacity: 0.35, child: jarra),
                child: GestureDetector(
                  onTap: () => _tocar(i),
                  child: AnimatedScale(
                    scale: resaltar ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: jarra,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text('de $cap L',
              style: const TextStyle(
                  fontSize: 15, color: TrazoColors.bordeControl)),
          if (widget.reto.conGrifo) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mini('Llenar', Icons.water_drop, () => _llenar(i)),
                const SizedBox(width: 6),
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
/// de litro para que se pueda "leer" cuánto lleva.
class _JarraPintada extends StatelessWidget {
  final int litros;
  final int capacidad;
  final bool seleccionada;
  final double ancho;
  final double alto;
  const _JarraPintada({
    required this.litros,
    required this.capacidad,
    required this.seleccionada,
    required this.ancho,
    required this.alto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        color: TrazoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seleccionada ? TrazoColors.coralDark : TrazoColors.bordeControl,
          width: seleccionada ? 4 : 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: CustomPaint(
          size: Size(ancho, alto),
          painter: _AguaPainter(litros: litros, capacidad: capacidad),
        ),
      ),
    );
  }
}

class _AguaPainter extends CustomPainter {
  final int litros;
  final int capacidad;
  _AguaPainter({required this.litros, required this.capacidad});

  @override
  void paint(Canvas canvas, Size size) {
    // Agua
    final frac = capacidad == 0 ? 0.0 : litros / capacidad;
    final hAgua = size.height * frac;
    final rectAgua = Rect.fromLTWH(0, size.height - hAgua, size.width, hAgua);
    canvas.drawRect(
        rectAgua, Paint()..color = const Color(0xFF5FB6E6).withValues(alpha: 0.9));
    if (hAgua > 4) {
      canvas.drawRect(
          Rect.fromLTWH(0, size.height - hAgua, size.width, 4),
          Paint()..color = const Color(0xFF3E97C9));
    }
    // Marcas de litro
    final linea = Paint()
      ..color = TrazoColors.sand
      ..strokeWidth = 1;
    for (var l = 1; l < capacidad; l++) {
      final y = size.height - size.height * (l / capacidad);
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.22, y), linea);
    }
  }

  @override
  bool shouldRepaint(_AguaPainter old) =>
      old.litros != litros || old.capacidad != capacidad;
}
