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
          if (_sesionId == null)
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
      ),
      body: _sesionId == null
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
  final _nombre = TextEditingController(text: 'Grupo tarde');
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

  Future<void> _abrir() async {
    if (_seleccionados.isEmpty || _nombre.text.trim().isEmpty) return;
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
                        child: Text('${e.nombre}  ·  ${e.bloque}',
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
                                backgroundColor: TrazoColors.sage),
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
      setState(() {
        _fichas = f;
        _cargando = false;
        _error = null;
      });
    } catch (err) {
      if (!mounted) return;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sala'),
        content: const Text('¿Seguro que quieres cerrar la sala?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, cerrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.cerrarSesion(widget.sesionId);
      widget.onCerrada();
    } catch (err) {
      _snack('No se pudo cerrar: $err');
    }
  }

  Future<void> _ayuda(FichaLive f) async {
    final id = f.ultimoIntentoId;
    if (id == null) {
      _snack('${f.aliasInterno} aún no tiene ningún intento que marcar.');
      return;
    }
    setState(() => _marcando.add(id));
    try {
      await ApiClient.instance.marcarEstadoIntento(id, 'con_ayuda');
      _snack('Marcado "con ayuda" para ${f.aliasInterno}.');
      await _poll(silencioso: true);
    } catch (err) {
      _snack('No se pudo marcar: $err');
    } finally {
      if (mounted) setState(() => _marcando.remove(id));
    }
  }

  Future<void> _enviarMas(FichaLive f) async {
    // La maestra elige QUÉ mandar en la nueva tanda (categorías + nº + nivel) o
    // repite lo mismo. Así no se le manda otra vez casi lo mismo sin querer.
    final res = await showDialog<_MasResult>(
      context: context,
      builder: (_) => _EnviarMasDialog(nombre: f.aliasInterno),
    );
    if (res == null) return;
    final uid = f.usuarioFinalId;
    setState(() => _enviandoMas.add(uid));
    try {
      if (res.repetir) {
        await ApiClient.instance.enviarMas(widget.sesionId, uid);
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
                            mainAxisExtent: 240,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _fichas.length,
                          itemBuilder: (_, i) {
                            final f = _fichas[i];
                            return _FichaCard(
                              ficha: f,
                              marcando: f.ultimoIntentoId != null &&
                                  _marcando.contains(f.ultimoIntentoId),
                              puedeAyudar: f.ultimoIntentoId != null,
                              enviandoMas:
                                  _enviandoMas.contains(f.usuarioFinalId),
                              onAyuda: () => _ayuda(f),
                              onEnviarMas: () => _enviarMas(f),
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
  const _MasResult.repetir()
      : repetir = true,
        nivel = null,
        lineas = const [];
  const _MasResult.config(this.nivel, this.lineas) : repetir = false;
}

/// Diálogo para elegir QUÉ mandar en la nueva tanda: categorías + nº + nivel,
/// o repetir lo mismo. Evita mandar otra vez casi los mismos ejercicios.
class _EnviarMasDialog extends StatefulWidget {
  final String nombre;
  const _EnviarMasDialog({required this.nombre});

  @override
  State<_EnviarMasDialog> createState() => _EnviarMasDialogState();
}

class _EnviarMasDialogState extends State<_EnviarMasDialog> {
  String _nivel = 'medio';
  final Map<String, _ConfigBloque> _bloques = {
    for (final k in kBloques.keys) k: _ConfigBloque(incluido: false, n: 2),
  };

  List<Map<String, dynamic>> get _lineas => _bloques.entries
      .where((e) => e.value.incluido && e.value.n > 0)
      .map((e) => {'bloque': e.key, 'n': e.value.n})
      .toList();

  @override
  Widget build(BuildContext context) {
    final hayCategorias = _lineas.isNotEmpty;
    return AlertDialog(
      title: Text('Enviar más a ${widget.nombre}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Elige categorías y cuántas de cada una, o repite lo '
                  'mismo de antes.',
                  style: TextStyle(fontSize: 14, color: TrazoColors.sageDark)),
              const SizedBox(height: 14),
              const Text('Nivel',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: TrazoColors.sageDark)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 16),
              const Text('Categorías y nº de actividades',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: TrazoColors.sageDark)),
              const SizedBox(height: 8),
              ...kBloques.entries.map((entry) => _FilaBloque(
                    etiqueta: entry.value,
                    cfg: _bloques[entry.key]!,
                    onCambio: () => setState(() {}),
                  )),
            ],
          ),
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
          onPressed: hayCategorias
              ? () => Navigator.pop(
                  context, _MasResult.config(_nivel, _lineas))
              : null,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Enviar'),
        ),
      ],
    );
  }
}

class _FichaCard extends StatelessWidget {
  final FichaLive ficha;
  final bool marcando;
  final bool puedeAyudar;
  final bool enviandoMas;
  final VoidCallback onAyuda;
  final VoidCallback onEnviarMas;

  const _FichaCard({
    required this.ficha,
    required this.marcando,
    required this.puedeAyudar,
    required this.enviandoMas,
    required this.onAyuda,
    required this.onEnviarMas,
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
      case 'con_ayuda':
        return (
          texto: 'Con ayuda',
          color: TrazoColors.coralDark,
          icono: Icons.pan_tool_alt
        );
      case 'solo':
        return (
          texto: 'Terminó solo',
          color: TrazoColors.sageDark,
          icono: Icons.check_circle
        );
      case 'no_completado':
        return (
          texto: 'Saltado',
          color: TrazoColors.coralDark,
          icono: Icons.skip_next
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
              if (ficha.ronda > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: TrazoColors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Ronda ${ficha.ronda + 1}',
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
          const Spacer(),
          if (terminado)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: enviandoMas ? null : onEnviarMas,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TrazoColors.sage,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: (marcando || !puedeAyudar) ? null : onAyuda,
                icon: marcando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.back_hand, size: 18),
                label: const Text('Ayuda'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TrazoColors.coralDark,
                  side: const BorderSide(color: TrazoColors.coral),
                ),
              ),
            ),
        ],
      ),
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
                  backgroundColor: TrazoColors.sage,
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
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sala'),
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
