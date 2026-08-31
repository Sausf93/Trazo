import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Reto interactivo de LA TORRE DE HANOI. Tres palos y una torre de discos de
/// distinto tamaño. Se mueve un disco cada vez, y NUNCA un disco grande encima
/// de uno más pequeño. Objetivo: pasar toda la torre al último palo.
///
/// Se juega tocando: tocas un palo para coger su disco de arriba y tocas otro
/// palo para dejarlo (si se puede). Autoevaluable: gana al montar la torre en
/// el último palo.
class RetoHanoi {
  final String titulo;
  final String enunciado;
  final int discos;
  const RetoHanoi(
      {required this.titulo, required this.enunciado, this.discos = 3});

  factory RetoHanoi.desdeRender(Map<String, dynamic> r) => RetoHanoi(
        titulo: (r['titulo'] ?? '').toString(),
        enunciado: (r['enunciado'] ?? '').toString(),
        discos: (r['discos'] as num? ?? 3).toInt(),
      );
}

class RetoHanoiWidget extends StatefulWidget {
  final RetoHanoi reto;
  final ValueChanged<Map<String, dynamic>>? onMetricas;
  const RetoHanoiWidget({super.key, required this.reto, this.onMetricas});

  @override
  State<RetoHanoiWidget> createState() => _RetoHanoiWidgetState();
}

class _RetoHanoiWidgetState extends State<RetoHanoiWidget> {
  late List<List<int>> _palos; // 3 palos; cada uno discos de abajo a arriba
  int? _sel; // palo con disco "cogido"
  int _movimientos = 0;
  bool _celebrado = false;

  static const _colores = [
    Color(0xFFC4553A),
    Color(0xFFE0913A),
    Color(0xFF3E97C9),
    Color(0xFF5FA85B),
    Color(0xFF8A6BB0),
    Color(0xFF1F7A70),
  ];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final n = widget.reto.discos;
    setState(() {
      _palos = [
        [for (var d = n; d >= 1; d--) d],
        <int>[],
        <int>[],
      ];
      _sel = null;
      _movimientos = 0;
      _celebrado = false;
    });
  }

  bool get _ganado => _palos[2].length == widget.reto.discos;

  void _tocar(int palo) {
    if (_sel == null) {
      if (_palos[palo].isEmpty) return;
      setState(() => _sel = palo);
      return;
    }
    if (_sel == palo) {
      setState(() => _sel = null);
      return;
    }
    final origen = _palos[_sel!];
    final destino = _palos[palo];
    if (origen.isEmpty) {
      setState(() => _sel = null);
      return;
    }
    final disco = origen.last;
    if (destino.isEmpty || destino.last > disco) {
      HapticFeedback.selectionClick();
      setState(() {
        origen.removeLast();
        destino.add(disco);
        _sel = null;
        _movimientos++;
        if (_ganado && !_celebrado) {
          _celebrado = true;
          HapticFeedback.mediumImpact();
          widget.onMetricas
              ?.call({'resuelto': true, 'movimientos': _movimientos});
        }
      });
    } else {
      // movimiento ilegal: no dejar disco grande sobre pequeño
      HapticFeedback.heavyImpact();
      setState(() => _sel = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.reto.discos;
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
          child: LayoutBuilder(builder: (context, cons) {
            final anchoPalo = cons.maxWidth / 3;
            final discoMax = (anchoPalo * 0.86).clamp(90.0, 220.0).toDouble();
            final altoDisco =
                ((cons.maxHeight - 40) / (n + 1)).clamp(20.0, 40.0).toDouble();
            return Row(
              children: [
                for (var p = 0; p < 3; p++)
                  Expanded(
                    child: _palo(p, discoMax, altoDisco, n),
                  ),
              ],
            );
          }),
        ),
        if (_ganado)
          _banner('¡Lo habéis conseguido!  ($_movimientos movimientos)'),
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

  Widget _palo(int p, double discoMax, double altoDisco, int n) {
    final seleccionado = _sel == p;
    final discos = _palos[p];
    return GestureDetector(
      onTap: () => _tocar(p),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: seleccionado
              ? TrazoColors.card
              : TrazoColors.ivory,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: seleccionado
                  ? TrazoColors.coralDark
                  : TrazoColors.sand,
              width: seleccionado ? 3 : 1.5),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Palo vertical
            Container(
              width: 10,
              margin: EdgeInsets.only(bottom: 10, top: altoDisco),
              decoration: BoxDecoration(
                color: const Color(0xFF9C8B6A),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // Base
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C8B6A),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Discos apilados
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var idx = discos.length - 1; idx >= 0; idx--)
                    _disco(discos[idx], n, discoMax, altoDisco,
                        idx == discos.length - 1 && seleccionado),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disco(int size, int n, double discoMax, double alto, bool arriba) {
    final ancho = discoMax * (0.32 + 0.68 * (size / n));
    return Container(
      width: ancho,
      height: alto,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: _colores[(size - 1) % _colores.length],
        borderRadius: BorderRadius.circular(alto / 2),
        border: arriba
            ? Border.all(color: TrazoColors.ink, width: 2.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text('$size',
          style: TextStyle(
              color: TrazoColors.white,
              fontWeight: FontWeight.w800,
              fontSize: alto * 0.5)),
    );
  }

  Widget _banner(String txt) => Container(
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
            Text(txt,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TrazoColors.sageDark)),
          ],
        ),
      );
}
