import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza `secuencia_ordenar`: la persona reordena los pasos ARRASTRANDO la
/// fila entera a su sitio (objetivo de arrastre grande, no una pieza pequeña).
/// No hay solución en el render → registra {orden_final:[textos], movimientos}.
class SecuenciaOrdenarWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const SecuenciaOrdenarWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<SecuenciaOrdenarWidget> createState() =>
      _SecuenciaOrdenarWidgetState();
}

class _SecuenciaOrdenarWidgetState extends State<SecuenciaOrdenarWidget> {
  late List<String> _pasos;
  int _movimientos = 0;
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    final barajados = (render['pasos_barajados'] as List? ?? []);
    _pasos = barajados
        .map((e) => (Map<String, dynamic>.from(e as Map)['paso'] ?? '')
            .toString())
        .toList();
  }

  void _emitir() {
    widget.onMetricas({
      'orden_final': List<String>.from(_pasos),
      'movimientos': _movimientos,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  void _reordenar(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pasos.removeAt(oldIndex);
      _pasos.insert(newIndex, item);
      _movimientos++;
    });
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion =
        render['instruccion'] as String? ?? 'Ordena los pasos';
    final titulo = render['titulo'] as String?;

    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        if (titulo != null && titulo.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, color: TrazoColors.sageDark)),
        ],
        const SizedBox(height: 6),
        const Text('Arrastra cada paso a su sitio',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: TrazoColors.sageDark)),
        const SizedBox(height: 16),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _pasos.length,
            onReorder: _reordenar,
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
            itemBuilder: (context, i) {
              // La FILA ENTERA es el asa de arrastre (objetivo grande, fácil
              // para manos que tiemblan). El número refleja la posición actual.
              return ReorderableDragStartListener(
                key: ValueKey(_pasos[i]),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: TrazoColors.card,
                      border: Border.all(color: TrazoColors.sand, width: 1.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: TrazoColors.sage,
                          foregroundColor: Colors.white,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(_pasos[i],
                              style: const TextStyle(
                                  fontSize: 22, color: TrazoColors.ink)),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.drag_indicator,
                            color: TrazoColors.sageDark, size: 34),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
