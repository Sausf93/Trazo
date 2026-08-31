import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import 'figura_geometrica.dart';
import 'ilustracion.dart';

/// Renderiza `busqueda_visual`: se muestra un OBJETIVO y una rejilla de dibujos
/// mezclados; la persona TOCA todos los que son el objetivo (p. ej. "toca todas
/// las llaves"). Auto-evaluable: registra aciertos/fallos. Basada en fichas del
/// centro (buscar y colorear la figura repetida).
class BusquedaVisualWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const BusquedaVisualWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<BusquedaVisualWidget> createState() => _BusquedaVisualWidgetState();
}

class _BusquedaVisualWidgetState extends State<BusquedaVisualWidget> {
  late final List<Map<String, dynamic>> _celdas;
  late final String _objetivoId;
  late final int _totalObjetivos;
  // Si NO todas las figuras de la actividad tienen foto, TODAS se pintan como
  // dibujo (coherentes), nunca fotos y dibujos mezclados en la misma actividad.
  late final bool _soloDibujo;
  final Set<int> _seleccionadas = {};
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _celdas = ((render['celdas'] ?? []) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final obj = render['objetivo'] is Map
        ? Map<String, dynamic>.from(render['objetivo'] as Map)
        : {'id': (render['objetivo'] ?? '').toString()};
    _objetivoId = (obj['id'] ?? '').toString();
    _totalObjetivos =
        _celdas.where((c) => (c['id'] ?? '').toString() == _objetivoId).length;
    // Todos los ids de figura de la actividad: objetivo + celdas (distractores).
    final idsFigura = <String>[
      _objetivoId,
      ..._celdas.map((c) => (c['id'] ?? '').toString()),
    ];
    _soloDibujo = !IlustracionResolver.todasConFoto(idsFigura);
  }

  void _emitir() {
    int aciertos = 0, fallos = 0;
    for (final i in _seleccionadas) {
      if ((_celdas[i]['id'] ?? '').toString() == _objetivoId) {
        aciertos++;
      } else {
        fallos++;
      }
    }
    widget.onMetricas({
      'aciertos': aciertos,
      'fallos': fallos,
      'objetivos': _totalObjetivos,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final instruccion = widget.instancia.render['instruccion'] as String? ??
        'Toca todas las iguales';
    return LayoutBuilder(
      builder: (context, c) {
        // Móvil vertical: viewport estrecho o bajo. Se usa una vista con scroll
        // y tamaños cómodos fijos para que nada se recorte ni se salga.
        final estrecho = c.maxWidth < 520 || c.maxHeight < 640;
        if (estrecho) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _objetivo(instruccion, estrecho: true),
                _progreso(),
                _rejilla(estrecho: true),
                const SizedBox(height: 12),
              ],
            ),
          );
        }
        return Column(
          children: [
            _objetivo(instruccion, estrecho: false),
            _progreso(),
            Expanded(child: _rejilla(estrecho: false)),
          ],
        );
      },
    );
  }

  /// Objetivo: qué hay que buscar, grande y claro. En móvil la figura es algo
  /// más pequeña y el texto puede envolver para que la fila no se salga de ancho.
  Widget _objetivo(String instruccion, {required bool estrecho}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TrazoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TrazoColors.sage, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(instruccion,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: TrazoColors.ink)),
          ),
          const SizedBox(width: 14),
          _figura(_objetivoId, estrecho ? 56 : 72),
        ],
      ),
    );
  }

  /// Cuántas del objetivo lleva encontradas, para que el mayor sepa si ya están
  /// todas (antes no había ninguna señal de "he terminado de buscar").
  Widget _progreso() {
    final encontradas = _seleccionadas
        .where((i) => (_celdas[i]['id'] ?? '').toString() == _objetivoId)
        .length;
    final completo = encontradas >= _totalObjetivos && _totalObjetivos > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        completo ? '¡Las has encontrado todas!' : 'Encontradas: $encontradas',
        style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: completo ? TrazoColors.sageDark : TrazoColors.ink),
      ),
    );
  }

  Widget _rejilla({required bool estrecho}) {
    final n = _celdas.length;
    return LayoutBuilder(
      builder: (context, c) {
        // Nunca más columnas que celdas: evita huecos vacíos que descentran.
        // En móvil vertical usamos menos columnas para que las celdas no se hagan
        // diminutas y la figura siga siendo reconocible.
        final columnas = min(
            estrecho ? (n <= 4 ? 2 : 3) : (n <= 6 ? 3 : (n <= 12 ? 4 : 5)), n);
        final filas = (n / columnas).ceil();
        final gap = estrecho ? 14.0 : 22.0;
        final anchoCelda = (c.maxWidth - gap * (columnas - 1)) / columnas;
        final double lado;
        if (estrecho) {
          // Dentro de un scroll: el alto es ilimitado, así que la celda se
          // dimensiona por ancho con un mínimo cómodo (mejor scroll que recortar).
          lado = min(anchoCelda, 160.0);
        } else {
          final altoCelda = (c.maxHeight - gap * (filas - 1)) / filas;
          lado = min(min(anchoCelda, altoCelda), 200.0);
        }
        // La figura ocupa la mayor parte de la celda (antes 0.66 se veía pequeña,
        // sobre todo el pájaro y figuras con margen): se agranda para el mayor.
        final imgSize = (lado * 0.82).clamp(64.0, 168.0);

        final filasWidgets = <Widget>[];
        for (var f = 0; f < filas; f++) {
          final celdas = <Widget>[];
          for (var col = 0; col < columnas; col++) {
            final idx = f * columnas + col;
            if (idx >= n) break; // sin celdas vacías: la última fila se centra
            if (celdas.isNotEmpty) celdas.add(SizedBox(width: gap));
            celdas.add(_celda(idx, lado, imgSize));
          }
          if (f > 0) filasWidgets.add(SizedBox(height: gap));
          filasWidgets.add(Row(
              mainAxisAlignment: MainAxisAlignment.center, children: celdas));
        }
        return Center(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: filasWidgets),
        );
      },
    );
  }

  /// Pinta la figura por su id; si NO tiene ilustración (p. ej. los dígitos de
  /// "Busca el número 5"), muestra el propio texto GRANDE y legible en vez del
  /// círculo con inicial fina (baja visión), igual que hace memoria_visual.
  // Color fijo por tipo de figura (como en la lámina: todos los círculos de un
  // color, los triángulos de otro…). Ayuda a distinguirlas sin depender del texto.
  static const _colorForma = {
    'circulo': 'rojo',
    'triangulo': 'verde',
    'rectangulo': 'azul',
    'cuadrado': 'morado',
    'estrella': 'amarillo',
    'rombo': 'naranja',
    'corazon': 'rosa',
    'ovalo': 'gris',
  };

  Widget _figura(String id, double size) {
    // Figuras geométricas ("Toca todos los círculos"): se pintan dibujadas y con
    // su color fijo, no como texto.
    if (esFiguraGeom(id)) {
      final c = colorPorNombre(_colorForma[id.toLowerCase()] ?? '');
      return FiguraGeometrica(id, size: size, color: c);
    }
    if (IlustracionResolver.tiene(id)) {
      return Ilustracion(id, size: size, soloDibujo: _soloDibujo);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(id,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.w700,
                color: TrazoColors.ink)),
      ),
    );
  }

  Widget _celda(int idx, double lado, double imgSize) {
    final id = (_celdas[idx]['id'] ?? '').toString();
    final sel = _seleccionadas.contains(idx);
    return SizedBox(
      // key con el ID (y el idx para unicidad): el test toca por ID, no por
      // posición, porque la rejilla se baraja al pintarse.
      key: ValueKey('bcelda|$id|$idx'),
      width: lado,
      height: lado,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (sel) {
              _seleccionadas.remove(idx);
            } else {
              _seleccionadas.add(idx);
            }
          });
          _emitir();
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
            border: Border.all(
                color: sel ? TrazoColors.coralDark : TrazoColors.sand,
                width: sel ? 3 : 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _figura(id, imgSize),
              if (sel)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.check_circle,
                      color: TrazoColors.coralDark, size: 30),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
