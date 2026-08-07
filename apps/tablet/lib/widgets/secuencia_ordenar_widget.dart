import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza `secuencia_ordenar`: la persona reordena los pasos con botones
/// grandes de subir/bajar (más accesible que arrastrar para público mayor).
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

  void _mover(int index, int delta) {
    final destino = index + delta;
    if (destino < 0 || destino >= _pasos.length) return;
    setState(() {
      final tmp = _pasos[index];
      _pasos[index] = _pasos[destino];
      _pasos[destino] = tmp;
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
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: _pasos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
                    IconButton(
                      iconSize: 40,
                      constraints: const BoxConstraints(
                          minWidth: 60, minHeight: 60),
                      padding: EdgeInsets.zero,
                      onPressed: i == 0 ? null : () => _mover(i, -1),
                      icon: const Icon(Icons.keyboard_arrow_up),
                      color: TrazoColors.sageDark,
                      tooltip: 'Subir',
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      iconSize: 40,
                      constraints: const BoxConstraints(
                          minWidth: 60, minHeight: 60),
                      padding: EdgeInsets.zero,
                      onPressed: i == _pasos.length - 1
                          ? null
                          : () => _mover(i, 1),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      color: TrazoColors.sageDark,
                      tooltip: 'Bajar',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
