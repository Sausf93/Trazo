import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../api/client.dart';
import '../models.dart';
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

enum _Fase { esperando, quienEres, esperandoInicio, ejercicio, terminado }

/// Rol PARTICIPANTE (kiosco). Pantalla completa, sin menús, para usuarios
/// mayores. El control de "ayuda" vive SOLO en la tablet de la maestra.
class ParticipanteScreen extends StatefulWidget {
  const ParticipanteScreen({super.key});

  @override
  State<ParticipanteScreen> createState() => _ParticipanteScreenState();
}

class _ParticipanteScreenState extends State<ParticipanteScreen> {
  final _uuid = const Uuid();
  Timer? _timer;

  _Fase _fase = _Fase.esperando;
  SesionActiva? _sesion;
  ParticipanteSesion? _yo;

  List<ColaItem> _cola = [];
  int _idx = 0;
  // Ronda en curso: la maestra la sube al "Enviar más". Sirve de baseline para
  // detectar cuándo llega una nueva tanda mientras el participante espera.
  int _rondaBase = 0;
  Instancia? _instancia;
  bool _cargandoInstancia = false;
  String? _errorInstancia;
  Map<String, dynamic> _valores = {};
  DateTime? _inicioEjercicio;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Polling del estado de la sala --------------------------------------

  Future<void> _poll() async {
    SesionActiva sesion;
    try {
      sesion = await ApiClient.instance.sesionActiva();
    } catch (_) {
      return; // reintenta en el siguiente tick
    }
    if (!mounted) return;
    _sesion = sesion;

    // La sala se cerró: volver a la pantalla de espera.
    if (!sesion.haySesion) {
      if (_fase != _Fase.esperando) {
        setState(() {
          _fase = _Fase.esperando;
          _yo = null;
          _cola = [];
          _instancia = null;
        });
      } else {
        setState(() {});
      }
      return;
    }

    switch (_fase) {
      case _Fase.esperando:
        setState(() => _fase = _Fase.quienEres);
        break;
      case _Fase.esperandoInicio:
        if (sesion.iniciada) {
          _empezarCola();
        } else {
          setState(() {});
        }
        break;
      case _Fase.terminado:
        await _comprobarNuevaTanda(sesion);
        break;
      default:
        setState(() {});
    }
  }

  /// Mientras el participante espera tras terminar, comprueba si la maestra le
  /// ha mandado OTRA tanda (`ronda` sube / `terminado` vuelve a false).
  Future<void> _comprobarNuevaTanda(SesionActiva sesion) async {
    final yo = _yo;
    final sid = sesion.sesionId;
    if (yo == null || sid == null) return;
    EstadoParticipante est;
    try {
      est = await ApiClient.instance.estadoParticipante(sid, yo.usuarioFinalId);
    } catch (_) {
      return; // reintenta en el siguiente tick
    }
    if (!mounted || _fase != _Fase.terminado) return;
    // Nueva tanda: la maestra subió la ronda (pulsó "Enviar más"). Volvemos a
    // pedir la cola y continuamos donde estábamos.
    if (est.ronda > _rondaBase) {
      _rondaBase = est.ronda;
      _empezarCola();
    }
  }

  // --- Selección de identidad ---------------------------------------------

  void _elegirse(ParticipanteSesion p) {
    setState(() => _yo = p);
    final sesion = _sesion;
    if (sesion != null && sesion.iniciada) {
      _empezarCola();
    } else {
      setState(() => _fase = _Fase.esperandoInicio);
    }
  }

  // --- Cola de ejercicios --------------------------------------------------

  Future<void> _empezarCola() async {
    final yo = _yo;
    final sesion = _sesion;
    if (yo == null || sesion?.sesionId == null) return;
    setState(() {
      _fase = _Fase.ejercicio;
      _cargandoInstancia = true;
      _errorInstancia = null;
    });
    try {
      final cola = await ApiClient.instance
          .colaUsuario(yo.usuarioFinalId, sesion!.sesionId!);
      // La sala pudo cerrarse mientras se pedía la cola.
      if (!mounted || _fase == _Fase.esperando || _yo == null) return;
      _cola = cola;
      _idx = 0;
      if (_cola.isEmpty) {
        setState(() {
          _fase = _Fase.terminado;
          _cargandoInstancia = false;
        });
        return;
      }
      await _cargarInstancia();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _errorInstancia = err.toString();
        _cargandoInstancia = false;
      });
    }
  }

  Future<void> _cargarInstancia() async {
    final yo = _yo;
    if (yo == null || _idx >= _cola.length) return;
    setState(() {
      _cargandoInstancia = true;
      _errorInstancia = null;
      _instancia = null;
      _valores = {};
    });
    try {
      final inst = await ApiClient.instance.generarInstancia(
        _cola[_idx].ejercicioId,
        usuarioFinalId: yo.usuarioFinalId,
        nivel: _cola[_idx].nivel, // banda de cantidad según el plan del paciente
      );
      // La sala pudo cerrarse mientras se pedía la instancia.
      if (!mounted || _fase == _Fase.esperando) return;
      setState(() {
        _instancia = inst;
        _cargandoInstancia = false;
        _inicioEjercicio = DateTime.now();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _errorInstancia = err.toString();
        _cargandoInstancia = false;
      });
    }
  }

  /// Reintento robusto: si la cola no llegó a cargarse, la reintenta; si ya
  /// hay cola, reintenta solo la instancia actual.
  void _reintentar() {
    if (_cola.isEmpty) {
      _empezarCola();
    } else {
      _cargarInstancia();
    }
  }

  /// Registra el intento (la MEDICIÓN) y pasa al siguiente ejercicio.
  Future<void> _terminarEjercicio() async {
    final yo = _yo;
    final sesion = _sesion;
    final inst = _instancia;
    if (yo != null && sesion?.sesionId != null && inst != null) {
      final intento = Intento(
        id: _uuid.v4(), // UUID en cliente -> sync offline idempotente
        usuarioFinalId: yo.usuarioFinalId,
        sesionId: sesion!.sesionId!,
        ejercicioId: _cola[_idx].ejercicioId,
        estado: 'solo', // por defecto; la maestra puede marcar "con_ayuda"
        timestampInicio: _inicioEjercicio ?? DateTime.now(),
        timestampFin: DateTime.now(),
        valores: _valores, // <-- métricas reportadas por el widget
        cantidadObjetivo: inst.cantidadObjetivo,
      );
      await SyncQueue.enviarOEncolar(intento);
    }
    if (!mounted) return;
    if (_idx + 1 >= _cola.length) {
      // Terminó su tanda: avisar a la maestra y ESPERAR (no volver solo). El
      // polling detecta si la maestra manda otra tanda (la `ronda` sube).
      if (yo != null && sesion?.sesionId != null) {
        try {
          final est = await ApiClient.instance
              .marcarTerminadoParticipante(sesion!.sesionId!, yo.usuarioFinalId);
          _rondaBase = est.ronda;
        } catch (_) {
          // si falla el aviso, se queda en "terminado" igualmente
        }
      }
      if (!mounted) return;
      setState(() => _fase = _Fase.terminado);
    } else {
      setState(() => _idx += 1);
      _cargarInstancia();
    }
  }

  // --- Gesto discreto de salida (para la integradora) ---------------------

  void _menuIntegradora() async {
    final accion = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Panel de la integradora'),
        content: const Text(
            'Esta zona es solo para el personal. ¿Qué deseas hacer?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancelar'),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'reasignar'),
              child: const Text('Cambiar de persona')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, 'salir'),
              child: const Text('Salir del kiosco')),
        ],
      ),
    );
    if (!mounted) return;
    if (accion == 'salir') {
      Navigator.of(context).maybePop();
    } else if (accion == 'reasignar') {
      setState(() {
        _fase = (_sesion?.haySesion ?? false)
            ? _Fase.quienEres
            : _Fase.esperando;
        _yo = null;
        _cola = [];
        _instancia = null;
      });
    }
  }

  // --- Render por plantilla -----------------------------------------------

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
        return SecuenciaOrdenarWidget(instancia: inst, onMetricas: onMetricas);
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

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _contenido()),
            // Gesto discreto: esquina superior izquierda + pulsación larga.
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: _menuIntegradora,
                child: const SizedBox(width: 72, height: 72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    switch (_fase) {
      case _Fase.esperando:
        return const _Esperando();
      case _Fase.quienEres:
        return _QuienEres(
          sesion: _sesion,
          onElegir: _elegirse,
        );
      case _Fase.esperandoInicio:
        return _AhoraEmpezamos(nombre: _yo?.aliasInterno ?? '');
      case _Fase.terminado:
        return const _Terminado();
      case _Fase.ejercicio:
        return _VistaEjercicio(
          nombrePersona: _yo?.aliasInterno ?? '',
          indice: _idx,
          total: _cola.length,
          cargando: _cargandoInstancia,
          error: _errorInstancia,
          instancia: _instancia,
          // La clave (índice + ejercicio) fuerza a Flutter a crear un State
          // NUEVO por cada ejercicio; sin ella, dos ejercicios seguidos de la
          // misma plantilla reutilizarían el estado (trazo/selección) anterior
          // y contaminarían las métricas.
          render: _instancia == null
              ? null
              : KeyedSubtree(
                  key: ValueKey('${_idx}_${_instancia!.ejercicioId}'),
                  child: _renderPorPlantilla(_instancia!),
                ),
          onReintentar: _reintentar,
          onListo: _terminarEjercicio,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-pantallas del kiosco
// ---------------------------------------------------------------------------

class _Esperando extends StatelessWidget {
  const _Esperando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom, size: 96, color: TrazoColors.sage),
          SizedBox(height: 24),
          Text('Esperando sala…',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.ink)),
          SizedBox(height: 12),
          Text('En un momento empezamos.',
              style: TextStyle(fontSize: 22, color: TrazoColors.sageDark)),
        ],
      ),
    );
  }
}

class _QuienEres extends StatelessWidget {
  final SesionActiva? sesion;
  final ValueChanged<ParticipanteSesion> onElegir;

  const _QuienEres({required this.sesion, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final participantes = sesion?.participantes ?? [];
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('¿Quién eres?',
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: TrazoColors.ink)),
          const SizedBox(height: 8),
          const Text('Toca tu nombre',
              style: TextStyle(fontSize: 22, color: TrazoColors.sageDark)),
          const SizedBox(height: 28),
          Expanded(
            child: participantes.isEmpty
                ? const Center(
                    child: Text('Todavía no hay nadie en la sala.',
                        style: TextStyle(
                            fontSize: 22, color: TrazoColors.sageDark)))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 120,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                    ),
                    itemCount: participantes.length,
                    itemBuilder: (_, i) {
                      final p = participantes[i];
                      return _BotonNombre(
                          nombre: p.aliasInterno, onTap: () => onElegir(p));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BotonNombre extends StatelessWidget {
  final String nombre;
  final VoidCallback onTap;

  const _BotonNombre({required this.nombre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrazoColors.sage,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _AhoraEmpezamos extends StatelessWidget {
  final String nombre;
  const _AhoraEmpezamos({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.spa, size: 96, color: TrazoColors.sage),
          const SizedBox(height: 24),
          Text('¡Hola, $nombre!',
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: TrazoColors.ink)),
          const SizedBox(height: 12),
          const Text('Ahora empezamos…',
              style: TextStyle(fontSize: 24, color: TrazoColors.sageDark)),
          const SizedBox(height: 28),
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: TrazoColors.sage),
          ),
        ],
      ),
    );
  }
}

class _Terminado extends StatelessWidget {
  const _Terminado();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 120, color: TrazoColors.coral),
          SizedBox(height: 24),
          Text('¡Muy bien!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: TrazoColors.ink)),
          SizedBox(height: 12),
          Text('Has terminado. Espera un momento…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, color: TrazoColors.sageDark)),
        ],
      ),
    );
  }
}

class _VistaEjercicio extends StatelessWidget {
  final String nombrePersona;
  final int indice;
  final int total;
  final bool cargando;
  final String? error;
  final Instancia? instancia;
  final Widget? render;
  final VoidCallback onReintentar;
  final VoidCallback onListo;

  const _VistaEjercicio({
    required this.nombrePersona,
    required this.indice,
    required this.total,
    required this.cargando,
    required this.error,
    required this.instancia,
    required this.render,
    required this.onReintentar,
    required this.onListo,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(color: TrazoColors.sage)),
            SizedBox(height: 20),
            Text('Preparando…',
                style: TextStyle(fontSize: 22, color: TrazoColors.sageDark)),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 72, color: TrazoColors.sand),
            const SizedBox(height: 16),
            const Text('No se pudo cargar el ejercicio.',
                style: TextStyle(fontSize: 22, color: TrazoColors.ink)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Cabecera minimal con progreso (sin menús).
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  instancia?.nombre ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: TrazoColors.ink),
                ),
              ),
              Text('${indice + 1} de $total',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.sageDark)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: render ?? const SizedBox.shrink(),
          ),
        ),
        // Único botón grande y amable para el usuario mayor.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onListo,
              style: ElevatedButton.styleFrom(
                backgroundColor: TrazoColors.sage,
                padding: const EdgeInsets.symmetric(vertical: 24),
                textStyle: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.check_circle, size: 32),
              label: Text(indice + 1 >= total ? 'Terminar' : 'Siguiente'),
            ),
          ),
        ),
      ],
    );
  }
}
