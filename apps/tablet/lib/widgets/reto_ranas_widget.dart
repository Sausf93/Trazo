import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Reto interactivo de LAS RANAS QUE SALTAN. En una fila de piedras hay ranas
/// verdes a la izquierda (avanzan hacia la derecha) y marrones a la derecha
/// (avanzan hacia la izquierda), con UNA piedra vacía en medio. Una rana puede
/// avanzar a la piedra de al lado si está vacía, o SALTAR por encima de otra
/// rana si la de más allá está vacía. Objetivo: intercambiar los dos grupos.
///
/// Se juega tocando la rana que se quiere mover (si tiene un movimiento legal,
/// salta). Autoevaluable: gana cuando los grupos quedan intercambiados.
class RetoRanas {
  final String titulo;
  final String enunciado;
  final int porLado; // ranas de cada color
  const RetoRanas(
      {required this.titulo, required this.enunciado, this.porLado = 3});

  factory RetoRanas.desdeRender(Map<String, dynamic> r) => RetoRanas(
        titulo: (r['titulo'] ?? '').toString(),
        enunciado: (r['enunciado'] ?? '').toString(),
        porLado: (r['por_lado'] as num? ?? 3).toInt(),
      );
}

class RetoRanasWidget extends StatefulWidget {
  final RetoRanas reto;
  final ValueChanged<Map<String, dynamic>>? onMetricas;
  const RetoRanasWidget({super.key, required this.reto, this.onMetricas});

  @override
  State<RetoRanasWidget> createState() => _RetoRanasWidgetState();
}

class _RetoRanasWidgetState extends State<RetoRanasWidget> {
  // 'A' = verde (avanza +1), 'B' = marrón (avanza -1), null = vacía.
  late List<String?> _p;
  late List<String?> _objetivo;
  int _movimientos = 0;
  bool _celebrado = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final n = widget.reto.porLado;
    setState(() {
      _p = [
        for (var i = 0; i < n; i++) 'A',
        null,
        for (var i = 0; i < n; i++) 'B',
      ];
      // Objetivo: intercambiadas (B a la izquierda, A a la derecha).
      _objetivo = [
        for (var i = 0; i < n; i++) 'B',
        null,
        for (var i = 0; i < n; i++) 'A',
      ];
      _movimientos = 0;
      _celebrado = false;
    });
  }

  bool get _ganado {
    for (var i = 0; i < _p.length; i++) {
      if (_p[i] != _objetivo[i]) return false;
    }
    return true;
  }

  int? _destino(int i) {
    final f = _p[i];
    if (f == null) return null;
    final dir = f == 'A' ? 1 : -1;
    final paso = i + dir;
    if (paso >= 0 && paso < _p.length && _p[paso] == null) return paso;
    final salto = i + 2 * dir;
    if (salto >= 0 &&
        salto < _p.length &&
        _p[salto] == null &&
        _p[paso] != null) {
      return salto;
    }
    return null;
  }

  void _tocar(int i) {
    final d = _destino(i);
    if (d == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _p[d] = _p[i];
      _p[i] = null;
      _movimientos++;
      if (_ganado && !_celebrado) {
        _celebrado = true;
        HapticFeedback.mediumImpact();
        widget.onMetricas
            ?.call({'resuelto': true, 'movimientos': _movimientos});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reto.porLado < 1) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Este reto no se puede mostrar.',
              style: TextStyle(fontSize: 18, color: TrazoColors.ink)),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(widget.reto.enunciado,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 19, color: TrazoColors.ink, height: 1.25)),
        ),
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (context, cons) {
              final n = _p.length;
              final tam =
                  ((cons.maxWidth - 24) / n).clamp(44.0, 92.0).toDouble();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < n; i++) _piedra(i, tam),
                  ],
                ),
              );
            }),
          ),
        ),
        if (_ganado)
          _banner(TrazoColors.sageDark, Icons.check_circle,
              '¡Lo habéis conseguido!  ($_movimientos movimientos)'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Movimientos: $_movimientos',
                  style: const TextStyle(
                      fontSize: 15, color: TrazoColors.bordeControl)),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Empezar de nuevo'),
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
    );
  }

  Widget _piedra(int i, double tam) {
    final f = _p[i];
    final movible = _destino(i) != null;
    final color = f == 'A'
        ? const Color(0xFF5FA85B)
        : f == 'B'
            ? const Color(0xFFB07A46)
            : TrazoColors.sand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _tocar(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              child: movible
                  ? const Icon(Icons.arrow_drop_up,
                      color: TrazoColors.coralDark, size: 22)
                  : null,
            ),
            Container(
              width: tam,
              height: tam,
              decoration: BoxDecoration(
                color: f == null ? TrazoColors.sand.withValues(alpha: 0.5) : color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: movible
                        ? TrazoColors.coralDark
                        : const Color(0xFF9C8B6A),
                    width: movible ? 3 : 1.5),
              ),
              alignment: Alignment.center,
              child: f == null
                  ? null
                  : Text('🐸', style: TextStyle(fontSize: tam * 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(Color c, IconData ic, String txt) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: TrazoColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c, width: 2.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic, color: c, size: 26),
            const SizedBox(width: 10),
            Text(txt,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
      );
}
