import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../api/client.dart';
import '../models.dart';
import '../sync_queue.dart';
import '../theme.dart';
import '../tts.dart';
import '../widgets/arrastrar_posicion_widget.dart';
import '../widgets/busqueda_visual_widget.dart';
import '../widgets/conteo_comparacion_widget.dart';
import '../widgets/generico_widget.dart';
import '../widgets/manejo_cantidad_widget.dart';
import '../widgets/memoria_parejas_widget.dart';
import '../widgets/memoria_visual_widget.dart';
import '../widgets/secuencia_ordenar_widget.dart';
import '../widgets/seleccion_multiple_widget.dart';
import '../widgets/trazo_widget.dart';

enum _Fase {
  esperando,
  // Hay VARIAS salas abiertas en el centro: la persona elige primero a cuál
  // unirse (qué actividad/grupo) y luego su nombre.
  elegirSala,
  quienEres,
  esperandoInicio,
  ejercicio,
  terminado,
  // La cola llegó vacía (p. ej. paciente aún sin plan): NO es "terminó", así que
  // no se muestra la felicitación. Se avisa para que la responsable lo resuelva.
  sinActividades,
}

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
  // Sala elegida (cuando hay varias) antes de elegir el nombre. Determina qué
  // lista de personas se muestra y a qué sesión se liga la persona.
  SalaActiva? _salaElegida;
  ParticipanteSesion? _yo;
  // Sesión a la que este participante quedó ligado al elegir su identidad. Toda
  // su medición va SIEMPRE a esta sesión, no a la "más reciente" del centro: si
  // se abre otra sala a mitad de actividad, no se le reasigna en silencio.
  String? _sesionIdActivo;

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
  // Algunas actividades (memoria) tienen un paso interno previo (memorizar) en el
  // que NO debe aparecer el botón global "Siguiente" (si no, se salta la prueba
  // sin medir). El widget lo controla con onListoParaAvanzar.
  bool _puedeAvanzar = true;
  // Ticks de polling fallidos seguidos (WiFi caído). A partir de 3 (~9 s) se
  // muestra un aviso en las pantallas de espera para que la integradora actúe;
  // el mayor no se queda con un "Esperando…" eterno sin saber que algo va mal.
  int _fallosSeguidos = 0;
  bool get _sinConexion => _fallosSeguidos >= 3;
  // Guarda de reentrada: con WiFi lento el timeout (12s) supera el tick (3s) y
  // se solaparían varios polls (banner errático, dos _empezarCola en carrera).
  bool _polling = false;

  // Overlay cálido y breve entre pasos (micro-refuerzo tras cada actividad y
  // puente al recibir otra tanda): la persona no encadena pruebas "al vacío" ni
  // recibe trabajo de golpe justo tras oír "has terminado".
  String? _overlayMensaje;
  String? _overlaySub;

  Future<void> _mostrarPaso(String msg, {String? sub, int ms = 1000}) async {
    if (!mounted) return;
    setState(() {
      _overlayMensaje = msg;
      _overlaySub = sub;
    });
    HapticFeedback.lightImpact();
    // Refuerzo/puente HABLADO: quien no lee bien también recibe el ánimo.
    Tts.instance.hablar(sub == null ? msg : '$msg. $sub');
    await Future.delayed(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(() {
      _overlayMensaje = null;
      _overlaySub = null;
    });
  }

  // Palabra cálida rotada para el refuerzo entre actividades (sobria, no infantil).
  String _fraseRefuerzo() {
    const frases = ['¡Muy bien!', 'Estupendo', '¡Vas muy bien!', 'Perfecto', '¡Bien hecho!'];
    return frases[_idx % frases.length];
  }

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    Tts.instance.parar();
    super.dispose();
  }

  // --- Polling del estado de la sala --------------------------------------

  Future<void> _poll() async {
    if (_polling) return; // no solapar con un poll aún en vuelo
    _polling = true;
    try {
      await _pollImpl();
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollImpl() async {
    // Aprovecha cada tick para reenviar mediciones que quedaron pendientes por
    // un corte de WiFi (no se pierden). flush() es barato si no hay nada.
    SyncQueue.flush();
    SesionActiva sesion;
    try {
      sesion = await ApiClient.instance.sesionActiva();
    } catch (_) {
      // Fallo de red: cuenta el tick y refresca por si toca mostrar el aviso.
      _fallosSeguidos++;
      if (mounted && _sinConexion) setState(() {});
      return; // reintenta en el siguiente tick
    }
    if (!mounted) return;
    if (_fallosSeguidos != 0) _fallosSeguidos = 0; // recuperada la conexión
    _sesion = sesion;

    // No hay ninguna sala abierta en el centro: volver a la pantalla de espera.
    if (!sesion.haySesion) {
      _volverAEspera();
      return;
    }

    // --- Persona YA ligada a una sala: todo gira en torno a SU sala ---------
    final sid = _sesionIdActivo;
    if (_yo != null && sid != null) {
      final sala = sesion.salaConId(sid);
      // Su sala se cerró (la maestra la finalizó): volver a espera. NO se le
      // reasigna en silencio a otra sala aunque el centro tenga más abiertas.
      if (sala == null) {
        _volverAEspera();
        return;
      }
      switch (_fase) {
        case _Fase.esperandoInicio:
          if (sala.iniciada) {
            _empezarCola();
          } else {
            setState(() {});
          }
          break;
        case _Fase.terminado:
          await _comprobarNuevaTanda(sala);
          break;
        default:
          setState(() {});
      }
      return;
    }

    // --- Persona AÚN sin elegir: elegir sala (si hay varias) y luego nombre --
    // Si su sala elegida desapareció (se cerró) mientras elegía, se recalcula.
    if (_salaElegida != null &&
        sesion.salaConId(_salaElegida!.sesionId) == null) {
      _salaElegida = null;
    }
    if (!sesion.variasSalas) {
      // Una sola sala: se salta el paso de elegir sala.
      _salaElegida = sesion.salas.isNotEmpty ? sesion.salas.first : null;
    } else {
      // Refresca la sala elegida con su estado más reciente (participantes).
      if (_salaElegida != null) {
        _salaElegida = sesion.salaConId(_salaElegida!.sesionId);
      }
    }

    switch (_fase) {
      case _Fase.esperando:
        setState(() =>
            _fase = sesion.variasSalas ? _Fase.elegirSala : _Fase.quienEres);
        break;
      case _Fase.elegirSala:
        // Si dejó de haber varias (una se cerró), colapsa a "¿quién eres?".
        setState(() {
          if (!sesion.variasSalas) _fase = _Fase.quienEres;
        });
        break;
      default:
        setState(() {});
    }
  }

  void _volverAEspera() {
    setState(() {
      _fase = _Fase.esperando;
      _yo = null;
      _salaElegida = null;
      _sesionIdActivo = null;
      _cola = [];
      _instancia = null;
    });
  }

  /// Mientras el participante espera tras terminar, comprueba si la maestra le
  /// ha mandado OTRA tanda (`ronda` sube / `terminado` vuelve a false).
  Future<void> _comprobarNuevaTanda(SalaActiva sala) async {
    final yo = _yo;
    final sid = sala.sesionId;
    if (yo == null) return;
    EstadoParticipante est;
    try {
      est = await ApiClient.instance.estadoParticipante(sid, yo.usuarioFinalId);
    } catch (_) {
      return; // reintenta en el siguiente tick
    }
    if (!mounted || _fase != _Fase.terminado) return;
    // Nueva tanda: la maestra subió la ronda (pulsó "Enviar más"). Se muestra un
    // puente sereno que reconecta con el "has terminado" que se le acaba de decir
    // (si no, reaparece trabajo de golpe y desconcierta), y luego se pide la cola.
    if (est.ronda > _rondaBase) {
      _rondaBase = est.ronda;
      await _mostrarPaso('¡Seguimos!',
          sub: 'Tu responsable te ha preparado un poco más', ms: 2000);
      if (!mounted) return;
      _empezarCola();
    }
  }

  // --- Selección de identidad ---------------------------------------------

  Future<void> _elegirse(ParticipanteSesion p) async {
    // Confirmación grande: si una persona con Alzheimer toca el nombre de al
    // lado, sus mediciones irían a OTRA ficha. Se confirma antes de empezar.
    // Se dice EN VOZ ALTA para quien no lee bien (evita medir a otra persona).
    Tts.instance.hablar('¿Eres tú, ${p.aliasInterno}?');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Eres tú, ${p.aliasInterno}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: TrazoColors.ink)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                textStyle: const TextStyle(fontSize: 20),
                foregroundColor: TrazoColors.coralDark,
                side: const BorderSide(color: TrazoColors.coral)),
            child: const Text('No, soy otro'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: TrazoColors.sageDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            child: const Text('Sí, soy yo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Queda ligado a SU sala (la elegida, o la única): su medición irá siempre
    // ahí, no a "la más reciente" del centro (ver _sesionIdActivo).
    final sala = _salaElegida ??
        (_sesion?.salas.isNotEmpty ?? false ? _sesion!.salas.first : null);
    if (sala == null) return;
    setState(() {
      _yo = p;
      _salaElegida = sala;
      _sesionIdActivo = sala.sesionId;
    });
    if (sala.iniciada) {
      _empezarCola();
    } else {
      setState(() => _fase = _Fase.esperandoInicio);
    }
  }

  // --- Cola de ejercicios --------------------------------------------------

  Future<void> _empezarCola() async {
    final yo = _yo;
    final sid = _sesionIdActivo;
    if (yo == null || sid == null) return;
    setState(() {
      _fase = _Fase.ejercicio;
      _cargandoInstancia = true;
      _errorInstancia = null;
    });
    try {
      final cola = await ApiClient.instance
          .colaUsuario(yo.usuarioFinalId, sid);
      // La sala pudo cerrarse mientras se pedía la cola.
      if (!mounted || _fase == _Fase.esperando || _yo == null) return;
      _cola = cola;
      _idx = 0;
      if (_cola.isEmpty) {
        setState(() {
          _fase = _Fase.sinActividades;
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
      _puedeAvanzar = true; // por defecto se puede avanzar; memoria lo desactiva
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
      // Lee la consigna en voz alta (accesibilidad: mayores que no leen bien).
      Tts.instance.hablar(_textoParaLeer(inst));
      // Avisa al monitor de la maestra de en qué actividad va AHORA. Usa la sala
      // a la que la persona quedó LIGADA (_sesionIdActivo), no el campo plano:
      // con varias salas el plano es la más reciente y el reporte iría a la sala
      // equivocada (el monitor perdería 'actividad en curso' y 'atascado').
      final sid = _sesionIdActivo;
      if (sid != null) {
        ApiClient.instance.reportarActual(
            sid, yo.usuarioFinalId, inst.nombre, _idx + 1, _cola.length);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _errorInstancia = err.toString();
        _cargandoInstancia = false;
      });
    }
  }

  /// Texto que se lee en voz alta: la consigna y, si la actividad trae un
  /// enunciado distinto (p. ej. la serie o el refrán), también.
  String _textoParaLeer(Instancia inst) {
    final r = inst.render;
    final instr = (r['instruccion'] ?? '').toString().trim();
    final enun = (r['enunciado'] ?? '').toString().trim();
    var base = (enun.isNotEmpty && enun != instr)
        ? (instr.isEmpty ? enun : '$instr. $enun')
        : instr;
    // Accesibilidad: leer también las OPCIONES en voz alta (muchos mayores no
    // leen bien; antes solo se dictaba la pregunta y las respuestas quedaban
    // mudas). Solo seleccion_multiple trae 'opciones'.
    final opciones = (r['opciones'] as List?)
        ?.map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (opciones != null && opciones.isNotEmpty) {
      base = '$base. Las opciones son: ${opciones.join(', ')}.';
    }
    return base;
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

  // Evita que una doble pulsación de "Siguiente" registre el intento dos veces
  // (medición duplicada) y salte una actividad.
  bool _avanzando = false;

  /// Registra el intento (la MEDICIÓN) y pasa al siguiente ejercicio.
  Future<void> _terminarEjercicio() async {
    if (_avanzando) return;
    _avanzando = true;
    try {
      await _terminarEjercicioImpl();
    } finally {
      _avanzando = false;
    }
  }

  Future<void> _terminarEjercicioImpl() async {
    final yo = _yo;
    final sid = _sesionIdActivo; // SIEMPRE la sesión a la que quedó ligado
    final inst = _instancia;
    if (yo != null && sid != null && inst != null) {
      final intento = Intento(
        id: _uuid.v4(), // UUID en cliente -> sync offline idempotente
        usuarioFinalId: yo.usuarioFinalId,
        sesionId: sid,
        ejercicioId: _cola[_idx].ejercicioId,
        // Nace SIN VALORAR: no cuenta como acierto hasta que la integradora diga
        // cómo fue (solo/con_ayuda/no_pudo). Así la medida no se infla sola.
        estado: 'sin_valorar',
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
      if (yo != null && sid != null) {
        try {
          final est = await ApiClient.instance
              .marcarTerminadoParticipante(sid, yo.usuarioFinalId);
          _rondaBase = est.ronda;
        } catch (_) {
          // si falla el aviso, se queda en "terminado" igualmente
        }
      }
      if (!mounted) return;
      setState(() => _fase = _Fase.terminado);
    } else {
      // Micro-refuerzo digno antes de la siguiente actividad: reconoce el
      // esfuerzo en vez de saltar en silencio de una prueba a otra.
      setState(() => _idx += 1);
      await _mostrarPaso(_fraseRefuerzo(), ms: 1000);
      if (!mounted) return;
      _cargarInstancia();
    }
  }

  // --- Gesto discreto de salida (para la integradora) ---------------------

  // PIN del personal para salir del kiosco. Configurable al compilar con
  // --dart-define=KIOSK_PIN=xxxx. Evita que un mayor salga y vea la lista de
  // nombres del centro o se reasigne a otra persona.
  static const _pinKiosco =
      String.fromEnvironment('KIOSK_PIN', defaultValue: '1379');

  void _menuIntegradora() async {
    // Primero el PIN: si un usuario mayor abre esto por azar, no puede salir.
    final okPin = await showDialog<bool>(
      context: context,
      builder: (_) => const _PinDialog(pinCorrecto: _pinKiosco),
    );
    if (okPin != true || !mounted) return;
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
              child: const Text('Salir del modo actividades')),
        ],
      ),
    );
    if (!mounted) return;
    if (accion == 'salir') {
      Navigator.of(context).maybePop();
    } else if (accion == 'reasignar') {
      // Al cambiar de persona se suelta la sala: si el centro tiene varias, se
      // vuelve a elegir sala primero; si solo hay una, directo a "¿quién eres?".
      setState(() {
        final ses = _sesion;
        _yo = null;
        _salaElegida = null;
        _sesionIdActivo = null;
        _cola = [];
        _instancia = null;
        if (ses == null || !ses.haySesion) {
          _fase = _Fase.esperando;
        } else {
          _fase = ses.variasSalas ? _Fase.elegirSala : _Fase.quienEres;
        }
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
        return MemoriaVisualWidget(
          instancia: inst,
          onMetricas: onMetricas,
          // Durante "memorizar" no debe verse el botón global (evita saltarse la
          // fase de selección sin medir).
          onListoParaAvanzar: (v) {
            if (mounted) setState(() => _puedeAvanzar = v);
          },
        );
      case 'parejas':
        return MemoriaParejasWidget(
          instancia: inst,
          onMetricas: onMetricas,
          // No mostrar "Siguiente" hasta completar el tablero (no saltarse el juego).
          onListoParaAvanzar: (v) {
            if (mounted) setState(() => _puedeAvanzar = v);
          },
        );
      case 'secuencia_ordenar':
        return SecuenciaOrdenarWidget(instancia: inst, onMetricas: onMetricas);
      case 'conteo_comparacion':
        return ConteoComparacionWidget(
            instancia: inst, onMetricas: onMetricas);
      case 'arrastrar_posicion':
        return ArrastrarPosicionWidget(
            instancia: inst, onMetricas: onMetricas);
      case 'manejo_cantidad':
        return ManejoCantidadWidget(instancia: inst, onMetricas: onMetricas);
      case 'busqueda_visual':
        return BusquedaVisualWidget(instancia: inst, onMetricas: onMetricas);
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
            // Refuerzo/puente cálido y breve por encima del contenido.
            if (_overlayMensaje != null)
              Positioned.fill(
                child: _OverlayPaso(mensaje: _overlayMensaje!, sub: _overlaySub),
              ),
            // Aviso de sin conexión: el mayor no se queda con un "Esperando…"
            // eterno; la integradora ve que debe revisar el WiFi.
            if (_sinConexion)
              const Positioned(
                top: 0, left: 0, right: 0,
                child: _BannerSinConexion(),
              ),
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
      case _Fase.elegirSala:
        return _ElegirSala(
          salas: _sesion?.salas ?? const [],
          onElegir: (s) => setState(() {
            _salaElegida = s;
            _fase = _Fase.quienEres;
          }),
        );
      case _Fase.quienEres:
        return _QuienEres(
          sala: _salaElegida,
          // Si hay varias salas, un botón para volver a elegir sala.
          onVolver: (_sesion?.variasSalas ?? false)
              ? () => setState(() {
                    _salaElegida = null;
                    _fase = _Fase.elegirSala;
                  })
              : null,
          onElegir: _elegirse,
        );
      case _Fase.esperandoInicio:
        return _AhoraEmpezamos(nombre: _yo?.aliasInterno ?? '');
      case _Fase.terminado:
        return _Terminado(nombre: _yo?.aliasInterno);
      case _Fase.sinActividades:
        return const _SinActividades();
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
          onLeer: _instancia == null
              ? null
              : () => Tts.instance.hablar(_textoParaLeer(_instancia!)),
          mostrarAvanzar: _puedeAvanzar,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-pantallas del kiosco
// ---------------------------------------------------------------------------

/// Banda superior cuando se pierde la conexión durante la espera. Grande y
/// clara para que la integradora la vea de lejos y revise el WiFi.
class _BannerSinConexion extends StatelessWidget {
  const _BannerSinConexion();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: TrazoColors.coralDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 26),
              SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Sin conexión. Avisa a la responsable para revisar el WiFi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Elegir grupo cuando el centro tiene varias salas abiertas (2 grupos a la
/// vez): la persona toca su grupo y luego su nombre. Lee el título en voz alta
/// al entrar (accesibilidad: mayores con baja visión).
class _ElegirSala extends StatefulWidget {
  final List<SalaActiva> salas;
  final ValueChanged<SalaActiva> onElegir;

  const _ElegirSala({required this.salas, required this.onElegir});

  @override
  State<_ElegirSala> createState() => _ElegirSalaState();
}

class _ElegirSalaState extends State<_ElegirSala> {
  static const _titulo = '¿A qué grupo vienes?';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _leer());
  }

  void _leer() => Tts.instance.hablar('$_titulo Toca tu grupo.');

  String _subtitulo(SalaActiva s) {
    final cuantos = s.participantes.length;
    final personas = cuantos == 1 ? '1 persona' : '$cuantos personas';
    final resp = s.responsable?.trim() ?? '';
    return resp.isEmpty ? personas : 'Con $resp · $personas';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Flexible(
                child: Text(_titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: TrazoColors.ink)),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _leer,
                iconSize: 34,
                tooltip: 'Escuchar',
                icon: const Icon(Icons.volume_up, color: TrazoColors.sageDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Toca tu grupo',
              style: TextStyle(fontSize: 22, color: TrazoColors.sageDark)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 440,
                mainAxisExtent: 150,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
              itemCount: widget.salas.length,
              itemBuilder: (_, i) {
                final s = widget.salas[i];
                final nombre = s.nombre.trim().isEmpty ? 'Grupo' : s.nombre;
                return _BotonSala(
                  nombre: nombre,
                  subtitulo: _subtitulo(s),
                  onTap: () => widget.onElegir(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSala extends StatelessWidget {
  final String nombre;
  final String subtitulo;
  final VoidCallback onTap;

  const _BotonSala(
      {required this.nombre, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrazoColors.sageDark,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(nombre,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitulo,
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuienEres extends StatefulWidget {
  final SalaActiva? sala;
  final ValueChanged<ParticipanteSesion> onElegir;
  final VoidCallback? onVolver;

  const _QuienEres(
      {required this.sala, required this.onElegir, this.onVolver});

  @override
  State<_QuienEres> createState() => _QuienEresState();
}

class _QuienEresState extends State<_QuienEres> {
  @override
  void initState() {
    super.initState();
    // Lee el título al entrar (baja visión): es el paso donde un error mandaría
    // la medición a otra persona.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Tts.instance.hablar('¿Quién eres? Toca tu nombre.'));
  }

  @override
  Widget build(BuildContext context) {
    final sala = widget.sala;
    final onVolver = widget.onVolver;
    final onElegir = widget.onElegir;
    final participantes = sala?.participantes ?? [];
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
          Text(
              onVolver != null && (sala?.nombre.trim().isNotEmpty ?? false)
                  ? '${sala!.nombre} · Toca tu nombre'
                  : 'Toca tu nombre',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, color: TrazoColors.sageDark)),
          if (onVolver != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onVolver,
              icon: const Icon(Icons.arrow_back, size: 22),
              label: const Text('Cambiar de actividad',
                  style: TextStyle(fontSize: 18)),
              style: TextButton.styleFrom(
                  foregroundColor: TrazoColors.sageDark),
            ),
          ],
          const SizedBox(height: 18),
          Expanded(
            child: participantes.isEmpty
                ? const Center(
                    child: Text('Todavía no hay nadie en este grupo.',
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
      // sageDark: el nombre en blanco sobre sage daba ~3.1:1 (falla AA). Leer
      // mal el propio nombre haría que el mayor se midiera como otra persona.
      color: TrazoColors.sageDark,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Encoge el nombre para que SIEMPRE quepa entero: un mayor puede no
            // reconocer su nombre cortado con "…" y elegir mal (mediría a otro).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AhoraEmpezamos extends StatefulWidget {
  final String nombre;
  const _AhoraEmpezamos({required this.nombre});

  @override
  State<_AhoraEmpezamos> createState() => _AhoraEmpezamosState();
}

class _AhoraEmpezamosState extends State<_AhoraEmpezamos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Tts.instance.hablar(
        '¡Hola, ${widget.nombre}! Ahora empezamos.'));
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombre;
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

class _Terminado extends StatefulWidget {
  final String? nombre;
  const _Terminado({this.nombre});

  @override
  State<_Terminado> createState() => _TerminadoState();
}

class _TerminadoState extends State<_Terminado> {
  @override
  void initState() {
    super.initState();
    final n = widget.nombre?.trim() ?? '';
    final saludo = n.isNotEmpty ? '¡Muy bien, $n!' : '¡Muy bien!';
    // Felicitación HABLADA: el cierre del esfuerzo también llega a quien no lee.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => Tts.instance.hablar('$saludo Has terminado.'));
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombre;
    // Cierra con el nombre de la persona (la app ya lo usa en "¿Eres tú, X?"):
    // más cercano y digno al final del esfuerzo.
    final saludo = (nombre != null && nombre.trim().isNotEmpty)
        ? '¡Muy bien, ${nombre.trim()}!'
        : '¡Muy bien!';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 120, color: TrazoColors.coral),
          const SizedBox(height: 24),
          Text(saludo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: TrazoColors.ink)),
          const SizedBox(height: 12),
          const Text('Has terminado. Espera un momento…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, color: TrazoColors.ink)),
          const SizedBox(height: 28),
          // Pulso suave: comunica "sigo contigo", no está colgada.
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: TrazoColors.sage),
          ),
        ],
      ),
    );
  }
}

/// Pantalla-puente breve y cálida entre pasos: micro-refuerzo tras cada
/// actividad y "seguimos" al recibir otra tanda. Sobria y digna, no infantil.
class _OverlayPaso extends StatelessWidget {
  final String mensaje;
  final String? sub;
  const _OverlayPaso({required this.mensaje, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TrazoColors.ivory,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 96, color: TrazoColors.sageDark),
          const SizedBox(height: 20),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: TrazoColors.ink)),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(sub!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, color: TrazoColors.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

/// La cola llegó vacía: normalmente el paciente aún no tiene un plan asignado.
/// Se muestra un aviso sereno (no la felicitación) para que el personal lo
/// resuelva desde el panel, sin dejar al mayor pensando que ya "acabó".
class _SinActividades extends StatelessWidget {
  const _SinActividades();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 96, color: TrazoColors.sage),
            SizedBox(height: 24),
            Text('Todavía no hay actividades preparadas',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: TrazoColors.ink)),
            SizedBox(height: 14),
            Text('Avisa a la responsable para que prepare tu plan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, color: TrazoColors.ink)),
          ],
        ),
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
  final VoidCallback? onLeer; // repetir la instrucción en voz alta
  final bool mostrarAvanzar;

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
    this.onLeer,
    this.mostrarAvanzar = true,
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
            const Icon(Icons.wifi_off, size: 72, color: TrazoColors.coralDark),
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
              if (onLeer != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: TrazoColors.card,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onLeer,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.volume_up,
                            size: 30, color: TrazoColors.sageDark),
                      ),
                    ),
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
        // Único botón grande y amable. Se OCULTA cuando la actividad tiene un
        // paso interno pendiente (p. ej. memoria mientras memorizas): así no hay
        // dos botones a la vez ni se puede saltar la prueba sin medir.
        if (mostrarAvanzar)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // En el último, confirmar para que un toque accidental no cierre
                // la tanda sin querer.
                onPressed: () async {
                  HapticFeedback.selectionClick(); // el botón más usado del kiosco
                  final esUltimo = indice + 1 >= total;
                  if (esUltimo) {
                    final ok = await _confirmarTerminar(context);
                    if (ok) onListo();
                  } else {
                    onListo();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrazoColors.sageDark,
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

/// Confirma antes de cerrar la última actividad de la tanda (evita que un toque
/// accidental termine la sesión de la persona sin querer).
Future<bool> _confirmarTerminar(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      icon: const Icon(Icons.emoji_events,
          color: TrazoColors.sageDark, size: 40),
      title: const Text('¿Has terminado?'),
      content: const Text('Es la última actividad.',
          style: TextStyle(fontSize: 18)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir un poco'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: TrazoColors.sageDark),
          child: const Text('Sí, terminar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Teclado de PIN del personal para salir del kiosco (evita que un mayor salga).
class _PinDialog extends StatefulWidget {
  final String pinCorrecto;
  const _PinDialog({required this.pinCorrecto});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _entrada = '';
  bool _error = false;

  void _pulsa(String d) {
    if (_entrada.length >= widget.pinCorrecto.length) return;
    setState(() {
      _entrada += d;
      _error = false;
    });
    if (_entrada.length == widget.pinCorrecto.length) {
      if (_entrada == widget.pinCorrecto) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = true;
          _entrada = '';
        });
      }
    }
  }

  void _borra() {
    if (_entrada.isNotEmpty) {
      setState(() => _entrada = _entrada.substring(0, _entrada.length - 1));
    }
  }

  Widget _tecla(String d) => SizedBox(
        width: 64,
        height: 60,
        child: OutlinedButton(
          onPressed: () => _pulsa(d),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: TrazoColors.sand)),
          child: Text(d,
              style: const TextStyle(fontSize: 24, color: TrazoColors.ink)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN del personal'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.pinCorrecto.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _entrada.length
                        ? TrazoColors.sageDark
                        : TrazoColors.sand,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_error)
              const Text('PIN incorrecto',
                  style: TextStyle(color: TrazoColors.coralDark)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                  _tecla(d),
                const SizedBox(width: 64),
                _tecla('0'),
                SizedBox(
                  width: 64,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: _borra,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: TrazoColors.sand)),
                    child: const Icon(Icons.backspace_outlined,
                        color: TrazoColors.sageDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
      ],
    );
  }
}
