import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Renderiza `evocacion_libre`: respuesta abierta (hablada/escrita) que valida
/// la integradora. Muestra el prompt y cuántas se piden, con un contador +/-
/// para marcar cuántas válidas ha dicho la persona.
/// Registra {n_pedidas, n_validas}.
class EvocacionLibreWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const EvocacionLibreWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<EvocacionLibreWidget> createState() => _EvocacionLibreWidgetState();
}

class _EvocacionLibreWidgetState extends State<EvocacionLibreWidget> {
  int _nValidas = 0;
  final DateTime _inicio = DateTime.now();

  int get _nPedidas =>
      (widget.instancia.render['n_pedidas'] as num?)?.toInt() ?? 0;

  void _emitir() {
    widget.onMetricas({
      'n_pedidas': _nPedidas,
      'n_validas': _nValidas,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  void _ajustar(int delta) {
    setState(() {
      _nValidas = (_nValidas + delta).clamp(0, 999);
    });
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion = render['instruccion'] as String? ?? 'Di o escribe:';
    final prompt = render['prompt'] is Map
        ? Map<String, dynamic>.from(render['prompt'] as Map)
        : {'texto': (render['prompt'] ?? '').toString()};
    final textoPrompt = (prompt['texto'] ?? '').toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(instruccion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, color: TrazoColors.sageDark)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TrazoColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TrazoColors.sand, width: 1.5),
              ),
              child: Text(textoPrompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.ink)),
            ),
            const SizedBox(height: 20),
            Text('Se piden $_nPedidas',
                style: const TextStyle(
                    fontSize: 20, color: TrazoColors.sageDark)),
            const SizedBox(height: 24),
            const Text('Válidas dichas',
                style: TextStyle(fontSize: 16, color: TrazoColors.sand)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _botonAjuste(Icons.remove, () => _ajustar(-1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text('$_nValidas',
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: TrazoColors.coralDark)),
                ),
                _botonAjuste(Icons.add, () => _ajustar(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonAjuste(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 80,
      height: 80,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: TrazoColors.sage,
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 40, color: Colors.white),
      ),
    );
  }
}
