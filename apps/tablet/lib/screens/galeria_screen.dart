// Galería/DEMO de actividades: permite PROBAR cada actividad como en la tablet,
// sin login ni backend. Pensada para revisar de un vistazo qué se ve bien y qué
// no, y para enseñar el producto. Los datos salen de assets/demo_actividades.json
// (una muestra por actividad, generada con el motor real).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';
import '../theme.dart';
import '../widgets/arrastrar_posicion_widget.dart';
import '../widgets/busqueda_visual_widget.dart';
import '../widgets/conteo_comparacion_widget.dart';
import '../widgets/generico_widget.dart';
import '../widgets/manejo_cantidad_widget.dart';
import '../widgets/memoria_visual_widget.dart';
import '../widgets/secuencia_ordenar_widget.dart';
import '../widgets/seleccion_multiple_widget.dart';
import '../widgets/trazo_widget.dart';

const _kBloques = {
  'atencion_memoria': 'Atención y memoria',
  'lenguaje': 'Lenguaje',
  'gnosias': 'Gnosias (reconocer)',
  'praxias': 'Praxias (manos)',
  'razonamiento': 'Razonamiento',
  'calculo': 'Cálculo',
  'funcion_ejecutiva': 'Función ejecutiva',
  'vida_cotidiana': 'Vida cotidiana',
};

/// Construye el widget de la actividad (mismo repertorio que el kiosco real).
Widget renderActividadDemo(
    Instancia inst, ValueChanged<Map<String, dynamic>> onMetricas) {
  switch (inst.plantilla) {
    case 'trazo':
      return TrazoWidget(instancia: inst, onMetricas: onMetricas);
    case 'seleccion_multiple':
      return SeleccionMultipleWidget(instancia: inst, onMetricas: onMetricas);
    case 'memoria_visual':
      return MemoriaVisualWidget(
          instancia: inst, onMetricas: onMetricas, onListoParaAvanzar: (_) {});
    case 'secuencia_ordenar':
      return SecuenciaOrdenarWidget(instancia: inst, onMetricas: onMetricas);
    case 'conteo_comparacion':
      return ConteoComparacionWidget(instancia: inst, onMetricas: onMetricas);
    case 'arrastrar_posicion':
      return ArrastrarPosicionWidget(instancia: inst, onMetricas: onMetricas);
    case 'manejo_cantidad':
      return ManejoCantidadWidget(instancia: inst, onMetricas: onMetricas);
    case 'busqueda_visual':
      return BusquedaVisualWidget(instancia: inst, onMetricas: onMetricas);
    default:
      return GenericoWidget(instancia: inst, onMetricas: onMetricas);
  }
}

class GaleriaScreen extends StatefulWidget {
  const GaleriaScreen({super.key});

  @override
  State<GaleriaScreen> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  List<Instancia> _todas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final txt = await rootBundle.loadString('assets/demo_actividades.json');
    final data = jsonDecode(txt) as Map<String, dynamic>;
    final lista = (data['actividades'] as List)
        .map((e) => Instancia.fromJson(e as Map<String, dynamic>))
        .toList();
    if (!mounted) return;
    setState(() {
      _todas = lista;
      _cargando = false;
    });
  }

  void _jugar(int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _JugarDemo(actividades: _todas, indiceInicial: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar por bloque conservando el orden de aparición.
    final porBloque = <String, List<int>>{};
    for (var i = 0; i < _todas.length; i++) {
      porBloque.putIfAbsent(_todas[i].bloque, () => []).add(i);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividades (demo)'),
        backgroundColor: TrazoColors.white,
        foregroundColor: TrazoColors.ink,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Toca cualquier actividad para probarla como en la tablet. '
                    'Es una muestra; no guarda nada.',
                    style: TextStyle(color: TrazoColors.sageDark, fontSize: 15),
                  ),
                ),
                for (final entry in porBloque.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(_kBloques[entry.key] ?? entry.key,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: TrazoColors.ink)),
                  ),
                  ...entry.value.map((i) => _FilaActividad(
                        inst: _todas[i],
                        onTap: () => _jugar(i),
                      )),
                ],
              ],
            ),
    );
  }
}

class _FilaActividad extends StatelessWidget {
  final Instancia inst;
  final VoidCallback onTap;
  const _FilaActividad({required this.inst, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: TrazoColors.white,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(inst.nombre,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: TrazoColors.ink)),
        subtitle: Text(inst.plantilla,
            style: const TextStyle(color: TrazoColors.sageDark, fontSize: 12)),
        trailing: const Icon(Icons.play_circle_outline,
            color: TrazoColors.sage, size: 30),
      ),
    );
  }
}

/// Reproductor a pantalla completa: prueba la actividad y muestra qué mediría la
/// app cuando la persona responde. "Siguiente" pasa a la actividad de al lado.
class _JugarDemo extends StatefulWidget {
  final List<Instancia> actividades;
  final int indiceInicial;
  const _JugarDemo({required this.actividades, required this.indiceInicial});

  @override
  State<_JugarDemo> createState() => _JugarDemoState();
}

class _JugarDemoState extends State<_JugarDemo> {
  late int _i = widget.indiceInicial;
  Map<String, dynamic>? _ultimasMetricas;

  Instancia get _inst => widget.actividades[_i];

  void _siguiente() {
    setState(() {
      _i = (_i + 1) % widget.actividades.length;
      _ultimasMetricas = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera con nombre + cerrar.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_inst.nombre,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: TrazoColors.ink)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 28),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                // Clave por índice: recrea el estado del widget al cambiar.
                child: KeyedSubtree(
                  key: ValueKey(_i),
                  child: renderActividadDemo(_inst, (m) {
                    setState(() => _ultimasMetricas = m);
                  }),
                ),
              ),
            ),
            if (_ultimasMetricas != null)
              Container(
                width: double.infinity,
                color: TrazoColors.card,
                padding: const EdgeInsets.all(12),
                child: Text(
                  'La app registró: ${_ultimasMetricas.toString()}',
                  style: const TextStyle(
                      fontSize: 13, color: TrazoColors.sageDark),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _siguiente,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: TrazoColors.sage),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Siguiente'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
