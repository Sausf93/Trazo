import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza `conteo_comparacion`: pinta los grupos (cada objeto como un emoji
/// repetido `cantidad` veces). Según `modo`:
///  - cual_tiene_mas: la persona toca el grupo que cree mayor.
///  - contar / sumar: introduce un número con el teclado numérico grande.
/// No se autocorrige → registra {respuesta, modo}.
class ConteoComparacionWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const ConteoComparacionWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<ConteoComparacionWidget> createState() =>
      _ConteoComparacionWidgetState();
}

class _ConteoComparacionWidgetState extends State<ConteoComparacionWidget> {
  final DateTime _inicio = DateTime.now();
  int? _grupoElegido;
  String _numero = '';

  static const Map<String, String> _emojis = {
    'pato_amarillo': '🦆',
    'pato_verde': '🦆',
    'manzana': '🍎',
    'pera': '🍐',
    'naranja': '🍊',
    'flor': '🌼',
    'estrella': '⭐',
    'coche': '🚗',
    'pelota': '⚽',
    'gato': '🐱',
    'perro': '🐶',
    'pez': '🐟',
    'corazon': '❤️',
    'circulo': '🔵',
  };

  String _emojiDe(String objeto) => _emojis[objeto] ?? '🔶';

  void _emitir(dynamic respuesta) {
    widget.onMetricas({
      'respuesta': respuesta,
      'modo': widget.instancia.render['modo'],
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion =
        render['instruccion'] as String? ?? '¿Cuál tiene más?';
    final modo = render['modo'] as String? ?? 'cual_tiene_mas';
    final grupos = (render['grupos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < grupos.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _grupoCard(i, grupos[i],
                        seleccionable: modo == 'cual_tiene_mas'),
                  ),
                ),
            ],
          ),
        ),
        if (modo != 'cual_tiene_mas') ...[
          const SizedBox(height: 16),
          _tecladoNumerico(),
        ],
      ],
    );
  }

  Widget _grupoCard(int i, Map<String, dynamic> grupo,
      {required bool seleccionable}) {
    final objeto = (grupo['objeto'] ?? '').toString();
    final cantidad = (grupo['cantidad'] as num?)?.toInt() ?? 0;
    final emoji = _emojiDe(objeto);
    final sel = _grupoElegido == i;

    return InkWell(
      onTap: seleccionable
          ? () {
              setState(() => _grupoElegido = i);
              _emitir({'grupo': i, 'objeto': objeto});
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
          border: Border.all(
              color: sel ? TrazoColors.coral : TrazoColors.sand,
              width: sel ? 3 : 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: List.generate(
                    cantidad,
                    (_) => Text(emoji,
                        style: const TextStyle(fontSize: 34)),
                  ),
                ),
              ),
            ),
            Text(objeto.replaceAll('_', ' '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: TrazoColors.sageDark)),
          ],
        ),
      ),
    );
  }

  Widget _tecladoNumerico() {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          width: 160,
          decoration: BoxDecoration(
            color: TrazoColors.white,
            border: Border.all(color: TrazoColors.sand, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_numero.isEmpty ? '—' : _numero,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: TrazoColors.ink)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
              _tecla(d, () {
                setState(() => _numero += d);
                _emitir(int.tryParse(_numero));
              }),
            _tecla('⌫', () {
              setState(() => _numero = _numero.isEmpty
                  ? ''
                  : _numero.substring(0, _numero.length - 1));
              _emitir(int.tryParse(_numero));
            }),
          ],
        ),
      ],
    );
  }

  Widget _tecla(String label, VoidCallback onTap) {
    return SizedBox(
      width: 64,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: TrazoColors.ink,
          side: const BorderSide(color: TrazoColors.sand),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
