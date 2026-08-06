import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../api/client.dart';
import '../sync_queue.dart';
import '../theme.dart';
import '../widgets/arrastrar_posicion_widget.dart';
import '../widgets/conteo_comparacion_widget.dart';
import '../widgets/evocacion_libre_widget.dart';
import '../widgets/generico_widget.dart';
import '../widgets/manejo_cantidad_widget.dart';
import '../widgets/memoria_visual_widget.dart';
import '../widgets/secuencia_ordenar_widget.dart';
import '../widgets/seleccion_multiple_widget.dart';
import '../widgets/trazo_widget.dart';

/// Modo participante: pantalla completa, un ejercicio, sin menús visibles.
/// La franja inferior es el CONTROL DE LA FACILITADORA (ayuda / saltar /
/// siguiente), no del usuario mayor — así se le quita la carga de decidir.
class ParticipanteScreen extends StatefulWidget {
  final UsuarioFinal usuario;
  final Ejercicio ejercicio;
  final String sesionId;

  const ParticipanteScreen({
    super.key,
    required this.usuario,
    required this.ejercicio,
    required this.sesionId,
  });

  @override
  State<ParticipanteScreen> createState() => _ParticipanteScreenState();
}

class _ParticipanteScreenState extends State<ParticipanteScreen> {
  Instancia? _instancia;
  String? _error;
  Map<String, dynamic> _valores = {};
  bool _conAyuda = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _cargarInstancia();
  }

  Future<void> _cargarInstancia() async {
    setState(() {
      _instancia = null;
      _error = null;
      _valores = {};
      _conAyuda = false;
    });
    try {
      final inst = await ApiClient.instance.generarInstancia(
        widget.ejercicio.id,
        usuarioFinalId: widget.usuario.id,
      );
      setState(() => _instancia = inst);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _registrar(String estado) async {
    final inst = _instancia;
    if (inst == null) return;
    final intento = Intento(
      id: _uuid.v4(), // UUID en cliente -> sync offline idempotente
      usuarioFinalId: widget.usuario.id,
      sesionId: widget.sesionId,
      ejercicioId: widget.ejercicio.id,
      estado: estado,
      timestampInicio: DateTime.now(),
      timestampFin: DateTime.now(),
      valores: _valores,
      cantidadObjetivo: inst.cantidadObjetivo,
    );
    await SyncQueue.enviarOEncolar(intento);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Registrado ($estado)')),
    );
  }

  Widget _renderPorPlantilla(Instancia inst) {
    void onMetricas(Map<String, dynamic> m) => _valores = {..._valores, ...m};
    switch (inst.plantilla) {
      case 'trazo':
        return TrazoWidget(instancia: inst, onMetricas: onMetricas);
      case 'seleccion_multiple':
        return SeleccionMultipleWidget(
            instancia: inst, onMetricas: onMetricas);
      case 'memoria_visual':
        return MemoriaVisualWidget(instancia: inst, onMetricas: onMetricas);
      case 'secuencia_ordenar':
        return SecuenciaOrdenarWidget(
            instancia: inst, onMetricas: onMetricas);
      case 'conteo_comparacion':
        return ConteoComparacionWidget(
            instancia: inst, onMetricas: onMetricas);
      case 'arrastrar_posicion':
        return ArrastrarPosicionWidget(
            instancia: inst, onMetricas: onMetricas);
      case 'evocacion_libre':
        return EvocacionLibreWidget(instancia: inst, onMetricas: onMetricas);
      case 'manejo_cantidad':
        return ManejoCantidadWidget(instancia: inst, onMetricas: onMetricas);
      default:
        return GenericoWidget(instancia: inst, onMetricas: onMetricas);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _error != null
                    ? Center(
                        child: Text('Error: $_error',
                            style: const TextStyle(
                                color: TrazoColors.coralDark)))
                    : _instancia == null
                        ? const Center(child: CircularProgressIndicator())
                        : _renderPorPlantilla(_instancia!),
              ),
            ),
            _FranjaFacilitadora(
              conAyuda: _conAyuda,
              onAyuda: () => setState(() => _conAyuda = !_conAyuda),
              onSaltar: () async {
                await _registrar('no_completado');
                await _cargarInstancia();
              },
              onSiguiente: () async {
                await _registrar(_conAyuda ? 'con_ayuda' : 'solo');
                await _cargarInstancia();
              },
              onSalir: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Franja de control discreta para la integradora (no para el usuario mayor).
class _FranjaFacilitadora extends StatelessWidget {
  final bool conAyuda;
  final VoidCallback onAyuda;
  final VoidCallback onSaltar;
  final VoidCallback onSiguiente;
  final VoidCallback onSalir;

  const _FranjaFacilitadora({
    required this.conAyuda,
    required this.onAyuda,
    required this.onSaltar,
    required this.onSiguiente,
    required this.onSalir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TrazoColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
              onPressed: onSalir,
              icon: const Icon(Icons.close, color: TrazoColors.sageDark),
              tooltip: 'Salir'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onAyuda,
            icon: Icon(conAyuda ? Icons.check : Icons.pan_tool_alt,
                size: 18),
            label: Text(conAyuda ? 'Ayuda ✓' : 'Ayuda'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  conAyuda ? TrazoColors.coralDark : TrazoColors.sageDark,
              side: BorderSide(
                  color: conAyuda ? TrazoColors.coral : TrazoColors.sand),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
              onPressed: onSaltar,
              child: const Text('Saltar',
                  style: TextStyle(color: TrazoColors.sageDark))),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: onSiguiente, child: const Text('Siguiente')),
        ],
      ),
    );
  }
}
