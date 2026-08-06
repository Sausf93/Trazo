import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Vista genérica para plantillas cuyo renderer específico aún no está hecho
/// (memoria_visual, secuencia_ordenar, conteo_comparacion, arrastrar_posicion,
/// evocacion_libre, manejo_cantidad). Muestra la instrucción de forma legible y
/// permite marcar el intento como completado. A completar por tipo en fases
/// siguientes.
class GenericoWidget extends StatelessWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const GenericoWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  Widget build(BuildContext context) {
    final render = instancia.render;
    final instruccion = render['instruccion'] as String? ?? instancia.nombre;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(instancia.nombre,
                style: const TextStyle(
                    fontSize: 15, color: TrazoColors.sageDark)),
            const SizedBox(height: 10),
            Text(instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, color: TrazoColors.ink)),
            const SizedBox(height: 8),
            Text('(plantilla "${instancia.plantilla}" — vista específica pendiente)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: TrazoColors.sand)),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => onMetricas({'completado_manual': true}),
              child: const Text('Marcar hecho'),
            ),
          ],
        ),
      ),
    );
  }
}
