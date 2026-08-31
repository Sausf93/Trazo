import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Reto interactivo tipo MASTERMIND: adivinar una secuencia oculta de colores.
/// Se elige una fila de colores y se pulsa COMPROBAR; la app dice cuántos están
/// en su sitio y cuántos son del color correcto pero en otro sitio. Con esas
/// pistas se va afinando. Pensado para mayores: círculos grandes, pistas en
/// palabras además de fichas, y sin prisa. La dificultad = nº de colores
/// (3 fácil, 4 medio, 5 difícil, 6 muy difícil).
class RetoMastermind {
  final String titulo;
  final String enunciado;
  final int colores; // 3..6
  final int longitud; // fichas por fila (4)
  const RetoMastermind(
      {required this.titulo,
      required this.enunciado,
      this.colores = 4,
      this.longitud = 4});

  factory RetoMastermind.desdeRender(Map<String, dynamic> r) => RetoMastermind(
        titulo: (r['titulo'] ?? '').toString(),
        enunciado: (r['enunciado'] ?? '').toString(),
        colores: (r['colores'] as num? ?? 4).toInt(),
        longitud: (r['longitud'] as num? ?? 4).toInt(),
      );
}

class RetoMastermindWidget extends StatefulWidget {
  final RetoMastermind reto;
  final ValueChanged<Map<String, dynamic>>? onMetricas;
  const RetoMastermindWidget({super.key, required this.reto, this.onMetricas});

  @override
  State<RetoMastermindWidget> createState() => _RetoMastermindWidgetState();
}

class _RetoMastermindWidgetState extends State<RetoMastermindWidget> {
  // Paleta (hasta 6). Colores muy distintos y de alto contraste para baja visión.
  static const _paleta = <Color>[
    Color(0xFFD64545), // rojo
    Color(0xFF3E7CC4), // azul
    Color(0xFFF2C14E), // amarillo
    Color(0xFF4FA65B), // verde
    Color(0xFFE08A3C), // naranja
    Color(0xFF8A5CC0), // morado
  ];
  late int _nc; // nº colores
  late int _len;
  late List<int> _secreto;
  final List<List<int>> _intentos = []; // filas ya comprobadas
  final List<List<int>> _pistas = []; // [negras, blancas] por intento
  late List<int?> _actual; // fila en construcción
  bool _ganado = false;
  bool _celebrado = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _nc = widget.reto.colores.clamp(3, 6);
    _len = widget.reto.longitud.clamp(3, 5);
    setState(() {
      _secreto = [for (var i = 0; i < _len; i++) _rng.nextInt(_nc)];
      _intentos.clear();
      _pistas.clear();
      _actual = List<int?>.filled(_len, null);
      _ganado = false;
      _celebrado = false;
    });
  }

  void _ponerColor(int color) {
    if (_ganado) return;
    final hueco = _actual.indexWhere((c) => c == null);
    if (hueco < 0) return;
    HapticFeedback.selectionClick();
    setState(() => _actual[hueco] = color);
  }

  void _quitar(int pos) {
    if (_ganado) return;
    setState(() => _actual[pos] = null);
  }

  bool get _filaCompleta => !_actual.contains(null);

  void _comprobar() {
    if (!_filaCompleta || _ganado) return;
    final intento = _actual.map((c) => c!).toList();
    // Negras: color y sitio correctos.
    var negras = 0;
    final restoSec = <int>[], restoInt = <int>[];
    for (var i = 0; i < _len; i++) {
      if (intento[i] == _secreto[i]) {
        negras++;
      } else {
        restoSec.add(_secreto[i]);
        restoInt.add(intento[i]);
      }
    }
    // Blancas: color correcto en otro sitio.
    var blancas = 0;
    final disp = List<int>.from(restoSec);
    for (final c in restoInt) {
      final k = disp.indexOf(c);
      if (k >= 0) {
        blancas++;
        disp.removeAt(k);
      }
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _intentos.add(intento);
      _pistas.add([negras, blancas]);
      _actual = List<int?>.filled(_len, null);
      if (negras == _len) {
        _ganado = true;
        if (!_celebrado) {
          _celebrado = true;
          widget.onMetricas
              ?.call({'resuelto': true, 'movimientos': _intentos.length});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(widget.reto.enunciado,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 19, color: TrazoColors.ink, height: 1.25)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
              'Adivinad el orden de $_len colores. Tras cada intento os digo cuántos acertáis.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, color: TrazoColors.bordeControl)),
        ),
        // Historial de intentos + fila actual
        Expanded(
          child: SingleChildScrollView(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (var i = 0; i < _intentos.length; i++)
                  _filaIntento(_intentos[i], _pistas[i]),
                if (!_ganado) _filaActual(),
              ],
            ),
          ),
        ),
        if (_ganado)
          _banner(
              '¡Lo habéis adivinado!  (${_intentos.length} intentos)', true),
        // Paleta de colores
        if (!_ganado)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var c = 0; c < _nc; c++)
                  GestureDetector(
                    onTap: () => _ponerColor(c),
                    child: _circulo(c, 46, true),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Otra secuencia'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TrazoColors.sageDark,
                  side: const BorderSide(
                      color: TrazoColors.bordeControl, width: 1.6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              if (!_ganado)
                ElevatedButton.icon(
                  onPressed: _filaCompleta ? _comprobar : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Comprobar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrazoColors.sageDark,
                    foregroundColor: TrazoColors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circulo(int color, double d, bool relleno) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: relleno ? _paleta[color] : TrazoColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: TrazoColors.ink.withValues(alpha: 0.25), width: 1.5),
      ),
    );
  }

  Widget _huecoActual(int pos) {
    final c = _actual[pos];
    return GestureDetector(
      onTap: c == null ? null : () => _quitar(pos),
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: c == null ? TrazoColors.white : _paleta[c],
          shape: BoxShape.circle,
          border: Border.all(
              color: c == null ? TrazoColors.bordeControl : TrazoColors.ink,
              width: c == null ? 2 : 1.5),
        ),
        child: c == null
            ? const Icon(Icons.add, color: TrazoColors.bordeControl, size: 22)
            : null,
      ),
    );
  }

  Widget _filaActual() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: TrazoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TrazoColors.sageDark, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (var i = 0; i < _len; i++) _huecoActual(i)],
      ),
    );
  }

  Widget _filaIntento(List<int> intento, List<int> pistas) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in intento)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _circulo(c, 40, true),
            ),
          const SizedBox(width: 14),
          // Pista en PALABRAS (clara para el mayor) + fichas.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TrazoColors.ivory,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TrazoColors.sand),
            ),
            child: Text(
              '${pistas[0]} en su sitio · ${pistas[1]} de color',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String txt, bool ok) => Container(
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
