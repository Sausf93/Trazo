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
import '../widgets/reto_garrafas_widget.dart';
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
  'percepcion': 'Percepción',
  'retos': 'Retos de ingenio',
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

/// Etiqueta legible del veredicto del banco.
String _etqEstado(String e) => e == 'valida'
    ? 'válida'
    : e == 'revisar'
        ? 'dudosa'
        : e == 'descartar'
            ? 'no válida'
            : 'otro grupo';

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
    case 'reto_garrafas':
      return RetoGarrafasWidget(
          reto: RetoGarrafas.desdeRender(inst.render), onMetricas: onMetricas);
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
    case 'reto_garrafas':
      return Icons.water_drop;
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
  /// `false` = carrusel de PENDIENTES de valorar (se marca; salen solo las no
  /// clasificadas). `true` = vitrina de APROBADAS (solo validadas; solo se
  /// juegan, sin marcar) para el filtro final.
  final bool modoAprobadas;
  const BancoPruebasScreen({super.key, this.modoAprobadas = false});

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
      var lista = (data['actividades'] as List? ?? const [])
          .map((e) => Instancia.fromJson(e as Map<String, dynamic>))
          .toList();
      // En modo APROBADAS solo se muestran las validadas (las que ya pasaron el
      // filtro). El estado viaja en el asset.
      if (widget.modoAprobadas) {
        final aprobadas = <String>{
          for (final e in (data['actividades'] as List? ?? const []))
            if ((e as Map<String, dynamic>)['estado'] == 'validada')
              (e['nombre'] ?? '').toString(),
        };
        lista = lista.where((i) => aprobadas.contains(i.nombre)).toList();
        if (!mounted) return;
        setState(() {
          _todas = lista;
          _cargando = false;
        });
        return; // sin nombre, sin sincronizar marcas, sin marcar
      }
      final ver = await BancoVeredictos.instance.todos();
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _veredictos = ver;
        _cargando = false;
      });
      await _asegurarNombre();
      // Sincroniza con el servidor: si el equipo borró una marca (actividad ya
      // corregida), aquí desaparece y la actividad vuelve a salir.
      final quien = await BancoVeredictos.instance.nombreMarcador();
      await BancoVeredictos.instance.descargarDeServidor(quien);
      await _recargarVeredictos();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Pregunta UNA vez quién está revisando (Saulo, Laura…) para que sus marcas
  /// viajen con su nombre al servidor y el equipo sepa quién dijo qué.
  Future<void> _asegurarNombre() async {
    final actual = await BancoVeredictos.instance.nombreMarcador();
    if (actual.isNotEmpty || !mounted) return;
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var t = '';
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('¿Quién va a revisar?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Tu nombre acompaña a cada marca (p. ej. Saulo, Laura).'),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (v) => setD(() => t = v.trim()),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: 'Tu nombre'),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: t.isEmpty ? null : () => Navigator.pop(ctx, t),
                child: const Text('Empezar'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (nombre != null && nombre.isNotEmpty) {
      await BancoVeredictos.instance.fijarNombre(nombre);
    }
  }

  Future<void> _recargarVeredictos() async {
    final ver = await BancoVeredictos.instance.todos();
    if (!mounted) return;
    setState(() => _veredictos = ver);
  }

  /// En PENDIENTES: cuántas quedan sin marcar. En APROBADAS: todas las del bloque.
  int _pendientesDe(List<Instancia> delBloque) => widget.modoAprobadas
      ? delBloque.length
      : delBloque.where((i) => !_veredictos.containsKey(i.nombre)).length;

  void _abrirBloque(List<Instancia> delBloque) {
    // Aprobadas: se juegan TODAS (sin marcar). Pendientes: solo las no marcadas.
    final pendientes = widget.modoAprobadas
        ? delBloque.toList()
        : delBloque.where((i) => !_veredictos.containsKey(i.nombre)).toList();
    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Marcaste todas las de este bloque; no queda ninguna que jugar.')));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => _JugarDemo(
              actividades: pendientes,
              indiceInicial: 0,
              mostrarProgreso: !widget.modoAprobadas),
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
    final descartar = todos.entries
        .where((e) => e.value.estado == 'descartar')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final otroGrupo = todos.entries
        .where((e) => e.value.estado == 'otro_grupo')
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    // Lista mostrada: lo que requiere acción (dudosa + no válida + reclasificar).
    final pendientes = [...revisar, ...descartar, ...otroGrupo];

    String textoExport() {
      final b = StringBuffer();
      b.writeln('TRAZO — DUDOSAS / A ARREGLAR (${revisar.length}):');
      for (final e in revisar) {
        b.writeln(
            '• ${e.key}${e.value.nota.isNotEmpty ? ' — ${e.value.nota}' : ''}');
      }
      b.writeln('\nTRAZO — NO VÁLIDAS / ELIMINAR (${descartar.length}):');
      for (final e in descartar) {
        b.writeln(
            '• ${e.key}${e.value.nota.isNotEmpty ? ' — ${e.value.nota}' : ''}');
      }
      b.writeln('\nTRAZO — CAMBIAR DE GRUPO (${otroGrupo.length}):');
      for (final e in otroGrupo) {
        b.writeln(
            '• ${e.key}${e.value.nota.isNotEmpty ? ' — ${e.value.nota}' : ''}');
      }
      b.writeln(
          '\nVálidas: ${validas.length} · Dudosas: ${revisar.length} · No válidas: ${descartar.length} · Otro grupo: ${otroGrupo.length}');
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
                  '✅ ${validas.length}   ⚠️ ${revisar.length}   🚫 ${descartar.length}   🔀 ${otroGrupo.length}',
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
                                    : e.value.estado == 'descartar'
                                        ? Icons.block
                                        : Icons.report_problem,
                                color: e.value.estado == 'otro_grupo'
                                    ? TrazoColors.azul
                                    : e.value.estado == 'descartar'
                                        ? const Color(0xFFB3261E)
                                        : TrazoColors.coralDark),
                            title: Text(e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(_etqEstado(e.value.estado) +
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
        title: Text(widget.modoAprobadas
            ? 'Actividades aprobadas · por bloque'
            : 'Pendientes de valorar · por bloque'),
        backgroundColor: TrazoColors.white,
        foregroundColor: TrazoColors.ink,
        actions: [
          if (!widget.modoAprobadas)
            TextButton.icon(
              onPressed: _verMarcadas,
              icon: const Icon(Icons.fact_check, color: TrazoColors.sageDark),
              label: const Text('Lo marcado',
                  style: TextStyle(
                      color: TrazoColors.sageDark,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.modoAprobadas
                      ? 'Actividades ya aprobadas (${_todas.length}). Juégalas '
                          'para el filtro final, cuando todo esté perfecto.'
                      : 'Elige un bloque y recórrelo entero: revisa que cada '
                          'actividad se ve bien y tiene sentido. Solo salen las '
                          'que aún NO has valorado (${_todas.length} en total).',
                  style: const TextStyle(
                      color: TrazoColors.sageDark, fontSize: 15),
                ),
                const SizedBox(height: 16),
                for (final clave in clavesOrdenadas)
                  Builder(builder: (_) {
                    final total = porBloque[clave]!.length;
                    final pend = _pendientesDe(porBloque[clave]!); // sin marcar
                    final marcadas = total - pend;
                    return Card(
                      color: TrazoColors.white,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        onTap: () => _abrirBloque(porBloque[clave]!),
                        leading: CircleAvatar(
                          backgroundColor: TrazoColors.sageDark,
                          foregroundColor: Colors.white,
                          child: Text('$total',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        title: Text(_kBloques[clave] ?? clave,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: TrazoColors.ink,
                                fontSize: 17)),
                        subtitle: Text(
                            widget.modoAprobadas
                                ? '$total aprobadas — tócalo para jugarlas'
                                : marcadas > 0
                                    ? '$total · $marcadas ya valoradas (no salen)'
                                    : '$total actividades — tócalo para jugarlas',
                            style: const TextStyle(
                                color: TrazoColors.sageDark, fontSize: 13)),
                        trailing: const Icon(Icons.play_circle_fill,
                            color: TrazoColors.coralDark, size: 32),
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
    // VÁLIDA: no exige motivo (el comentario es opcional vía la nota). Al marcarla
    // queda revisada -> no vuelve a salir, y viaja al servidor para que el equipo
    // la promocione a la app.
    if (estado == 'valida') {
      final nota = _notaCtrl.text.trim();
      await BancoVeredictos.instance.guardar(_inst.nombre, 'valida', nota);
      if (!mounted) return;
      setState(() => _veredicto = Veredicto('valida', nota));
      return;
    }
    // DUDOSA / NO VÁLIDA / OTRO GRUPO: el motivo es OBLIGATORIO (para poder
    // revisarla o arreglarla después).
    final titulo = estado == 'otro_grupo'
        ? '🔀 Otro grupo'
        : estado == 'descartar'
            ? '🚫 No válida'
            : '⚠️ Dudosa';
    final pregunta = estado == 'otro_grupo'
        ? '¿A qué grupo debería ir? (y por qué)'
        : estado == 'descartar'
            ? '¿Por qué no vale? (la vamos a eliminar)'
            : '¿Qué falla o qué habría que cambiar?';
    final ctrl = TextEditingController(text: _notaCtrl.text.trim());
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var texto = ctrl.text.trim();
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text(titulo),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pregunta),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (t) => setD(() => texto = t.trim()),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Escríbelo aquí…',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed:
                    texto.isEmpty ? null : () => Navigator.pop(ctx, texto),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (motivo == null || motivo.isEmpty) return; // canceló o vacío
    _notaCtrl.text = motivo;
    await BancoVeredictos.instance.guardar(_inst.nombre, estado, motivo);
    if (!mounted) return;
    setState(() => _veredicto = Veredicto(estado, motivo));
  }

  void _siguiente() {
    // COMPUERTA DE CALIDAD: marcar es OBLIGATORIO. No se puede pasar a la
    // siguiente sin dar un veredicto (válida / dudosa / no válida / otro grupo).
    if (widget.mostrarProgreso && _veredicto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Marca la actividad antes de pasar: '
            'válida, dudosa, no válida u otro grupo.'),
        duration: Duration(seconds: 3),
      ));
      return;
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
            : e == 'descartar'
                ? const Color(0xFFB3261E) // no válida (se elimina)
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
          // COMPUERTA: hay que dar un veredicto para poder pasar. Válida =
          // promociona a la app; Dudosa = a arreglar; No válida = se elimina;
          // Otro grupo = está bien pero va a otro bloque. Las tres últimas piden
          // motivo obligatorio.
          Row(
            children: [
              chip('valida', Icons.check_circle, 'Válida'),
              const SizedBox(width: 8),
              chip('revisar', Icons.report_problem, 'Dudosa'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              chip('descartar', Icons.block, 'No válida'),
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
                        ? 'Marca la actividad para continuar (obligatorio).'
                        : 'Marcada: ${_etqEstado(_veredicto!.estado)} · no vuelve a salir.',
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
