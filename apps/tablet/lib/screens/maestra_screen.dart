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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: Text(_sesionId == null ? 'Abrir sala' : 'Monitor en vivo'),
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
      final sesionId = await ApiClient.instance.crearSesion(
        tipo: _tipo,
        nombre: _nombre.text.trim(),
        modo: _tipo,
        ejercicioCompartidoId:
            _tipo == 'grupo' ? _ejercicioCompartido?.id : null,
        participantes: _seleccionados.toList(),
        configs: configs,
      );
      if (!mounted) return;
      widget.onAbierta(sesionId);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _creando = false;
      });
    }
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
            // Config por participante (colapsada por defecto). En modo grupo
            // todos hacen el mismo ejercicio compartido, así que se oculta.
            if (_tipo == 'individual' && _seleccionados.isNotEmpty) ...[
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
            const SizedBox(height: 28),
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
              icon: _creando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.meeting_room),
              label: const Text('Abrir sala'),
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
    final uid = f.usuarioFinalId;
    setState(() => _enviandoMas.add(uid));
    try {
      // Body vacío: repite su config/plan (nueva tanda para quien terminó).
      await ApiClient.instance.enviarMas(widget.sesionId, uid);
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
          color: TrazoColors.sand,
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
