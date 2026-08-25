import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../models.dart';
import '../theme.dart';

/// Rol MAESTRA: abrir una sala, repartir participantes y seguir en vivo.
class MaestraScreen extends StatefulWidget {
  const MaestraScreen({super.key});

  @override
  State<MaestraScreen> createState() => _MaestraScreenState();
}

class _MaestraScreenState extends State<MaestraScreen> {
  String? _sesionId;
  bool _iniciada = false;
  bool _comprobando = true;

  @override
  void initState() {
    super.initState();
    _recuperarSala();
  }

  /// Si al abrir (o al REFRESCAR) ya hay una sala abierta del centro, se recupera
  /// y se vuelve al monitor: así un refresco accidental no deja a las esclavas
  /// solas ni obliga a abrir otra sala.
  Future<void> _recuperarSala() async {
    try {
      // SU sala (no la de otra compañera): con varias salas por centro no vale
      // coger 'la más reciente'.
      final activa = await ApiClient.instance.miSalaAbierta();
      if (!mounted) return;
      if (activa.haySesion) {
        setState(() {
          _sesionId = activa.sesionId;
          _iniciada = activa.iniciada;
          _comprobando = false;
        });
        return;
      }
    } catch (_) {
      // sin conexión: seguimos a "Abrir sala"
    }
    if (mounted) setState(() => _comprobando = false);
  }

  void _salaAbierta(String sesionId) {
    setState(() => _sesionId = sesionId);
  }

  void _cerrada() {
    setState(() {
      _sesionId = null;
      _iniciada = false;
    });
    Navigator.of(context).maybePop();
  }

  Future<void> _abrirProgramadas() async {
    final sesionId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ProgramadasScreen()),
    );
    if (sesionId != null) _salaAbierta(sesionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: Text(_sesionId == null ? 'Abrir sala' : 'Monitor en vivo'),
        actions: [
          if (_sesionId == null && !_comprobando) ...[
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const _HistorialScreen())),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Historial'),
              style:
                  TextButton.styleFrom(foregroundColor: TrazoColors.sageDark),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _abrirProgramadas,
                icon: const Icon(Icons.event_note),
                label: const Text('Programadas'),
                style: TextButton.styleFrom(
                    foregroundColor: TrazoColors.sageDark),
              ),
            ),
          ],
        ],
      ),
      body: _comprobando
          ? const Center(child: CircularProgressIndicator())
          : _sesionId == null
              ? _AbrirSala(onAbierta: _salaAbierta)
              : _Monitor(
                  sesionId: _sesionId!,
                  iniciada: _iniciada,
                  onIniciada: () => setState(() => _iniciada = true),
                  onCerrada: _cerrada,
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paso 1: abrir sala
// ---------------------------------------------------------------------------

/// Config editable de UN bloque para la sesión (incluido + nº de actividades).
class _ConfigBloque {
  bool incluido;
  int n;
  _ConfigBloque({required this.incluido, required this.n});
}

/// Config por participante para ESTA sesión (nivel + categorías + nº).
/// Se pre-rellena desde su PLAN la primera vez que la maestra la despliega.
class _ConfigParticipante {
  String nivel; // bajo | medio | alto
  final Map<String, _ConfigBloque> bloques;
  bool cargado; // ya se pre-rellenó desde el plan
  bool cargando;
  String? error;

  _ConfigParticipante()
      : nivel = 'medio',
        bloques = {
          for (final k in kBloques.keys)
            k: _ConfigBloque(incluido: false, n: 2),
        },
        cargado = false,
        cargando = false,
        error = null;

  /// Líneas listas para el contrato: `[{bloque, n}]` de los bloques incluidos.
  List<Map<String, dynamic>> get lineas => bloques.entries
      .where((e) => e.value.incluido && e.value.n > 0)
      .map((e) => {'bloque': e.key, 'n': e.value.n})
      .toList();

  bool get tieneConfig => lineas.isNotEmpty;

  int get total => bloques.values
      .where((b) => b.incluido)
      .fold(0, (a, b) => a + b.n);

  /// PLAN ESTÁNDAR: reparte `n` actividades VARIADAS entre todas las categorías.
  /// La app elegirá en cada una las de la dificultad acorde al nivel. Es el modo
  /// ágil por defecto: la integradora solo elige nivel y número.
  void aplicarEstandar(int n) {
    final claves = kBloques.keys.toList();
    final base = n ~/ claves.length;
    final extra = n % claves.length;
    for (var i = 0; i < claves.length; i++) {
      final cb = bloques[claves[i]]!;
      cb.n = base + (i < extra ? 1 : 0);
      cb.incluido = cb.n > 0;
    }
    cargado = true;
  }
}

class _AbrirSala extends StatefulWidget {
  final ValueChanged<String> onAbierta;
  const _AbrirSala({required this.onAbierta});

  @override
  State<_AbrirSala> createState() => _AbrirSalaState();
}

class _AbrirSalaState extends State<_AbrirSala> {
  // Se pre-rellena con el nombre de la maestra logueada: si dos maestras abren
  // sala a la vez, el mayor las distingue ("Grupo de Lucía" vs "Grupo de
  // Marta") en lugar de ver dos botones idénticos.
  final _nombre = TextEditingController(
      text: (ApiClient.instance.nombre?.trim().isNotEmpty ?? false)
          ? 'Grupo de ${ApiClient.instance.nombre!.trim()}'
          : 'Grupo tarde');
  List<UsuarioFinal> _usuarios = [];
  List<Ejercicio> _ejercicios = [];
  final Set<String> _seleccionados = {};
  // Config por participante (solo se crea al seleccionarlo).
  final Map<String, _ConfigParticipante> _configs = {};
  String _tipo = 'individual'; // individual | grupo
  Ejercicio? _ejercicioCompartido;
  bool _cargando = true;
  bool _creando = false;
  String? _error;
  // Plan estándar para todos: nivel + nº de actividades variadas.
  String _nivelEstandar = 'medio';
  int _numEstandar = 16;
  // Programar: guardar la sala para otro día sin abrirla ahora.
  bool _programar = false;
  DateTime? _fecha;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final u = await ApiClient.instance.usuariosDelCentro();
      final e = await ApiClient.instance.ejercicios();
      if (!mounted) return;
      setState(() {
        _usuarios = u;
        _ejercicios = e;
        _cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _cargando = false;
      });
    }
  }

  /// Normaliza el nivel del plan a bajo/medio/alto (por si viene numérico).
  String _normNivel(String? nivel) {
    switch (nivel) {
      case 'bajo':
      case 'medio':
      case 'alto':
        return nivel!;
      default:
        return 'medio';
    }
  }

  /// Pre-rellena la config del participante desde su PLAN (una sola vez).
  Future<void> _prefillDesdePlan(String usuarioId) async {
    final cfg = _configs[usuarioId];
    if (cfg == null || cfg.cargado || cfg.cargando) return;
    setState(() {
      cfg.cargando = true;
      cfg.error = null;
    });
    try {
      final plan = await ApiClient.instance.planUsuario(usuarioId);
      if (!mounted) return;
      setState(() {
        // Nivel: del primer dominio activo del plan.
        final conNivel = plan.firstWhere(
          (l) => l.activo && l.nivel != null,
          orElse: () => plan.isNotEmpty
              ? plan.first
              : PlanLinea(
                  tipo: 'dominio',
                  bloque: null,
                  ejercicioId: null,
                  nivel: 'medio',
                  nPorSesion: 2,
                  orden: 0,
                  activo: true),
        );
        cfg.nivel = _normNivel(conNivel.nivel);
        // Categorías: cada línea de dominio -> {bloque, n_por_sesion}. Si el
        // plan repite un bloque, se suman las cantidades.
        for (final l in plan) {
          if (!l.activo || l.tipo != 'dominio') continue;
          final b = l.bloque;
          if (b == null || !cfg.bloques.containsKey(b)) continue;
          final cb = cfg.bloques[b]!;
          cb.n = cb.incluido ? cb.n + l.nPorSesion : l.nPorSesion;
          cb.incluido = true;
        }
        cfg.cargado = true;
        cfg.cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        cfg.error = err.toString();
        cfg.cargando = false;
      });
    }
  }

  /// Aviso (no bloqueante) si otra facilitadora ya tiene una sala EN VIVO
  /// abierta en el centro, para no duplicar salas sin querer. Devuelve true si
  /// la maestra decide abrir otra igualmente.
  Future<bool> _avisarSiHaySalaAbierta() async {
    List<SesionHistorial> abiertas;
    try {
      abiertas = await ApiClient.instance
          .sesionesAnteriores(estado: 'abierta', limit: 10);
    } catch (_) {
      return true; // si no se puede comprobar, no estorbamos
    }
    if (abiertas.isEmpty || !mounted) return true;
    final s = abiertas.first;
    final quien = (s.staffNombre != null && s.staffNombre!.isNotEmpty)
        ? s.staffNombre!
        : 'otra persona';
    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ya hay una sala abierta'),
        content: Text(
          abiertas.length == 1
              ? 'Hay una sala abierta ("${s.nombre}", ${s.nParticipantes} personas) '
                  'iniciada por $quien. ¿Quieres abrir otra igualmente?'
              : 'Hay ${abiertas.length} salas abiertas en el centro. '
                  '¿Quieres abrir otra igualmente?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir otra')),
        ],
      ),
    );
    return continuar ?? false;
  }

  Future<void> _abrir() async {
    if (_seleccionados.isEmpty || _nombre.text.trim().isEmpty) return;
    // Solo para salas en vivo: si hay otra abierta, confirmamos antes.
    if (!_programar) {
      final seguir = await _avisarSiHaySalaAbierta();
      if (!seguir || !mounted) return;
    }
    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      // Config por participante: solo los que la maestra ajustó (cargado) y
      // tienen al menos una categoría. El resto va sin config (usa su plan).
      final configs = <Map<String, dynamic>>[];
      for (final uid in _seleccionados) {
        final cfg = _configs[uid];
        if (cfg != null && cfg.cargado && cfg.tieneConfig) {
          configs.add({
            'usuario_final_id': uid,
            'nivel': cfg.nivel,
            'lineas': cfg.lineas,
          });
        }
      }
      await ApiClient.instance.crearSesion(
        tipo: _tipo,
        nombre: _nombre.text.trim(),
        modo: _tipo,
        ejercicioCompartidoId:
            _tipo == 'grupo' ? _ejercicioCompartido?.id : null,
        participantes: _seleccionados.toList(),
        configs: configs,
        programar: _programar,
        programadaPara:
            _programar && _fecha != null ? _fmtFecha(_fecha!) : null,
      ).then((sesionId) {
        if (!mounted) return;
        if (_programar) {
          _confirmarProgramada();
        } else {
          widget.onAbierta(sesionId);
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _creando = false;
      });
    }
  }

  String _fmtFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy.add(const Duration(days: 1)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'Día de la sesión',
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _confirmarProgramada() async {
    setState(() {
      _creando = false;
      _seleccionados.clear();
      _configs.clear();
      _programar = false;
      _fecha = null;
    });
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.event_available,
            color: TrazoColors.sageDark, size: 40),
        title: const Text('Sesión guardada'),
        content: const Text(
            'La abrirás el día señalado desde "Sesiones programadas": solo '
            'tendrás que abrirla y repartir las tablets.'),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido')),
        ],
      ),
    );
  }

  /// Aplica el PLAN ESTÁNDAR (nivel + nº variadas) a TODOS los seleccionados.
  /// El modo ágil: un toque y todos listos; luego se puede afinar por persona.
  void _aplicarEstandarTodos() {
    setState(() {
      for (final uid in _seleccionados) {
        final cfg = _configs.putIfAbsent(uid, () => _ConfigParticipante());
        cfg.nivel = _nivelEstandar;
        cfg.aplicarEstandar(_numEstandar);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Plan estándar aplicado a ${_seleccionados.length} personas '
            '($_numEstandar actividades, nivel $_nivelEstandar).')));
  }

  void _toggleParticipante(String uid, bool sel) {
    setState(() {
      if (sel) {
        _seleccionados.add(uid);
        _configs.putIfAbsent(uid, () => _ConfigParticipante());
      } else {
        _seleccionados.remove(uid);
        _configs.remove(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _usuarios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudo cargar:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TrazoColors.coralDark)),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Nombre de la sala',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: TrazoColors.sageDark)),
            const SizedBox(height: 8),
            TextField(
              controller: _nombre,
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 22),
            const Text('Modo',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: TrazoColors.sageDark)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'individual',
                    label: Text('Individual'),
                    icon: Icon(Icons.person)),
                ButtonSegment(
                    value: 'grupo',
                    label: Text('Grupo'),
                    icon: Icon(Icons.groups)),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            if (_tipo == 'grupo') ...[
              const SizedBox(height: 18),
              const Text('Ejercicio compartido (opcional)',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.sageDark)),
              const SizedBox(height: 8),
              DropdownButtonFormField<Ejercicio>(
                initialValue: _ejercicioCompartido,
                isExpanded: true,
                decoration:
                    const InputDecoration(border: OutlineInputBorder()),
                items: _ejercicios
                    .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.nombre}  ·  ${etiquetaBloque(e.bloque)}',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _ejercicioCompartido = v),
              ),
            ],
            const SizedBox(height: 22),
            Text('Participantes (${_seleccionados.length})',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: TrazoColors.sageDark)),
            const SizedBox(height: 8),
            if (_usuarios.isEmpty)
              // Centro recién creado: sin personas, seleccionar es imposible y el
              // botón "Abrir sala" queda deshabilitado sin explicación. Se guía.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TrazoColors.sand.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aún no hay personas en el centro. Pídele a administración '
                  'que las dé de alta en el panel (sección Personas); luego '
                  'podrás seleccionarlas aquí y abrir la sala.',
                  style: TextStyle(fontSize: 16, color: TrazoColors.ink),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _usuarios.map((u) {
                  final sel = _seleccionados.contains(u.id);
                  return FilterChip(
                    label: Text(u.aliasInterno,
                        style: const TextStyle(fontSize: 18)),
                    selected: sel,
                    showCheckmark: true,
                    selectedColor: TrazoColors.sage.withValues(alpha: 0.30),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    onSelected: (v) => _toggleParticipante(u.id, v),
                  );
                }).toList(),
              ),
            // PLAN ESTÁNDAR PARA TODOS: lo ágil. La integradora solo elige nivel
            // y número; la app arma actividades variadas y medibles de la
            // dificultad adecuada. No hace falta elegir actividades a mano.
            if (_tipo == 'individual' && _seleccionados.isNotEmpty) ...[
              const SizedBox(height: 22),
              Card(
                color: TrazoColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: TrazoColors.sage, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Plan estándar para todos',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: TrazoColors.ink)),
                      const SizedBox(height: 2),
                      const Text(
                          'Elige nivel y número; la app pone actividades '
                          'variadas y medibles. Luego puedes afinar por persona.',
                          style: TextStyle(
                              fontSize: 13, color: TrazoColors.sageDark)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Nivel  ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: TrazoColors.sageDark)),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'bajo', label: Text('Bajo')),
                                ButtonSegment(
                                    value: 'medio', label: Text('Medio')),
                                ButtonSegment(value: 'alto', label: Text('Alto')),
                              ],
                              selected: {_nivelEstandar},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) =>
                                  setState(() => _nivelEstandar = s.first),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Actividades  ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: TrazoColors.sageDark)),
                          IconButton(
                            iconSize: 30,
                            color: TrazoColors.coralDark,
                            onPressed: _numEstandar > 4
                                ? () => setState(() => _numEstandar -= 2)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_numEstandar',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: TrazoColors.ink)),
                          IconButton(
                            iconSize: 30,
                            color: TrazoColors.sageDark,
                            onPressed: _numEstandar < 30
                                ? () => setState(() => _numEstandar += 2)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _aplicarEstandarTodos,
                            style: FilledButton.styleFrom(
                                backgroundColor: TrazoColors.sageDark),
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text('Aplicar a todos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Ajustar actividad de cada persona (opcional)',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.sageDark)),
              const SizedBox(height: 4),
              const Text(
                  'Por defecto usa su plan. Despliega para cambiar nivel y '
                  'categorías solo para hoy.',
                  style:
                      TextStyle(fontSize: 14, color: TrazoColors.sageDark)),
              const SizedBox(height: 10),
              ..._usuarios.where((u) => _seleccionados.contains(u.id)).map(
                    (u) => _ConfigParticipantePanel(
                      nombre: u.aliasInterno,
                      config: _configs[u.id]!,
                      onExpandir: () => _prefillDesdePlan(u.id),
                      onCambio: () => setState(() {}),
                    ),
                  ),
            ],
            const SizedBox(height: 22),
            // Programar para otro día (dejar la sala lista, sin abrirla ahora).
            Card(
              color: TrazoColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: TrazoColors.sand),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _programar,
                    activeThumbColor: TrazoColors.sage,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Guardar para otro día',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Deja la sala configurada; la abrirás ese día y solo '
                        'repartirás las tablets.'),
                    onChanged: (v) => setState(() => _programar = v),
                  ),
                  if (_programar)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: TrazoColors.sageDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fecha == null
                                  ? 'Sin fecha (opcional)'
                                  : 'Día: ${_fmtFecha(_fecha!)}',
                              style: const TextStyle(
                                  fontSize: 16, color: TrazoColors.ink),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _elegirFecha,
                            icon: const Icon(Icons.edit_calendar),
                            label: Text(_fecha == null
                                ? 'Elegir día'
                                : 'Cambiar'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: TrazoColors.coralDark)),
              ),
            ElevatedButton.icon(
              onPressed: (_creando ||
                      _seleccionados.isEmpty ||
                      _nombre.text.trim().isEmpty)
                  ? null
                  : _abrir,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              icon: _creando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(_programar ? Icons.event_available : Icons.meeting_room),
              label: Text(_programar ? 'Guardar para otro día' : 'Abrir sala'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel expandible con la config de UN participante para la sesión.
class _ConfigParticipantePanel extends StatelessWidget {
  final String nombre;
  final _ConfigParticipante config;
  final VoidCallback onExpandir;
  final VoidCallback onCambio;

  const _ConfigParticipantePanel({
    required this.nombre,
    required this.config,
    required this.onExpandir,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final resumen = config.cargado
        ? '${config.nivel} · ${config.lineas.length} categorías'
        : 'Usa su plan';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: TrazoColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TrazoColors.sand),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(nombre,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.ink)),
          subtitle: Text(resumen,
              style: const TextStyle(color: TrazoColors.sageDark)),
          onExpansionChanged: (abierto) {
            if (abierto) onExpandir();
          },
          children: [
            if (config.cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (config.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No se pudo cargar su plan: ${config.error}',
                    style: const TextStyle(color: TrazoColors.coralDark)),
              )
            else ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Nivel',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: TrazoColors.sageDark)),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bajo', label: Text('Bajo')),
                  ButtonSegment(value: 'medio', label: Text('Medio')),
                  ButtonSegment(value: 'alto', label: Text('Alto')),
                ],
                selected: {config.nivel},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  config.nivel = s.first;
                  onCambio();
                },
                style: const ButtonStyle(
                  textStyle: WidgetStatePropertyAll(
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Categorías y nº de actividades',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: TrazoColors.sageDark)),
              ),
              const SizedBox(height: 8),
              ...kBloques.entries.map((entry) {
                final cb = config.bloques[entry.key]!;
                return _FilaBloque(
                  etiqueta: entry.value,
                  cfg: cb,
                  onCambio: onCambio,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de un bloque: incluir/excluir + stepper de nº de actividades.
class _FilaBloque extends StatelessWidget {
  final String etiqueta;
  final _ConfigBloque cfg;
  final VoidCallback onCambio;

  const _FilaBloque({
    required this.etiqueta,
    required this.cfg,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: cfg.incluido,
            activeColor: TrazoColors.sage,
            onChanged: (v) {
              cfg.incluido = v ?? false;
              onCambio();
            },
          ),
          Expanded(
            child: Text(etiqueta,
                style: TextStyle(
                    fontSize: 18,
                    color: cfg.incluido
                        ? TrazoColors.ink
                        : TrazoColors.sageDark)),
          ),
          if (cfg.incluido) ...[
            IconButton(
              iconSize: 28,
              color: TrazoColors.coralDark,
              onPressed: cfg.n > 1
                  ? () {
                      cfg.n -= 1;
                      onCambio();
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 32,
              child: Text('${cfg.n}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: TrazoColors.ink)),
            ),
            IconButton(
              iconSize: 28,
              color: TrazoColors.sageDark,
              onPressed: cfg.n < 20
                  ? () {
                      cfg.n += 1;
                      onCambio();
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paso 2: monitor en vivo
// ---------------------------------------------------------------------------

class _Monitor extends StatefulWidget {
  final String sesionId;
  final bool iniciada;
  final VoidCallback onIniciada;
  final VoidCallback onCerrada;

  const _Monitor({
    required this.sesionId,
    required this.iniciada,
    required this.onIniciada,
    required this.onCerrada,
  });

  @override
  State<_Monitor> createState() => _MonitorState();
}

class _MonitorState extends State<_Monitor> {
  Timer? _timer;
  List<FichaLive> _fichas = [];
  bool _cargando = true;
  String? _error;
  bool _iniciando = false;
  final Set<String> _marcando = {};
  final Set<String> _enviandoMas = {};
  // Ticks de polling fallidos seguidos: a partir de 3 (~9s) se avisa a la
  // facilitadora de que revise el WiFi (si no, cree que nadie avanza).
  int _fallosSeguidos = 0;
  bool get _sinConexion => _fallosSeguidos >= 3;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(
        const Duration(seconds: 3), (_) => _poll(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll({bool silencioso = false}) async {
    try {
      final f = await ApiClient.instance.sesionLive(widget.sesionId);
      if (!mounted) return;
      // Orden SIEMPRE estable (alfabético): la rejilla NUNCA se reordena entre
      // refrescos. Reordenar por "atención" hacía que una tarjeta se moviera
      // bajo el dedo de la maestra justo al pulsar y el resultado clínico (o el
      // "le ayudé") cayera en OTRA persona. La atención se señala con el borde
      // coral y el aviso de "atascado", no moviendo las tarjetas.
      f.sort((a, b) => a.aliasInterno.compareTo(b.aliasInterno));
      setState(() {
        _fichas = f;
        _cargando = false;
        _error = null;
        _fallosSeguidos = 0;
      });
    } catch (err) {
      if (!mounted) return;
      _fallosSeguidos++;
      if (!silencioso) setState(() => _error = err.toString());
      setState(() => _cargando = false);
    }
  }

  Future<void> _iniciar() async {
    setState(() => _iniciando = true);
    try {
      await ApiClient.instance.iniciarSesion(widget.sesionId);
      widget.onIniciada();
    } catch (err) {
      _snack('No se pudo iniciar: $err');
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _cerrar() async {
    // Aviso si alguien SIGUE trabajando (no ha terminado su tanda): evita cortar
    // la actividad a media persona sin darse cuenta.
    final trabajando =
        _fichas.where((f) => !f.terminado && f.totalActual > 0).length;
    final aviso = trabajando > 0
        ? (trabajando == 1
            ? 'Hay 1 persona todavía haciendo actividades. Si finalizas, se le cortará.'
            : 'Hay $trabajando personas todavía haciendo actividades. Si finalizas, se les cortará.')
        : '¿Terminamos la sesión de todos?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar la sesión'),
        content: Text(aviso, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(trabajando > 0 ? 'Esperar' : 'No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: trabajando > 0
                  ? ElevatedButton.styleFrom(backgroundColor: TrazoColors.coralDark)
                  : null,
              child: const Text('Sí, finalizar')),
        ],
      ),
    );
    if (ok != true) return;
    // Pide el resumen ANTES de cerrar y lo muestra: cómo fue cada uno.
    ResumenSesion? resumen;
    try {
      resumen = await ApiClient.instance.resumenSesion(widget.sesionId);
    } catch (_) {}
    try {
      await ApiClient.instance.cerrarSesion(widget.sesionId);
    } catch (err) {
      _snack('No se pudo finalizar: $err');
      return;
    }
    if (!mounted) return;
    if (resumen != null && resumen.fichas.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ResumenSesionDialog(resumen: resumen!),
      );
    }
    widget.onCerrada();
  }

  /// Marca/desmarca que la integradora AYUDÓ en la última actividad (capa
  /// secundaria: no cambia el resultado, que lo pone la app sola).
  Future<void> _marcarAyuda(FichaLive f, bool conAyuda) async {
    final id = f.ultimoIntentoId;
    if (id == null) {
      _snack('${f.aliasInterno} aún no tiene ninguna actividad.');
      return;
    }
    setState(() => _marcando.add(id));
    try {
      await ApiClient.instance.marcarAyudaIntento(id, conAyuda);
      await _poll(silencioso: true);
    } catch (err) {
      _snack('No se pudo marcar: $err');
    } finally {
      if (mounted) setState(() => _marcando.remove(id));
    }
  }

  /// Cola de revisión inline: la integradora fija el resultado de una actividad
  /// que la app no supo juzgar (sin_valorar) -> logrado / parcial / no_logrado.
  Future<void> _marcarResultado(FichaLive f, String resultado) async {
    final id = f.ultimoIntentoId;
    if (id == null) return;
    setState(() => _marcando.add(id));
    try {
      await ApiClient.instance.marcarResultadoIntento(id, resultado);
      await _poll(silencioso: true);
    } catch (err) {
      _snack('No se pudo marcar: $err');
    } finally {
      if (mounted) setState(() => _marcando.remove(id));
    }
  }

  /// Abre el diálogo para revisar/marcar las últimas 3-4 actividades de la
  /// persona de golpe (lo que pedía Laura: no solo la última).
  Future<void> _revisarLote(FichaLive f) async {
    List<IntentoRevision> intentos;
    try {
      intentos = await ApiClient.instance.ultimosIntentos(
          widget.sesionId, f.usuarioFinalId, limit: 4);
    } catch (err) {
      _snack('No se pudieron cargar las últimas: $err');
      return;
    }
    if (!mounted) return;
    if (intentos.isEmpty) {
      _snack('${f.aliasInterno} aún no tiene actividades.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _RevisionLoteDialog(
        alias: f.aliasInterno,
        intentos: intentos,
      ),
    );
    await _poll(silencioso: true);
  }

  Future<void> _enviarMas(FichaLive f) async {
    // La maestra elige QUÉ mandar en la nueva tanda (categorías + nº + nivel) o
    // repite lo mismo. Así no se le manda otra vez casi lo mismo sin querer.
    final res = await showDialog<_MasResult>(
      context: context,
      builder: (_) =>
          _EnviarMasDialog(nombre: f.aliasInterno, usuarioFinalId: f.usuarioFinalId),
    );
    if (res == null) return;
    final uid = f.usuarioFinalId;
    setState(() => _enviandoMas.add(uid));
    try {
      if (res.repetir) {
        await ApiClient.instance.enviarMas(widget.sesionId, uid);
      } else if (res.ejercicios.isNotEmpty) {
        await ApiClient.instance.enviarMas(widget.sesionId, uid,
            nivel: res.nivel, ejercicios: res.ejercicios);
      } else {
        await ApiClient.instance.enviarMas(widget.sesionId, uid,
            nivel: res.nivel, lineas: res.lineas);
      }
      _snack('Nueva tanda enviada a ${f.aliasInterno}.');
      await _poll(silencioso: true);
    } catch (err) {
      _snack('No se pudo enviar más: $err');
    } finally {
      if (mounted) setState(() => _enviandoMas.remove(uid));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Aviso de WiFi caído: si el monitor deja de recibir datos, la
        // facilitadora ve que debe revisar la conexión (no que nadie avanza).
        if (_sinConexion)
          Container(
            width: double.infinity,
            color: TrazoColors.coralDark,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                      'Sin conexión: revisa el WiFi. Los datos pueden estar sin actualizar.',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _fichas.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Error: $_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: TrazoColors.coralDark)),
                      ),
                    )
                  : _fichas.isEmpty
                      ? const Center(
                          child: Text('Sin participantes en la sala.'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            mainAxisExtent: 292,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _fichas.length,
                          itemBuilder: (_, i) {
                            final f = _fichas[i];
                            return _FichaCard(
                              key: ValueKey(f.usuarioFinalId),
                              ficha: f,
                              marcando: f.ultimoIntentoId != null &&
                                  _marcando.contains(f.ultimoIntentoId),
                              puedeMarcar: f.ultimoIntentoId != null,
                              enviandoMas:
                                  _enviandoMas.contains(f.usuarioFinalId),
                              onAyuda: (v) => _marcarAyuda(f, v),
                              onResultado: (r) => _marcarResultado(f, r),
                              onEnviarMas: () => _enviarMas(f),
                              onRevisar: () => _revisarLote(f),
                            );
                          },
                        ),
        ),
        _BarraControl(
          iniciada: widget.iniciada,
          iniciando: _iniciando,
          onIniciar: _iniciar,
          onCerrar: _cerrar,
        ),
      ],
    );
  }
}

/// Resultado del diálogo "Enviar más": repetir lo mismo, o una config nueva.
class _MasResult {
  final bool repetir;
  final String? nivel;
  final List<Map<String, dynamic>> lineas;
  // Actividades CONCRETAS a mandar (elegidas por la maestra o propuestas por la
  // app y aceptadas). Van primero en la cola de la persona (origen 'en_vivo').
  final List<String> ejercicios;
  const _MasResult.repetir()
      : repetir = true,
        nivel = null,
        lineas = const [],
        ejercicios = const [];
  const _MasResult.config(this.nivel, this.lineas)
      : repetir = false,
        ejercicios = const [];
  const _MasResult.concretas(this.nivel, this.ejercicios)
      : repetir = false,
        lineas = const [];
}

/// Diálogo para elegir QUÉ mandar en la nueva tanda: categorías + nº + nivel,
/// o repetir lo mismo. Evita mandar otra vez casi los mismos ejercicios.
enum _ModoMas { areas, propone, elige }

class _EnviarMasDialog extends StatefulWidget {
  final String nombre;
  final String usuarioFinalId;
  const _EnviarMasDialog({required this.nombre, required this.usuarioFinalId});

  @override
  State<_EnviarMasDialog> createState() => _EnviarMasDialogState();
}

class _EnviarMasDialogState extends State<_EnviarMasDialog> {
  String _nivel = 'medio';
  _ModoMas _modo = _ModoMas.areas;

  // Modo "áreas": categorías + nº (comportamiento clásico).
  final Map<String, _ConfigBloque> _bloques = {
    for (final k in kBloques.keys) k: _ConfigBloque(incluido: false, n: 2),
  };
  List<Map<String, dynamic>> get _lineas => _bloques.entries
      .where((e) => e.value.incluido && e.value.n > 0)
      .map((e) => {'bloque': e.key, 'n': e.value.n})
      .toList();

  // Modo "la app propone": actividades frescas que sugiere el motor.
  List<ColaItem>? _propuestas;
  bool _cargandoPropuesta = false;
  String? _errorCarga;
  final Set<String> _propMarcadas = {};

  // Modo "elijo yo": buscador del catálogo.
  List<Ejercicio>? _catalogo;
  bool _cargandoCatalogo = false;
  String _busqueda = '';
  final Set<String> _eligMarcadas = {};

  Future<void> _cargarPropuesta() async {
    if (_propuestas != null || _cargandoPropuesta) return;
    setState(() {
      _cargandoPropuesta = true;
      _errorCarga = null;
    });
    try {
      final p = await ApiClient.instance.propuesta(widget.usuarioFinalId, n: 5);
      if (!mounted) return;
      setState(() {
        _propuestas = p;
        // Vienen pre-marcadas: aceptar tal cual es un toque, quitar es fácil.
        _propMarcadas
          ..clear()
          ..addAll(p.map((e) => e.ejercicioId));
      });
    } catch (e) {
      if (mounted) setState(() => _errorCarga = '$e');
    } finally {
      if (mounted) setState(() => _cargandoPropuesta = false);
    }
  }

  Future<void> _cargarCatalogo() async {
    if (_catalogo != null || _cargandoCatalogo) return;
    setState(() => _cargandoCatalogo = true);
    try {
      final c = await ApiClient.instance.ejercicios();
      if (!mounted) return;
      c.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      setState(() => _catalogo = c);
    } catch (e) {
      if (mounted) setState(() => _errorCarga = '$e');
    } finally {
      if (mounted) setState(() => _cargandoCatalogo = false);
    }
  }

  void _cambiarModo(_ModoMas m) {
    setState(() => _modo = m);
    if (m == _ModoMas.propone) _cargarPropuesta();
    if (m == _ModoMas.elige) _cargarCatalogo();
  }

  bool get _puedeEnviar {
    switch (_modo) {
      case _ModoMas.areas:
        return _lineas.isNotEmpty;
      case _ModoMas.propone:
        return _propMarcadas.isNotEmpty;
      case _ModoMas.elige:
        return _eligMarcadas.isNotEmpty;
    }
  }

  _MasResult _resultado() {
    switch (_modo) {
      case _ModoMas.areas:
        return _MasResult.config(_nivel, _lineas);
      case _ModoMas.propone:
        final ids = (_propuestas ?? [])
            .map((e) => e.ejercicioId)
            .where(_propMarcadas.contains)
            .toList();
        return _MasResult.concretas(_nivel, ids);
      case _ModoMas.elige:
        return _MasResult.concretas(_nivel, _eligMarcadas.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enviar más a ${widget.nombre}'),
      content: SizedBox(
        width: 480,
        height: 470,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // De dónde sale la nueva tanda: por áreas, que la proponga la app, o
            // elegir yo una actividad concreta.
            SegmentedButton<_ModoMas>(
              segments: const [
                ButtonSegment(
                    value: _ModoMas.areas,
                    label: Text('Áreas'),
                    icon: Icon(Icons.category_outlined)),
                ButtonSegment(
                    value: _ModoMas.propone,
                    label: Text('La app propone'),
                    icon: Icon(Icons.auto_awesome)),
                ButtonSegment(
                    value: _ModoMas.elige,
                    label: Text('Elijo yo'),
                    icon: Icon(Icons.touch_app_outlined)),
              ],
              selected: {_modo},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _cambiarModo(s.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Nivel',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: TrazoColors.sageDark)),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bajo', label: Text('Bajo')),
                  ButtonSegment(value: 'medio', label: Text('Medio')),
                  ButtonSegment(value: 'alto', label: Text('Alto')),
                ],
                selected: {_nivel},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _nivel = s.first),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(child: _cuerpo()),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () =>
                Navigator.pop(context, const _MasResult.repetir()),
            child: const Text('Repetir lo mismo')),
        ElevatedButton.icon(
          onPressed:
              _puedeEnviar ? () => Navigator.pop(context, _resultado()) : null,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Enviar'),
        ),
      ],
    );
  }

  Widget _cuerpo() {
    switch (_modo) {
      case _ModoMas.areas:
        return _cuerpoAreas();
      case _ModoMas.propone:
        return _cuerpoPropone();
      case _ModoMas.elige:
        return _cuerpoElige();
    }
  }

  Widget _cuerpoAreas() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Elige categorías y cuántas de cada una.',
              style: TextStyle(fontSize: 14, color: TrazoColors.sageDark)),
          const SizedBox(height: 8),
          ...kBloques.entries.map((entry) => _FilaBloque(
                etiqueta: entry.value,
                cfg: _bloques[entry.key]!,
                onCambio: () => setState(() {}),
              )),
        ],
      ),
    );
  }

  Widget _cuerpoPropone() {
    if (_cargandoPropuesta) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCarga != null) {
      return Center(
          child: Text('No se pudo cargar la propuesta.\n$_errorCarga',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TrazoColors.ink)));
    }
    final props = _propuestas ?? [];
    if (props.isEmpty) {
      return const Center(
          child: Text(
              'La app no tiene actividades frescas que proponer ahora mismo. '
              'Revisa el plan de la persona.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TrazoColors.ink)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('La app sugiere estas actividades frescas. Desmarca las que '
            'no quieras.',
            style: TextStyle(fontSize: 14, color: TrazoColors.sageDark)),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: props
                .map((it) => CheckboxListTile(
                      value: _propMarcadas.contains(it.ejercicioId),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _propMarcadas.add(it.ejercicioId);
                        } else {
                          _propMarcadas.remove(it.ejercicioId);
                        }
                      }),
                      title: Text(it.nombre),
                      subtitle: Text(etiquetaBloque(it.bloque)),
                      dense: true,
                      activeColor: TrazoColors.sageDark,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _cuerpoElige() {
    if (_cargandoCatalogo) {
      return const Center(child: CircularProgressIndicator());
    }
    final cat = _catalogo ?? [];
    final q = _busqueda.trim().toLowerCase();
    final filtrado = q.isEmpty
        ? cat
        : cat
            .where((e) =>
                e.nombre.toLowerCase().contains(q) ||
                etiquetaBloque(e.bloque).toLowerCase().contains(q))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Busca una actividad…',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtrado.isEmpty
              ? const Center(child: Text('Sin resultados.'))
              : ListView(
                  children: filtrado
                      .map((e) => CheckboxListTile(
                            value: _eligMarcadas.contains(e.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _eligMarcadas.add(e.id);
                              } else {
                                _eligMarcadas.remove(e.id);
                              }
                            }),
                            title: Text(e.nombre),
                            subtitle: Text(etiquetaBloque(e.bloque)),
                            dense: true,
                            activeColor: TrazoColors.sageDark,
                          ))
                      .toList(),
                ),
        ),
        if (_eligMarcadas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${_eligMarcadas.length} elegida(s)',
                style:
                    const TextStyle(fontSize: 13, color: TrazoColors.sageDark)),
          ),
      ],
    );
  }
}

class _FichaCard extends StatelessWidget {
  final FichaLive ficha;
  final bool marcando;
  final bool puedeMarcar;
  final bool enviandoMas;
  final ValueChanged<bool> onAyuda;        // marcar/desmarcar "le ayudé"
  final ValueChanged<String> onResultado;  // cola de revisión (logrado/parcial/no_logrado)
  final VoidCallback onEnviarMas;
  final VoidCallback onRevisar;            // revisar/marcar en lote las últimas

  const _FichaCard({
    super.key,
    required this.ficha,
    required this.marcando,
    required this.puedeMarcar,
    required this.enviandoMas,
    required this.onAyuda,
    required this.onResultado,
    required this.onEnviarMas,
    required this.onRevisar,
  });

  ({String texto, Color color, IconData icono}) get _estado {
    if (ficha.terminado) {
      return (
        texto: 'Terminó ✓',
        color: TrazoColors.sageDark,
        icono: Icons.check_circle
      );
    }
    if (ficha.atascado) {
      return (
        texto: 'Atascado',
        color: TrazoColors.coralDark,
        icono: Icons.error_outline
      );
    }
    switch (ficha.ultimoEstado) {
      case 'logrado':
        return (
          texto: 'Lo logró',
          color: TrazoColors.sageDark,
          icono: Icons.check_circle
        );
      case 'parcial':
        return (
          texto: 'A medias',
          color: TrazoColors.coralDark,
          icono: Icons.timelapse
        );
      case 'no_logrado':
        return (
          texto: 'No lo logró',
          color: TrazoColors.coralDark,
          icono: Icons.close
        );
      case 'sin_valorar':
        // La app no la pudo juzgar (respuesta abierta, trazo dudoso o no tocó):
        // revísala abajo.
        return (
          texto: 'Revisar: ¿cómo fue?',
          color: TrazoColors.sageDark,
          icono: Icons.rate_review_outlined
        );
      default:
        return (
          texto: 'Trabajando',
          color: TrazoColors.sage,
          icono: Icons.edit
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _estado;
    final terminado = ficha.terminado;
    // Resaltado en verde/sage cuando la persona ha terminado su tanda.
    final bordeColor = terminado
        ? TrazoColors.sage
        : (ficha.atascado ? TrazoColors.coral : TrazoColors.sand);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: terminado
            ? TrazoColors.sage.withValues(alpha: 0.14)
            : TrazoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bordeColor,
          width: (terminado || ficha.atascado) ? 3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ficha.aliasInterno,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: TrazoColors.ink)),
              ),
              // La ronda nace en 1; solo se muestra el badge a partir de la 2ª
              // (cuando la maestra ya envió "más"), con el número real.
              if (ficha.ronda > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: TrazoColors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Ronda ${ficha.ronda}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: TrazoColors.sageDark)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(e.icono, size: 18, color: e.color),
              const SizedBox(width: 6),
              Text(e.texto,
                  style: TextStyle(
                      color: e.color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            terminado
                ? 'Esperando a los demás'
                : (ficha.ejercicioActual ?? 'Sin ejercicio'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TrazoColors.sageDark),
          ),
          // Posición dentro de su tanda (ej. "Actividad 2 de 5"), en vivo.
          if (!terminado && ficha.totalActual > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Actividad ${ficha.posActual} de ${ficha.totalActual}',
                style: const TextStyle(
                    fontSize: 12, color: TrazoColors.sageDark),
              ),
            ),
          const Spacer(),
          // La app corrige el resultado sola. La integradora solo interviene:
          //  · si la app no supo juzgarla (sin_valorar) -> dice cómo fue.
          //  · marca "le ayudé" cuando de verdad intervino (capa aparte).
          if (puedeMarcar && ficha.ultimoEstado == 'sin_valorar')
            Row(
              children: [
                _seg('Logró', 'logrado', Icons.check_circle, TrazoColors.sage),
                _seg('A medias', 'parcial', Icons.timelapse,
                    TrazoColors.coralDark),
                _seg('No pudo', 'no_logrado', Icons.close,
                    const Color(0xFF8A6E52)),
              ],
            ),
          if (puedeMarcar) ...[
            const SizedBox(height: 6),
            _BotonAyuda(
              activo: ficha.ultimoConAyuda,
              cargando: marcando,
              onTap: () => onAyuda(!ficha.ultimoConAyuda),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRevisar,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Revisar últimas'),
                style: TextButton.styleFrom(
                    foregroundColor: TrazoColors.sageDark,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
              ),
            ),
          ],
          if (terminado) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: enviandoMas ? null : onEnviarMas,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrazoColors.sageDark,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: enviandoMas
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 20),
                label: const Text('Enviar más'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Un botón de la cola de revisión ("¿cómo fue?"): fija el resultado de una
  /// actividad que la app no supo juzgar. Objetivo táctil amplio.
  Widget _seg(String label, String valor, IconData icono, Color color) {
    final activo = ficha.ultimoEstado == valor;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          onPressed: (marcando || !puedeMarcar) ? null : () => onResultado(valor),
          style: OutlinedButton.styleFrom(
            backgroundColor: activo ? color.withValues(alpha: 0.16) : null,
            foregroundColor: activo ? color : TrazoColors.ink,
            side: BorderSide(
                color: activo ? color : TrazoColors.sand,
                width: activo ? 2.2 : 1),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            minimumSize: const Size(0, 60),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 22),
              const SizedBox(height: 3),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, height: 1.05)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón "Le ayudé": la integradora lo marca cuando de verdad intervino en la
/// última actividad de esa persona. Toggle (se puede desmarcar si se equivoca).
class _BotonAyuda extends StatelessWidget {
  final bool activo;
  final bool cargando;
  final VoidCallback onTap;

  const _BotonAyuda(
      {required this.activo, required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: cargando ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              activo ? TrazoColors.coralDark.withValues(alpha: 0.16) : null,
          foregroundColor: activo ? TrazoColors.coralDark : TrazoColors.sageDark,
          side: BorderSide(
              color: activo ? TrazoColors.coralDark : TrazoColors.sand,
              width: activo ? 2 : 1),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(activo ? Icons.back_hand : Icons.back_hand_outlined, size: 18),
        label: Text(activo ? 'Le ayudé ✓' : 'Le ayudé',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Diálogo para marcar en LOTE las últimas actividades de una persona: marcar
/// "le ayudé" en cualquiera, y resolver las que quedaron sin valorar.
class _RevisionLoteDialog extends StatefulWidget {
  final String alias;
  final List<IntentoRevision> intentos;
  const _RevisionLoteDialog({required this.alias, required this.intentos});

  @override
  State<_RevisionLoteDialog> createState() => _RevisionLoteDialogState();
}

class _RevisionLoteDialogState extends State<_RevisionLoteDialog> {
  late final List<IntentoRevision> _items = List.of(widget.intentos);
  final Set<String> _ocupado = {};

  void _reemplaza(int i, IntentoRevision nuevo) {
    setState(() => _items[i] = nuevo);
  }

  Future<void> _ayuda(int i, bool v) async {
    final it = _items[i];
    setState(() => _ocupado.add(it.id));
    try {
      await ApiClient.instance.marcarAyudaIntento(it.id, v);
      _reemplaza(i, IntentoRevision(
          id: it.id, ejercicio: it.ejercicio, resultado: it.resultado, conAyuda: v));
    } catch (_) {} finally {
      if (mounted) setState(() => _ocupado.remove(it.id));
    }
  }

  Future<void> _resultado(int i, String r) async {
    final it = _items[i];
    setState(() => _ocupado.add(it.id));
    try {
      await ApiClient.instance.marcarResultadoIntento(it.id, r);
      _reemplaza(i, IntentoRevision(
          id: it.id, ejercicio: it.ejercicio, resultado: r, conAyuda: it.conAyuda));
    } catch (_) {} finally {
      if (mounted) setState(() => _ocupado.remove(it.id));
    }
  }

  String _txtRes(String r) => switch (r) {
        'logrado' => 'Lo logró',
        'parcial' => 'A medias',
        'no_logrado' => 'No lo logró',
        _ => 'Sin valorar',
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Últimas de ${widget.alias}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _items.length; i++) _fila(i),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo')),
      ],
    );
  }

  Widget _fila(int i) {
    final it = _items[i];
    final cargando = _ocupado.contains(it.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(it.ejercicio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: TrazoColors.ink)),
              ),
              Text(_txtRes(it.resultado),
                  style: const TextStyle(
                      fontSize: 13, color: TrazoColors.sageDark)),
            ],
          ),
          const SizedBox(height: 4),
          // Si quedó sin valorar, resolver aquí; siempre, marcar la ayuda.
          Row(
            children: [
              if (it.resultado == 'sin_valorar') ...[
                _mini('Logró', () => _resultado(i, 'logrado'), cargando),
                _mini('A medias', () => _resultado(i, 'parcial'), cargando),
                _mini('No pudo', () => _resultado(i, 'no_logrado'), cargando),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              _AyudaChip(
                activo: it.conAyuda,
                cargando: cargando,
                onTap: () => _ayuda(i, !it.conAyuda),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String t, VoidCallback onTap, bool cargando) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: OutlinedButton(
          onPressed: cargando ? null : onTap,
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 36)),
          child: Text(t, style: const TextStyle(fontSize: 13)),
        ),
      );
}

class _AyudaChip extends StatelessWidget {
  final bool activo;
  final bool cargando;
  final VoidCallback onTap;
  const _AyudaChip(
      {required this.activo, required this.cargando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: cargando ? null : onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor:
            activo ? TrazoColors.coralDark.withValues(alpha: 0.16) : null,
        foregroundColor: activo ? TrazoColors.coralDark : TrazoColors.sageDark,
        side: BorderSide(
            color: activo ? TrazoColors.coralDark : TrazoColors.sand),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
      icon: Icon(activo ? Icons.back_hand : Icons.back_hand_outlined, size: 16),
      label: Text(activo ? 'Le ayudé ✓' : 'Le ayudé',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------
// Sesiones programadas: lista de salas preparadas para abrir otro día
// ---------------------------------------------------------------------------

class _ProgramadasScreen extends StatefulWidget {
  const _ProgramadasScreen();

  @override
  State<_ProgramadasScreen> createState() => _ProgramadasScreenState();
}

class _ProgramadasScreenState extends State<_ProgramadasScreen> {
  List<SesionProgramada> _sesiones = [];
  bool _cargando = true;
  String? _error;
  final Set<String> _abriendo = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final s = await ApiClient.instance.sesionesProgramadas();
      if (!mounted) return;
      setState(() {
        _sesiones = s;
        _cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _abrir(SesionProgramada s) async {
    setState(() => _abriendo.add(s.id));
    try {
      await ApiClient.instance.abrirSesion(s.id);
      if (!mounted) return;
      Navigator.of(context).pop(s.id); // vuelve al monitor con la sala abierta
    } catch (err) {
      if (!mounted) return;
      setState(() => _abriendo.remove(s.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo abrir: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: const Text('Sesiones programadas'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No se pudo cargar:\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: TrazoColors.coralDark)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sesiones.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay sesiones guardadas.\n\nPuedes preparar una '
                          'desde "Abrir sala" activando "Guardar para otro día".',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, color: TrazoColors.sageDark),
                        ),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: _sesiones
                              .map((s) => _TarjetaProgramada(
                                    sesion: s,
                                    abriendo: _abriendo.contains(s.id),
                                    onAbrir: () => _abrir(s),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
    );
  }
}

class _TarjetaProgramada extends StatelessWidget {
  final SesionProgramada sesion;
  final bool abriendo;
  final VoidCallback onAbrir;

  const _TarjetaProgramada({
    required this.sesion,
    required this.abriendo,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: TrazoColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: TrazoColors.sand),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(sesion.nombre,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: TrazoColors.ink)),
                ),
                if (sesion.programadaPara != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: TrazoColors.card,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event,
                            size: 16, color: TrazoColors.sageDark),
                        const SizedBox(width: 6),
                        Text(sesion.programadaPara!,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: TrazoColors.sageDark)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...sesion.participantes.map((p) {
              final cats = p.lineas.isEmpty
                  ? 'su plan'
                  : p.lineas
                      .map((l) => '${etiquetaBloque(l.bloque)} ×${l.n}')
                      .join(' · ');
              final nivel = p.nivel != null ? '${p.nivel} · ' : '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_outline,
                        size: 18, color: TrazoColors.sageDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${p.aliasInterno}: ',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: TrazoColors.ink)),
                        TextSpan(
                            text: '$nivel$cats',
                            style: const TextStyle(
                                fontSize: 16, color: TrazoColors.sageDark)),
                      ])),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: abriendo ? null : onAbrir,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrazoColors.sageDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                icon: abriendo
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.meeting_room),
                label: const Text('Abrir y repartir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraControl extends StatelessWidget {
  final bool iniciada;
  final bool iniciando;
  final VoidCallback onIniciar;
  final VoidCallback onCerrar;

  const _BarraControl({
    required this.iniciada,
    required this.iniciando,
    required this.onIniciar,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TrazoColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (iniciada)
              const Row(children: [
                Icon(Icons.play_circle, color: TrazoColors.sageDark),
                SizedBox(width: 8),
                Text('Actividad en curso',
                    style: TextStyle(
                        color: TrazoColors.sageDark,
                        fontWeight: FontWeight.w600)),
              ])
            else
              ElevatedButton.icon(
                onPressed: iniciando ? null : onIniciar,
                icon: iniciando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: const Text('Iniciar actividad'),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onCerrar,
              icon: const Icon(Icons.flag, size: 18),
              label: const Text('Finalizar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: TrazoColors.coralDark,
                side: const BorderSide(color: TrazoColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Historial de sesiones del centro: la integradora ve las sesiones anteriores
/// y, al tocar una, el resumen de cómo fue cada persona (para decidir qué mandar).
class _HistorialScreen extends StatefulWidget {
  const _HistorialScreen();

  @override
  State<_HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<_HistorialScreen> {
  List<SesionHistorial> _sesiones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final s = await ApiClient.instance.sesionesAnteriores();
      if (!mounted) return;
      setState(() {
        _sesiones = s;
        _cargando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _verResumen(SesionHistorial s) async {
    try {
      final resumen = await ApiClient.instance.resumenSesion(s.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ResumenSesionDialog(resumen: resumen),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo cargar: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: const Text('Sesiones anteriores'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('No se pudo cargar:\n$_error',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: TrazoColors.coralDark)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar')),
                    ]),
                  ),
                )
              : _sesiones.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Aún no hay sesiones anteriores.',
                            style: TextStyle(
                                fontSize: 18, color: TrazoColors.sageDark)),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _sesiones.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = _sesiones[i];
                            return Card(
                              color: TrazoColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side:
                                    const BorderSide(color: TrazoColors.sand),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                title: Text(s.nombre,
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: TrazoColors.ink)),
                                subtitle: Text(
                                    '${s.fechaCorta}  ·  ${s.nParticipantes} personas',
                                    style: const TextStyle(
                                        color: TrazoColors.sageDark)),
                                trailing: const Icon(Icons.chevron_right,
                                    color: TrazoColors.sageDark),
                                onTap: () => _verResumen(s),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

/// Resumen al finalizar la sesión: por persona, cuántas actividades y cómo fueron
/// (solo / con ayuda / no pudo), con una barra proporcional. Cierra el bucle.
class _ResumenSesionDialog extends StatefulWidget {
  final ResumenSesion resumen;
  const _ResumenSesionDialog({required this.resumen});

  @override
  State<_ResumenSesionDialog> createState() => _ResumenSesionDialogState();
}

class _ResumenSesionDialogState extends State<_ResumenSesionDialog> {
  late final TextEditingController _nota =
      TextEditingController(text: widget.resumen.notas ?? '');
  bool _guardando = false;
  bool _guardada = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardarNota() async {
    setState(() {
      _guardando = true;
      _guardada = false;
    });
    try {
      await ApiClient.instance
          .guardarNotaSesion(widget.resumen.sesionId, _nota.text.trim());
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _guardada = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la nota')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resumen;
    return AlertDialog(
      icon: const Icon(Icons.emoji_events, color: TrazoColors.sageDark, size: 40),
      title: const Text('Sesión finalizada'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.fichas.every((f) => f.nIntentos == 0 && f.sinValorar == 0))
                const Text('No se registraron actividades en esta sesión.',
                    style: TextStyle(color: TrazoColors.sageDark))
              else
                ...r.fichas.map((f) => _FilaResumen(ficha: f)),
              const SizedBox(height: 16),
              const Text('Observaciones (opcional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: TrazoColors.ink)),
              const SizedBox(height: 6),
              TextField(
                controller: _nota,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                onChanged: (_) {
                  if (_guardada) setState(() => _guardada = false);
                },
                decoration: const InputDecoration(
                  hintText:
                      'Cómo fue la sesión, incidencias, ánimo del grupo…',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _guardada
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: TrazoColors.sage, size: 18),
                          SizedBox(width: 4),
                          Text('Nota guardada',
                              style: TextStyle(color: TrazoColors.sageDark)),
                        ],
                      )
                    : TextButton.icon(
                        onPressed: _guardando ? null : _guardarNota,
                        icon: _guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('Guardar nota'),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo')),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final FichaResumen ficha;
  const _FilaResumen({required this.ficha});

  @override
  Widget build(BuildContext context) {
    final total = ficha.nIntentos;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ficha.aliasInterno,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: TrazoColors.ink)),
              ),
              Text(
                  ficha.sinValorar > 0
                      ? '$total valoradas · ${ficha.sinValorar} sin valorar'
                      : '$total actividades',
                  style: const TextStyle(color: TrazoColors.sageDark)),
            ],
          ),
          const SizedBox(height: 6),
          // Barra proporcional del RESULTADO: verde=logró, coral=a medias,
          // arena=no lo logró.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: total == 0
                  ? Container(color: TrazoColors.card)
                  : Row(
                      children: [
                        if (ficha.logrado > 0)
                          Expanded(
                              flex: ficha.logrado,
                              child: Container(color: TrazoColors.sage)),
                        if (ficha.parcial > 0)
                          Expanded(
                              flex: ficha.parcial,
                              child: Container(color: TrazoColors.coral)),
                        if (ficha.noLogrado > 0)
                          Expanded(
                              flex: ficha.noLogrado,
                              child: Container(color: TrazoColors.sand)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
              'Logró ${ficha.logrado}  ·  A medias ${ficha.parcial}  ·  '
              'No lo logró ${ficha.noLogrado}'
              '${ficha.conAyuda > 0 ? '  ·  con ayuda ${ficha.conAyuda}' : ''}',
              style: const TextStyle(fontSize: 13, color: TrazoColors.sageDark)),
        ],
      ),
    );
  }
}
