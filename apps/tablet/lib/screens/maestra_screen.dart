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

  Future<void> _cargar() async {
    try {
      final u = await ApiClient.instance.usuariosDelCentro();
      final e = await ApiClient.instance.ejercicios();
      setState(() {
        _usuarios = u;
        _ejercicios = e;
        _cargando = false;
      });
    } catch (err) {
      setState(() {
        _error = err.toString();
        _cargando = false;
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
      final sesionId = await ApiClient.instance.crearSesion(
        tipo: _tipo,
        nombre: _nombre.text.trim(),
        modo: _tipo,
        ejercicioCompartidoId:
            _tipo == 'grupo' ? _ejercicioCompartido?.id : null,
        participantes: _seleccionados.toList(),
      );
      widget.onAbierta(sesionId);
    } catch (err) {
      setState(() {
        _error = err.toString();
        _creando = false;
      });
    }
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
        constraints: const BoxConstraints(maxWidth: 640),
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
                  onSelected: (v) => setState(() {
                    if (v) {
                      _seleccionados.add(u.id);
                    } else {
                      _seleccionados.remove(u.id);
                    }
                  }),
                );
              }).toList(),
            ),
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
                            mainAxisExtent: 190,
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
                              onAyuda: () => _ayuda(f),
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
  final VoidCallback onAyuda;

  const _FichaCard({
    required this.ficha,
    required this.marcando,
    required this.onAyuda,
  });

  ({String texto, Color color, IconData icono}) get _estado {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TrazoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ficha.atascado ? TrazoColors.coral : TrazoColors.sand,
          width: ficha.atascado ? 3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ficha.aliasInterno,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.ink)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(e.icono, size: 18, color: e.color),
              const SizedBox(width: 6),
              Text(e.texto,
                  style: TextStyle(
                      color: e.color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ficha.ejercicioActual ?? 'Sin ejercicio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TrazoColors.sageDark),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: marcando ? null : onAyuda,
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
