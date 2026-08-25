// Galería/DEMO de actividades: permite PROBAR cada actividad como en la tablet,
// sin login ni backend. Pensada para revisar de un vistazo qué se ve bien y qué
// no, y para enseñar el producto. Los datos salen de assets/demo_actividades.json
// (una muestra por actividad, generada con el motor real).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;

import '../banco_veredictos.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/arrastrar_posicion_widget.dart';
import '../widgets/busqueda_visual_widget.dart';
import '../widgets/conteo_comparacion_widget.dart';
import '../widgets/generico_widget.dart';
import '../widgets/manejo_cantidad_widget.dart';
import '../widgets/memoria_parejas_widget.dart';
import '../widgets/memoria_visual_widget.dart';
import '../widgets/secuencia_ordenar_widget.dart';
import '../widgets/seleccion_multiple_widget.dart';
import '../widgets/trazo_logo.dart';
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

/// Traduce el Map de métricas a un resumen legible (esta pantalla también
/// alimenta la vitrina comercial: nunca debe verse el Map en crudo).
String _resumenMetricas(Map<String, dynamic> m) {
  const etiquetas = {
    'correcto': 'Resultado',
    'aciertos': 'Aciertos',
    'errores': 'Errores',
    'intentos': 'Intentos',
    'pistas': 'Pistas',
    'ayudas': 'Ayudas',
  };
  final partes = <String>[];
  m.forEach((k, v) {
    // Se omite el ruido técnico (tiempos en ms, ids, etc.).
    if (k.contains('tiempo') || k.contains('ms') || k.endsWith('_id')) return;
    final etiqueta = etiquetas[k] ?? k.replaceAll('_', ' ');
    final valor = v is bool ? (v ? 'sí' : 'no') : '$v';
    partes.add('$etiqueta: $valor');
  });
  return partes.isEmpty ? 'actividad completada.' : partes.join('  ·  ');
}

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
    case 'parejas':
      return MemoriaParejasWidget(
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

/// Puñado de actividades representativas para la VITRINA de la web comercial:
/// una por cada tipo, elegidas por ser vistosas y fáciles de entender. Es lo que
/// ve quien pulsa "Probar las actividades" en la landing (no la app interna).
const _kVitrina = <String>[
  'Sigue la línea', // trazo (con "Empieza" y flechas)
  '¿Qué objeto es?', // elegir imagen
  'Completar refranes', // elegir palabra
  'Memoria de figuras', // memoria visual
  'Parejas de animales', // parejas (encontrar iguales)
  'Cuenta cuántos hay', // contar
  '¿Fruta o verdura?', // arrastrar a su sitio (categoría clara)
  'Busca los corazones', // búsqueda visual
  'Ordena las etapas de la vida', // ordenar pasos (orden inequívoco)
  'Reúne el importe (solo monedas)', // dinero
];

class GaleriaScreen extends StatefulWidget {
  /// En modo vitrina se muestra solo una muestra curada y con textos pensados
  /// para un cliente, no para la persona que abre la app interna.
  final bool vitrina;
  const GaleriaScreen({super.key, this.vitrina = false});

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
    try {
      final txt = await rootBundle.loadString('assets/demo_actividades.json');
      final data = jsonDecode(txt) as Map<String, dynamic>;
      var lista = (data['actividades'] as List? ?? const [])
          .map((e) => Instancia.fromJson(e as Map<String, dynamic>))
          .toList();
      if (widget.vitrina) {
        // Solo la muestra curada, en el orden de _kVitrina.
        final porNombre = {for (final x in lista) x.nombre: x};
        lista = [
          for (final n in _kVitrina)
            if (porNombre[n] != null) porNombre[n]!,
        ];
      }
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _cargando = false;
      });
    } catch (_) {
      // Nunca dejar la vitrina colgada en el spinner: se muestra vacía.
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _jugar(int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _JugarDemo(actividades: _todas, indiceInicial: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vitrina) return _buildVitrina(context);

    // --- Modo interno: catálogo completo agrupado por bloque ---
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

  // --- Vitrina de la web comercial: paleta de la marca, tarjetas cálidas ---
  Widget _buildVitrina(BuildContext context) {
    return Scaffold(
      backgroundColor: TrazoColors.ivory,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            TrazoLogo(size: 46),
                            SizedBox(width: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trazo',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: TrazoColors.ink,
                                        height: 1.0)),
                                Text('Estimulación cognitiva en tablet',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: TrazoColors.sageDark,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        const Text('Actividades de muestra',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: TrazoColors.ink,
                                height: 1.1)),
                        const SizedBox(height: 10),
                        const Text(
                          'Algunos ejemplos de lo que hace la persona en la tablet. '
                          'Tócalos para probarlos: así de sencillos y claros. No hace '
                          'falta instalar nada ni se guarda ningún dato.',
                          style: TextStyle(
                              fontSize: 16.5,
                              color: TrazoColors.sageDark,
                              height: 1.5),
                        ),
                        const SizedBox(height: 26),
                        LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth > 620 ? 2 : 1;
                            const gap = 16.0;
                            final w = (c.maxWidth - (cols - 1) * gap) / cols;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (var i = 0; i < _todas.length; i++)
                                  SizedBox(
                                    width: w,
                                    child: _VitrinaCard(
                                      inst: _todas[i],
                                      onTap: () => _jugar(i),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Icono representativo de cada tipo de actividad (para la vitrina).
IconData _iconoPlantilla(String plantilla) {
  switch (plantilla) {
    case 'trazo':
      return Icons.gesture;
    case 'seleccion_multiple':
      return Icons.touch_app;
    case 'memoria_visual':
      return Icons.grid_view_rounded;
    case 'parejas':
      return Icons.style;
    case 'conteo_comparacion':
      return Icons.tag;
    case 'arrastrar_posicion':
      return Icons.pan_tool_alt;
    case 'busqueda_visual':
      return Icons.search;
    case 'secuencia_ordenar':
      return Icons.format_list_numbered;
    case 'manejo_cantidad':
      return Icons.euro;
    default:
      return Icons.play_arrow_rounded;
  }
}

/// Tarjeta de la vitrina: icono en círculo salvia, nombre y "Probar" en coral.
class _VitrinaCard extends StatelessWidget {
  final Instancia inst;
  final VoidCallback onTap;
  const _VitrinaCard({required this.inst, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrazoColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TrazoColors.sand, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDF3EE),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconoPlantilla(inst.plantilla),
                    color: TrazoColors.sageDark, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(inst.nombre,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: TrazoColors.ink,
                        height: 1.15)),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.play_circle_fill,
                  color: TrazoColors.coralDark, size: 30),
            ],
          ),
        ),
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

/// BANCO DE PRUEBAS (solo admin supremo): elige un bloque y recorre TODAS sus
/// actividades una a una, para revisar que se ven bien, tienen sentido y no
/// tienen dibujos rotos. No guarda nada. Se entra por URL secreta (ver main.dart).
class BancoPruebasScreen extends StatefulWidget {
  const BancoPruebasScreen({super.key});

  @override
  State<BancoPruebasScreen> createState() => _BancoPruebasScreenState();
}

class _BancoPruebasScreenState extends State<BancoPruebasScreen> {
  List<Instancia> _todas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // Veredictos ya guardados: para no volver a mostrar las actividades ya revisadas.
  Map<String, Veredicto> _veredictos = {};

  Future<void> _cargar() async {
    try {
      final txt = await rootBundle.loadString('assets/demo_actividades.json');
      final data = jsonDecode(txt) as Map<String, dynamic>;
      final lista = (data['actividades'] as List? ?? const [])
          .map((e) => Instancia.fromJson(e as Map<String, dynamic>))
          .toList();
      final ver = await BancoVeredictos.instance.todos();
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _veredictos = ver;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _recargarVeredictos() async {
    final ver = await BancoVeredictos.instance.todos();
    if (!mounted) return;
    setState(() => _veredictos = ver);
  }

  /// Cuántas de un bloque quedan SIN revisar (sin veredicto guardado).
  int _pendientesDe(List<Instancia> delBloque) =>
      delBloque.where((i) => !_veredictos.containsKey(i.nombre)).length;

  void _abrirBloque(List<Instancia> delBloque) {
    // Solo las que aún no has revisado: las ya vistas/marcadas no reaparecen.
    final pendientes =
        delBloque.where((i) => !_veredictos.containsKey(i.nombre)).toList();
    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ya revisaste todas las de este bloque 🎉')));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => _JugarDemo(
              actividades: pendientes, indiceInicial: 0, mostrarProgreso: true),
        ))
        .then((_) => _recargarVeredictos()); // refresca contadores al volver
  }

  /// Resumen de lo que la especialista ha marcado, con la lista de "a revisar" y
  /// un botón para copiarla (y pasársela a quien lo arregla).
  Future<void> _verMarcadas() async {
    final todos = await BancoVeredictos.instance.todos();
    if (!mounted) return;
    final validas =
        todos.entries.where((e) => e.value.estado == 'valida').toList();
    final revisar = todos.entries
        .where((e) => e.value.estado == 'revisar')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final otroGrupo = todos.entries
        .where((e) => e.value.estado == 'otro_grupo')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    // Lista mostrada: lo que requiere acción (revisar + reclasificar).
    final pendientes = [...revisar, ...otroGrupo];

    String textoExport() {
      final b = StringBuffer();
      b.writeln('TRAZO — A REVISAR (${revisar.length}):');
      for (final e in revisar) {
        b.writeln(
            '• ${e.key}${e.value.nota.isNotEmpty ? ' — ${e.value.nota}' : ''}');
      }
      b.writeln('\nTRAZO — CAMBIAR DE GRUPO (${otroGrupo.length}):');
      for (final e in otroGrupo) {
        b.writeln(
            '• ${e.key}${e.value.nota.isNotEmpty ? ' — ${e.value.nota}' : ''}');
      }
      b.writeln(
          '\nValidadas: ${validas.length} · A revisar: ${revisar.length} · Otro grupo: ${otroGrupo.length}');
      return b.toString();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TrazoColors.ivory,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lo que has marcado',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TrazoColors.ink)),
              const SizedBox(height: 4),
              Text(
                  '✅ ${validas.length}   ⚠️ ${revisar.length}   🔀 ${otroGrupo.length} (otro grupo)',
                  style: const TextStyle(
                      fontSize: 15, color: TrazoColors.sageDark)),
              const SizedBox(height: 12),
              if (pendientes.isEmpty)
                const Text(
                    'Aún no has marcado nada para revisar o reclasificar.',
                    style: TextStyle(color: TrazoColors.sageDark))
              else
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: [
                      for (final e in pendientes)
                        Card(
                          color: TrazoColors.white,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                                e.value.estado == 'otro_grupo'
                                    ? Icons.swap_horiz
                                    : Icons.report_problem,
                                color: e.value.estado == 'otro_grupo'
                                    ? TrazoColors.azul
                                    : TrazoColors.coralDark),
                            title: Text(e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text((e.value.estado == 'otro_grupo'
                                    ? 'Otro grupo'
                                    : 'A revisar') +
                                (e.value.nota.isEmpty
                                    ? ''
                                    : ' · ${e.value.nota}')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Quitar de la lista',
                              onPressed: () async {
                                await BancoVeredictos.instance.borrar(e.key);
                                if (ctx.mounted) Navigator.pop(ctx);
                                _verMarcadas();
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: pendientes.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                              ClipboardData(text: textoExport()));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Lista copiada')));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: TrazoColors.sageDark,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar la lista de «a revisar»'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agrupa por bloque en el orden de _kBloques (y añade los que falten al final).
    final porBloque = <String, List<Instancia>>{};
    for (final inst in _todas) {
      porBloque.putIfAbsent(inst.bloque, () => []).add(inst);
    }
    final clavesOrdenadas = <String>[
      ...(_kBloques.keys.where(porBloque.containsKey)),
      ...(porBloque.keys.where((k) => !_kBloques.containsKey(k))),
    ];

    return Scaffold(
      backgroundColor: TrazoColors.ivory,
      appBar: AppBar(
        title: const Text('Banco de pruebas · por bloque'),
        backgroundColor: TrazoColors.white,
        foregroundColor: TrazoColors.ink,
        actions: [
          TextButton.icon(
            onPressed: _verMarcadas,
            icon: const Icon(Icons.fact_check, color: TrazoColors.sageDark),
            label: const Text('Lo marcado',
                style: TextStyle(
                    color: TrazoColors.sageDark, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Elige un bloque y recórrelo entero: revisa que cada actividad '
                  'se ve bien, tiene sentido y no le faltan dibujos. '
                  '${_todas.length} actividades en total. No guarda nada.',
                  style: const TextStyle(
                      color: TrazoColors.sageDark, fontSize: 15),
                ),
                const SizedBox(height: 16),
                for (final clave in clavesOrdenadas)
                  Builder(builder: (_) {
                    final total = porBloque[clave]!.length;
                    final pend = _pendientesDe(porBloque[clave]!);
                    final hecho = pend == 0;
                    return Card(
                      color: TrazoColors.white,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        onTap: () => _abrirBloque(porBloque[clave]!),
                        leading: CircleAvatar(
                          backgroundColor:
                              hecho ? TrazoColors.sage : TrazoColors.sageDark,
                          foregroundColor: Colors.white,
                          child: Text(hecho ? '✓' : '$pend',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        title: Text(_kBloques[clave] ?? clave,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: TrazoColors.ink,
                                fontSize: 17)),
                        subtitle: Text(
                            hecho
                                ? 'Todas revisadas ($total)'
                                : '$pend por revisar de $total',
                            style: const TextStyle(
                                color: TrazoColors.sageDark, fontSize: 13)),
                        trailing: Icon(Icons.play_circle_fill,
                            color: hecho
                                ? TrazoColors.sand
                                : TrazoColors.coralDark,
                            size: 32),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

/// Reproductor a pantalla completa: prueba la actividad y muestra qué mediría la
/// app cuando la persona responde. "Siguiente" pasa a la actividad de al lado.
class _JugarDemo extends StatefulWidget {
  final List<Instancia> actividades;
  final int indiceInicial;

  /// En el banco de pruebas: muestra "N/total" para saber cuántas quedan del
  /// bloque (en la vitrina/demo no aporta y distrae, así que va apagado).
  final bool mostrarProgreso;
  const _JugarDemo(
      {required this.actividades,
      required this.indiceInicial,
      this.mostrarProgreso = false});

  @override
  State<_JugarDemo> createState() => _JugarDemoState();
}

class _JugarDemoState extends State<_JugarDemo> {
  late int _i = widget.indiceInicial;
  Map<String, dynamic>? _ultimasMetricas;

  Instancia get _inst => widget.actividades[_i];

  bool _vuelta =
      false; // en el banco: ya se recorrió el bloque entero al menos una vez

  // Veredicto de la especialista sobre la actividad actual (solo banco).
  Veredicto? _veredicto;
  final TextEditingController _notaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.mostrarProgreso) _cargarVeredicto();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVeredicto() async {
    final v = await BancoVeredictos.instance.para(_inst.nombre);
    if (!mounted) return;
    setState(() {
      _veredicto = v;
      _notaCtrl.text = v?.nota ?? '';
    });
  }

  Future<void> _marcar(String estado) async {
    await BancoVeredictos.instance
        .guardar(_inst.nombre, estado, _notaCtrl.text.trim());
    if (!mounted) return;
    setState(() => _veredicto = Veredicto(estado, _notaCtrl.text.trim()));
  }

  void _siguiente() {
    // En el banco: si la actividad actual no está marcada (ni a revisar ni otro
    // grupo), se da por VÁLIDA sola al pasar. Así solo hay que marcar lo que falla.
    if (widget.mostrarProgreso && _veredicto == null) {
      BancoVeredictos.instance.guardar(_inst.nombre, 'valida', '');
    }
    setState(() {
      final sig = _i + 1;
      if (sig >= widget.actividades.length) {
        _vuelta = true; // vuelve al principio del bloque
      }
      _i = sig % widget.actividades.length;
      _ultimasMetricas = null;
    });
    if (widget.mostrarProgreso) _cargarVeredicto();
  }

  // Nota plegada por defecto: en el móvil roba mucha pantalla a la actividad.
  bool _notaAbierta = false;

  /// Barra COMPACTA del banco (móvil): veredicto + nota plegable + Siguiente, en
  /// el mínimo espacio, para dejar casi toda la pantalla a la actividad.
  Widget _barraBanco() {
    final v = _veredicto;
    Color colorDe(String e) => e == 'valida'
        ? TrazoColors.sageDark
        : e == 'revisar'
            ? TrazoColors.coralDark
            : TrazoColors.azul; // otro_grupo (mal clasificada)
    Color fondo(String e) => v?.estado == e ? colorDe(e) : TrazoColors.white;
    Color texto(String e) => v?.estado == e ? Colors.white : TrazoColors.ink;

    Widget chip(String estado, IconData ic, String etq) => Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _marcar(estado),
            style: OutlinedButton.styleFrom(
              backgroundColor: fondo(estado),
              foregroundColor: texto(estado),
              side: BorderSide(color: colorDe(estado)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
            icon: Icon(ic, size: 17),
            label: Text(etq, style: const TextStyle(fontSize: 13)),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      color: const Color(0xFFF3F7F5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_notaAbierta)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextField(
                controller: _notaCtrl,
                minLines: 1,
                maxLines: 2,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Qué falla, qué cambiar…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (t) {
                  if (v != null) {
                    BancoVeredictos.instance
                        .guardar(_inst.nombre, v.estado, t.trim());
                  }
                },
              ),
            ),
          // Solo se marca lo que está MAL: si la juegas sin problema y pasas a
          // Siguiente, se da por VÁLIDA sola (menos fricción). "Otro grupo" = la
          // actividad está bien pero no pertenece a ese bloque.
          Row(
            children: [
              chip('revisar', Icons.report_problem, 'A revisar'),
              const SizedBox(width: 8),
              chip('otro_grupo', Icons.swap_horiz, 'Otro grupo'),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _notaAbierta = !_notaAbierta),
                tooltip: 'Nota',
                icon: Icon(
                    _notaCtrl.text.trim().isEmpty
                        ? Icons.sticky_note_2_outlined
                        : Icons.sticky_note_2,
                    color: TrazoColors.sageDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                    _veredicto == null
                        ? 'Si está bien, no marques nada: pasa a Siguiente (se da por válida).'
                        : (_veredicto!.estado == 'otro_grupo'
                            ? 'Marcada: otro grupo.'
                            : 'Marcada: a revisar.'),
                    style: const TextStyle(
                        fontSize: 12, color: TrazoColors.sageDark)),
              ),
              ElevatedButton(
                onPressed: _siguiente,
                style: ElevatedButton.styleFrom(
                    backgroundColor: TrazoColors.sageDark,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
                child: const Text('Siguiente →'),
              ),
            ],
          ),
        ],
      ),
    );
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.mostrarProgreso)
                          Text(
                              '${_i + 1} / ${widget.actividades.length}  ·  ${_inst.plantilla}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: TrazoColors.sageDark)),
                        Text(_inst.nombre,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: TrazoColors.ink)),
                      ],
                    ),
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
                // En el banco (móvil) casi sin margen: la actividad manda.
                padding: EdgeInsets.all(widget.mostrarProgreso ? 6 : 16),
                // Clave por índice: recrea el estado del widget al cambiar.
                child: KeyedSubtree(
                  key: ValueKey(_i),
                  child: renderActividadDemo(_inst, (m) {
                    setState(() => _ultimasMetricas = m);
                  }),
                ),
              ),
            ),
            // Banco de pruebas: avisa cuando ya se recorrió el bloque entero (para
            // que el revisor sepa que dio la vuelta y no siga en bucle sin darse cuenta).
            if (widget.mostrarProgreso && _vuelta)
              Container(
                width: double.infinity,
                color: TrazoColors.sageDark,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Text(
                  'Has recorrido las ${widget.actividades.length} de este bloque; vuelve a empezar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            // Banco: barra compacta (veredicto + Siguiente). Demo/vitrina: fila normal.
            if (widget.mostrarProgreso)
              _barraBanco()
            else ...[
              if (_ultimasMetricas != null)
                Container(
                  width: double.infinity,
                  color: TrazoColors.card,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'En esta prueba — ${_resumenMetricas(_ultimasMetricas!)}',
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
                            backgroundColor: TrazoColors.sageDark),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Siguiente'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
