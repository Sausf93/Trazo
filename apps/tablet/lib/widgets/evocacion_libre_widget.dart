import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza `evocacion_libre`: respuesta HABLADA. En la tablet del usuario solo
/// se ve el enunciado, grande y claro (sin contadores que confunden). La persona
/// responde en voz alta; la validación la hace la integradora aparte.
///
/// `render.modo`:
///  - "completar": termina un refrán/frase (una respuesta).
///  - "listar": di N palabras/objetos de algo (`n_pedidas`).
class EvocacionLibreWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const EvocacionLibreWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<EvocacionLibreWidget> createState() => _EvocacionLibreWidgetState();
}

class _EvocacionLibreWidgetState extends State<EvocacionLibreWidget> {
  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    // Registra lo que se pidió (la validación de voz la marca la integradora).
    widget.onMetricas({
      'n_pedidas': (render['n_pedidas'] as num?)?.toInt() ?? 1,
      'modo': (render['modo'] ?? 'listar').toString(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final modo = (render['modo'] ?? 'listar').toString();
    final prompt = render['prompt'] is Map
        ? Map<String, dynamic>.from(render['prompt'] as Map)
        : {'texto': (render['prompt'] ?? '').toString()};
    final textoPrompt = (prompt['texto'] ?? '').toString();
    final n = (render['n_pedidas'] as num?)?.toInt() ?? 1;

    // Instrucción clara según el tipo.
    final instruccion = modo == 'completar'
        ? 'Termina la frase en voz alta'
        : 'Di en voz alta';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, color: TrazoColors.sageDark)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              decoration: BoxDecoration(
                color: TrazoColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: TrazoColors.sand, width: 1.5),
              ),
              child: Text(textoPrompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.ink)),
            ),
            // En modo "listar" (di N cosas), recordamos cuántas se piden.
            if (modo != 'completar') ...[
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: TrazoColors.coralDark,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('Di $n',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
            const SizedBox(height: 18),
            const Icon(Icons.volume_up_rounded,
                size: 40, color: TrazoColors.sand),
          ],
        ),
      ),
    );
  }
}
