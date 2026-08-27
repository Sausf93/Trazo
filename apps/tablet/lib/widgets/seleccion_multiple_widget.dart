import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    // Cast tolerante: una instancia malformada del backend no debe tumbar la
    // tablet en pleno kiosco (mejor sin opciones que un crash).
    final opciones = (render['opciones'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final instruccion = render['instruccion'] as String?;
    final enunciado = render['enunciado'] as String? ??
        render['instruccion'] as String? ??
        'Elige la correcta';
    // Si vienen AMBOS y difieren (p. ej. series: instruccion='¿Qué sigue?' y
    // enunciado='rojo, azul, rojo…'), se pinta la consigna encima; si no, la
    // serie quedaba en pantalla sin ninguna pregunta que dijera qué hacer.
    final mostrarConsigna = instruccion != null &&
        instruccion.isNotEmpty &&
        instruccion != enunciado;
    final imagen = (render['imagen'] ?? '').toString();

    final n = opciones.length;
    const gap = 14.0;
    // Se desplaza SOLO si no cabe (minHeight = alto disponible). Así en pantallas
    // altas se centra y llena, y en tablets bajas (1024x600) con 5 opciones no
    // desborda ni corta la última opción: aparece scroll de rescate. El enunciado
    // NUNCA se trunca (las adivinanzas perderían la pista y medirían injusto).
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              if (mostrarConsigna) ...[
                Text(instruccion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: TrazoColors.sageDark)),
                const SizedBox(height: 8),
              ],
              Text(enunciado,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.ink)),
              if (imagen.isNotEmpty && IlustracionResolver.tiene(imagen)) ...[
                const SizedBox(height: 12),
                Ilustracion(imagen, size: 110),
              ],
              const SizedBox(height: 18),
              // Opciones a un tamaño táctil cómodo y estable (no gigantes).
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                _opcion(opciones[i], 66),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  Widget _opcion(String op, double alto) {
    final sel = op == _elegida;
    // Texto grande; si la opción es larga (un refrán, una definición), algo menor.
    final fontSize = op.length > 42
        ? 19.0
        : op.length > 22
            ? 22.0
            : 30.0;
    return Semantics(
      button: true,
      selected: sel,
      label: op,
      child: ConstrainedBox(
        // Altura ADAPTABLE: mínimo cómodo pero CRECE si el texto es largo, para
        // que un refrán o una definición se lea ENTERO (antes se cortaba con "…").
        constraints: BoxConstraints(minHeight: alto),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _elegida = op);
                widget.onMetricas({
                  'eleccion': op,
                  'tiempo_ms':
                      DateTime.now().difference(_inicio).inMilliseconds,
                });
              },
              child: Container(
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      // Se muestra ENTERA (hasta 5 líneas envueltas): un refrán o
                      // una definición larga ya no se corta con "…".
                      child: Text(op,
                          textAlign: TextAlign.center,
                          maxLines: 5,
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
      ),
    );
  }
}
