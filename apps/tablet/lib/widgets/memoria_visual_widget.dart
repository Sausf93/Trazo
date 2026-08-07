import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `memoria_visual`: muestra `a_recordar` durante `segundos_memorizar`
/// (con cuenta atrás), las oculta y presenta `rejilla_seleccion` para que la
/// persona toque las que cree recordar. Puntúa en cliente comparando con los
/// ids de `a_recordar` (que sí vienen en el render).
class MemoriaVisualWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const MemoriaVisualWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<MemoriaVisualWidget> createState() => _MemoriaVisualWidgetState();
}

class _MemoriaVisualWidgetState extends State<MemoriaVisualWidget> {
  late final List<Map<String, dynamic>> _aRecordar;
  late final List<Map<String, dynamic>> _rejilla;
  late final Set<String> _idsCorrectos;

  bool _memorizando = true;
  int _restante = 0;
  Timer? _timer;
  final Set<String> _seleccionadas = {};
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _aRecordar = _comoLista(render['a_recordar']);
    _rejilla = _comoLista(render['rejilla_seleccion']);
    _idsCorrectos = _aRecordar.map((e) => _idDe(e)).toSet();
    _restante =
        (render['segundos_memorizar'] as num?)?.toInt() ?? 10;
    // La cuenta atrás es solo ORIENTATIVA: al llegar a 0 no se ocultan las
    // figuras (no penalizamos la lentitud, apunte de Laura). Solo avanza la
    // persona pulsando "Ya lo recuerdo".
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_restante > 0) {
          _restante--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _comoLista(dynamic v) => (v as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  String _idDe(Map<String, dynamic> e) =>
      (e['id'] ?? e['label'] ?? '').toString();

  String _labelDe(Map<String, dynamic> e) =>
      (e['label'] ?? e['id'] ?? '').toString();

  void _emitir() {
    int aciertos = 0;
    int fallos = 0;
    for (final id in _seleccionadas) {
      if (_idsCorrectos.contains(id)) {
        aciertos++;
      } else {
        fallos++;
      }
    }
    widget.onMetricas({
      'aciertos': aciertos,
      'fallos': fallos,
      'seleccionadas': _seleccionadas.toList(),
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  void _terminarMemorizacion() {
    _timer?.cancel();
    setState(() {
      _memorizando = false;
      _restante = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion = render['instruccion'] as String? ?? 'Memoriza';
    return _memorizando
        ? _vistaMemorizar(instruccion)
        : _vistaSeleccion();
  }

  Widget _vistaMemorizar(String instruccion) {
    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _restante > 0 ? TrazoColors.coralDark : TrazoColors.sageDark,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(_restante > 0 ? '$_restante' : 'Sin prisa',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        const SizedBox(height: 20),
        Expanded(child: _rejillaTarjetas(_aRecordar, seleccionable: false)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _terminarMemorizacion,
          style: FilledButton.styleFrom(
            backgroundColor: TrazoColors.sage,
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.check),
          label: const Text('Ya lo recuerdo'),
        ),
      ],
    );
  }

  Widget _vistaSeleccion() {
    return Column(
      children: [
        const Text('Toca las que estaban antes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 20),
        Expanded(child: _rejillaTarjetas(_rejilla, seleccionable: true)),
      ],
    );
  }

  Widget _rejillaTarjetas(List<Map<String, dynamic>> items,
      {required bool seleccionable}) {
    // Rejilla que SIEMPRE cabe en pantalla (sin scroll) con tarjetas cuadradas
    // e imágenes GRANDES: se calcula el nº de columnas/filas y el tamaño de celda
    // a partir del espacio disponible; la imagen ocupa ~62% de la celda.
    final n = items.length;
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = n <= 6 ? 3 : (n <= 12 ? 4 : 5);
        final filas = (n / columnas).ceil();
        const gap = 14.0;
        final anchoCelda = (c.maxWidth - gap * (columnas - 1)) / columnas;
        final altoCelda = (c.maxHeight - gap * (filas - 1)) / filas;
        // Celda cuadrada, acotada para que no se hagan recuadros gigantes.
        final lado = min(min(anchoCelda, altoCelda), 230.0);
        final imgSize = (lado * 0.62).clamp(56.0, 150.0);

        final filasWidgets = <Widget>[];
        for (var f = 0; f < filas; f++) {
          final celdas = <Widget>[];
          for (var col = 0; col < columnas; col++) {
            final idx = f * columnas + col;
            if (col > 0) celdas.add(const SizedBox(width: gap));
            celdas.add(idx >= n
                ? SizedBox(width: lado)
                : _celdaMemoria(items[idx], lado, imgSize, seleccionable));
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

  Widget _celdaMemoria(Map<String, dynamic> it, double lado, double imgSize,
      bool seleccionable) {
    final id = _idDe(it);
    final sel = _seleccionadas.contains(id);
    final tieneDibujo = IlustracionResolver.tiene(id);
    return SizedBox(
      width: lado,
      height: lado,
      child: InkWell(
        onTap: seleccionable
            ? () {
                setState(() {
                  if (sel) {
                    _seleccionadas.remove(id);
                  } else {
                    _seleccionadas.add(id);
                  }
                });
                _emitir();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
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
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tieneDibujo) ...[
                    Ilustracion(id, size: imgSize),
                    const SizedBox(height: 6),
                  ],
                  Flexible(
                    child: Text(_labelDe(it),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: tieneDibujo ? 17 : 24,
                            fontWeight: FontWeight.w600,
                            color: TrazoColors.ink)),
                  ),
                ],
              ),
              if (seleccionable && sel)
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
