import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `seleccion_multiple`: enunciado (+ imagen si la hay) y opciones
/// GRANDES apiladas a lo ancho, con texto grande y legible, que caben sin scroll.
/// Registra la elección; la corrección la resuelve el motor / la integradora.
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
    final imagen = (render['imagen'] ?? '').toString();

    return Column(
      children: [
        Text(enunciado,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: TrazoColors.ink)),
        // Si la actividad muestra una imagen (p. ej. "¿qué animal es?"), grande.
        if (imagen.isNotEmpty && IlustracionResolver.tiene(imagen)) ...[
          const SizedBox(height: 12),
          Ilustracion(imagen, size: 110),
        ],
        const SizedBox(height: 18),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final n = opciones.length;
              const gap = 14.0;
              // Cada opción ocupa a lo ancho; alto repartido pero acotado para
              // que no salgan cuadros gigantes.
              final alto =
                  ((c.maxHeight - gap * (n - 1)) / n).clamp(60.0, 128.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < n; i++) ...[
                    if (i > 0) const SizedBox(height: gap),
                    _opcion(opciones[i], alto),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _opcion(String op, double alto) {
    final sel = op == _elegida;
    // Texto grande; si la opción es larga, algo menor para que quepa.
    final fontSize = op.length > 22 ? 22.0 : 30.0;
    return Semantics(
      button: true,
      selected: sel,
      label: op,
      child: SizedBox(
        height: alto,
        width: double.infinity,
        child: Material(
          color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _elegida = op);
              widget.onMetricas({
                'eleccion': op,
                'tiempo_ms':
                    DateTime.now().difference(_inicio).inMilliseconds,
              });
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: sel ? TrazoColors.coralDark : TrazoColors.sand,
                    width: sel ? 3 : 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sel) ...[
                    const Icon(Icons.check_circle,
                        color: TrazoColors.coralDark, size: 30),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(op,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: TrazoColors.ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
