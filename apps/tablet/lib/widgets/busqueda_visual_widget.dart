import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
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
  final Set<int> _seleccionadas = {};
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _celdas = ((render['celdas'] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final obj = render['objetivo'] is Map
        ? Map<String, dynamic>.from(render['objetivo'] as Map)
        : {'id': (render['objetivo'] ?? '').toString()};
    _objetivoId = (obj['id'] ?? '').toString();
    _totalObjetivos =
        _celdas.where((c) => (c['id'] ?? '').toString() == _objetivoId).length;
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
    return Column(
      children: [
        // Objetivo: qué hay que buscar, grande y claro.
        Container(
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
              Text(instruccion,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.ink)),
              const SizedBox(width: 14),
              Ilustracion(_objetivoId, size: 52),
            ],
          ),
        ),
        Expanded(child: _rejilla()),
      ],
    );
  }

  Widget _rejilla() {
    final n = _celdas.length;
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = n <= 6 ? 3 : (n <= 12 ? 4 : 5);
        final filas = (n / columnas).ceil();
        const gap = 14.0;
        final anchoCelda = (c.maxWidth - gap * (columnas - 1)) / columnas;
        final altoCelda = (c.maxHeight - gap * (filas - 1)) / filas;
        final lado = min(min(anchoCelda, altoCelda), 200.0);
        final imgSize = (lado * 0.66).clamp(56.0, 150.0);

        final filasWidgets = <Widget>[];
        for (var f = 0; f < filas; f++) {
          final celdas = <Widget>[];
          for (var col = 0; col < columnas; col++) {
            final idx = f * columnas + col;
            if (col > 0) celdas.add(const SizedBox(width: gap));
            celdas.add(idx >= n
                ? SizedBox(width: lado)
                : _celda(idx, lado, imgSize));
          }
          if (f > 0) filasWidgets.add(const SizedBox(height: gap));
          filasWidgets.add(Row(
              mainAxisAlignment: MainAxisAlignment.center, children: celdas));
        }
        return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: filasWidgets),
        );
      },
    );
  }

  Widget _celda(int idx, double lado, double imgSize) {
    final id = (_celdas[idx]['id'] ?? '').toString();
    final sel = _seleccionadas.contains(idx);
    return SizedBox(
      width: lado,
      height: lado,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
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
          padding: const EdgeInsets.all(8),
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
              Ilustracion(id, size: imgSize),
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
