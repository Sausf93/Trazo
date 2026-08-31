import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Reto interactivo del TAQUÍN (puzzle deslizante). Una cuadrícula con fichas
/// numeradas y un hueco; se toca una ficha de al lado del hueco para deslizarla.
/// Objetivo: dejar los números en orden. Juego de grupo, autoevaluado en la
/// tablet. La mezcla siempre es RESOLUBLE (se parte del orden y se dan N
/// movimientos legales al azar).
class RetoTaquin {
  final String titulo;
  final String enunciado;
  final int lado; // 3 = 8 fichas (3x3)
  const RetoTaquin(
      {required this.titulo, required this.enunciado, this.lado = 3});

  factory RetoTaquin.desdeRender(Map<String, dynamic> r) => RetoTaquin(
        titulo: (r['titulo'] ?? '').toString(),
        enunciado: (r['enunciado'] ?? '').toString(),
        lado: (r['lado'] as num? ?? 3).toInt(),
      );
}

class RetoTaquinWidget extends StatefulWidget {
  final RetoTaquin reto;
  final ValueChanged<Map<String, dynamic>>? onMetricas;
  const RetoTaquinWidget({super.key, required this.reto, this.onMetricas});

  @override
  State<RetoTaquinWidget> createState() => _RetoTaquinWidgetState();
}

class _RetoTaquinWidgetState extends State<RetoTaquinWidget> {
  late List<int> _f; // valores; 0 = hueco. Índice = posición en la cuadrícula.
  late int _n; // lado
  int _movimientos = 0;
  bool _celebrado = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _n = widget.reto.lado.clamp(3, 4);
    final total = _n * _n;
    _f = [for (var i = 1; i < total; i++) i, 0]; // resuelto: 1..n², hueco al final
    // Mezcla resoluble: N movimientos legales al azar desde el estado resuelto.
    for (var k = 0; k < 120; k++) {
      final vecinos = _vecinosDelHueco();
      final elegido = vecinos[_rng.nextInt(vecinos.length)];
      _deslizar(elegido, contar: false);
    }
    _movimientos = 0;
    _celebrado = false;
    if (mounted) setState(() {});
  }

  int get _hueco => _f.indexOf(0);

  List<int> _vecinosDelHueco() {
    final h = _hueco;
    final fila = h ~/ _n, col = h % _n;
    final v = <int>[];
    if (fila > 0) v.add(h - _n);
    if (fila < _n - 1) v.add(h + _n);
    if (col > 0) v.add(h - 1);
    if (col < _n - 1) v.add(h + 1);
    return v;
  }

  bool get _resuelto {
    for (var i = 0; i < _f.length - 1; i++) {
      if (_f[i] != i + 1) return false;
    }
    return _f.last == 0;
  }

  void _deslizar(int pos, {bool contar = true}) {
    if (!_vecinosDelHueco().contains(pos)) return;
    final h = _hueco;
    _f[h] = _f[pos];
    _f[pos] = 0;
    if (contar) {
      HapticFeedback.selectionClick();
      _movimientos++;
      if (_resuelto && !_celebrado) {
        _celebrado = true;
        HapticFeedback.mediumImpact();
        widget.onMetricas
            ?.call({'resuelto': true, 'movimientos': _movimientos});
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, outer) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: outer.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(widget.reto.enunciado,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 19, color: TrazoColors.ink, height: 1.25)),
        ),
        SizedBox(
          height: 340,
          child: Center(
            child: LayoutBuilder(builder: (context, cons) {
              final lado = min(cons.maxWidth, cons.maxHeight) - 16;
              final celda = lado / _n;
              return SizedBox(
                width: celda * _n,
                height: celda * _n,
                child: Stack(
                  children: [
                    for (var i = 0; i < _f.length; i++)
                      if (_f[i] != 0) _ficha(i, celda),
                  ],
                ),
              );
            }),
          ),
        ),
        if (_resuelto)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: TrazoColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TrazoColors.sageDark, width: 2.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: TrazoColors.sageDark, size: 26),
                const SizedBox(width: 10),
                Text('¡Lo habéis conseguido!  ($_movimientos movimientos)',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: TrazoColors.sageDark)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Movimientos: $_movimientos',
                  style: const TextStyle(
                      fontSize: 15, color: TrazoColors.bordeControl)),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.shuffle),
                label: const Text('Mezclar de nuevo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TrazoColors.sageDark,
                  side: const BorderSide(
                      color: TrazoColors.bordeControl, width: 1.6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
          ),
        ),
      );
    });
  }

  Widget _ficha(int pos, double celda) {
    final v = _f[pos];
    final fila = pos ~/ _n, col = pos % _n;
    final movible = _vecinosDelHueco().contains(pos);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 130),
      left: col * celda,
      top: fila * celda,
      width: celda,
      height: celda,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          onTap: () => _deslizar(pos),
          child: Container(
            decoration: BoxDecoration(
              color: movible ? TrazoColors.sageDark : TrazoColors.sage,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: movible ? TrazoColors.coralDark : TrazoColors.sageDark,
                  width: movible ? 3 : 1),
            ),
            alignment: Alignment.center,
            child: Text('$v',
                style: TextStyle(
                    color: TrazoColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: celda * 0.4)),
          ),
        ),
      ),
    );
  }
}
