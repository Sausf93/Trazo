import 'dart:async';

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
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _restante--;
        if (_restante <= 0) {
          _memorizando = false;
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
            color: TrazoColors.coralDark,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text('$_restante',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        const SizedBox(height: 20),
        Expanded(child: _rejillaTarjetas(_aRecordar, seleccionable: false)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _terminarMemorizacion,
          child: const Text('Ya lo recuerdo'),
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
    // Columnas adaptativas: cuantas más figuras (nivel alto), más columnas, para
    // que quepan sin una barra de scroll fea. El scroll (si hace falta) es limpio.
    final n = items.length;
    final columnas = n <= 6 ? 3 : (n <= 12 ? 4 : 5);
    final imgSize = columnas >= 5 ? 44.0 : (columnas == 4 ? 54.0 : 62.0);
    return ScrollConfiguration(
      behavior: const _SinBarraScroll(),
      child: GridView.count(
        crossAxisCount: columnas,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: items.map((it) {
          final id = _idDe(it);
          final sel = _seleccionadas.contains(id);
          final tieneDibujo = IlustracionResolver.tiene(id);
        return InkWell(
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
          borderRadius: BorderRadius.circular(14),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
              border: Border.all(
                  color: sel ? TrazoColors.coral : TrazoColors.sand,
                  width: sel ? 3 : 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tieneDibujo) ...[
                      Ilustracion(id, size: imgSize),
                      const SizedBox(height: 4),
                    ],
                    Flexible(
                      child: Text(_labelDe(it),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: tieneDibujo ? 16 : 22,
                              color: TrazoColors.ink)),
                    ),
                  ],
                ),
                if (seleccionable && sel)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.check_circle,
                        color: TrazoColors.coralDark, size: 28),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      ),
    );
  }
}

/// Comportamiento de scroll SIN barra visible: el scroll (cuando hace falta por
/// muchas figuras en nivel alto) se hace arrastrando, sin la barra fea de Material.
class _SinBarraScroll extends ScrollBehavior {
  const _SinBarraScroll();
  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
