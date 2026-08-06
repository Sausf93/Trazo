import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza una plantilla `seleccion_multiple`: enunciado + opciones grandes.
/// Registra la elección; la corrección definitiva se resuelve más adelante
/// (server-side o control de la facilitadora).
class SeleccionMultipleWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const SeleccionMultipleWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<SeleccionMultipleWidget> createState() =>
      _SeleccionMultipleWidgetState();
}

class _SeleccionMultipleWidgetState extends State<SeleccionMultipleWidget> {
  String? _elegida;
  final DateTime _inicio = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final opciones =
        (render['opciones'] as List).map((e) => e.toString()).toList();
    final enunciado = render['enunciado'] as String? ??
        render['instruccion'] as String? ??
        'Elige la correcta';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(enunciado,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.4,
            children: opciones.map((op) {
              final sel = op == _elegida;
              return InkWell(
                onTap: () {
                  setState(() => _elegida = op);
                  widget.onMetricas({
                    'eleccion': op,
                    'tiempo_ms':
                        DateTime.now().difference(_inicio).inMilliseconds,
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
                    border: Border.all(
                        color: sel ? TrazoColors.coral : TrazoColors.sand,
                        width: sel ? 2.5 : 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(op,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, color: TrazoColors.ink)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
