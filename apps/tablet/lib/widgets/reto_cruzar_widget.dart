import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'reto_contenedor.dart';

/// Reto interactivo de CRUZAR EL RÍO. Motor genérico que cubre dos clásicos:
///  - El barquero (el lobo, la cabra y la col): hay un REMERO (el barquero) que
///    debe ir en la barca para cruzar y que "vigila"; ciertas parejas no pueden
///    quedarse SOLAS en una orilla sin él (`incompatibles`).
///  - Misioneros y caníbales: cualquiera rema; en NINGUNA orilla puede haber más
///    caníbales que misioneros (salvo que no haya misioneros) (`mayoria`).
///
/// Se juega tocando: tocas una figura de la orilla de la barca para subirla (o
/// una de la barca para bajarla) y luego "Cruzar". Si al cruzar se rompe una
/// regla, avisa y se puede reintentar. Gana cuando todos están en la otra orilla.
class CruzarEntidad {
  final String id;
  final String nombre;
  final String emoji;
  final String tipo; // libre; usado por la regla de mayoría
  const CruzarEntidad(
      {required this.id,
      required this.nombre,
      required this.emoji,
      this.tipo = ''});
}

class MayoriaRegla {
  final String debil; // tipo que NO puede ser superado (misioneros)
  final String fuerte; // tipo que no puede superar al débil (caníbales)
  const MayoriaRegla({required this.debil, required this.fuerte});
}

class RetoCruzar {
  final String titulo;
  final String enunciado;
  final List<CruzarEntidad> entidades;
  final int capacidadBarca;
  final String? remero; // id que debe ir en la barca para moverla (y vigila)
  final List<List<String>> incompatibles; // pares inseguros sin el remero
  final MayoriaRegla? mayoria;

  const RetoCruzar({
    required this.titulo,
    required this.enunciado,
    required this.entidades,
    this.capacidadBarca = 2,
    this.remero,
    this.incompatibles = const [],
    this.mayoria,
  });

  /// Construye el reto desde el `render` de una Instancia del catálogo (banco).
  factory RetoCruzar.desdeRender(Map<String, dynamic> r) {
    final ents = (r['entidades'] as List? ?? const [])
        .map((e) => CruzarEntidad(
              id: (e['id'] ?? '').toString(),
              nombre: (e['nombre'] ?? '').toString(),
              emoji: (e['emoji'] ?? '').toString(),
              tipo: (e['tipo'] ?? '').toString(),
            ))
        .toList();
    final incs = (r['incompatibles'] as List? ?? const [])
        .map<List<String>>(
            (p) => (p as List).map((x) => x.toString()).toList())
        .toList();
    final m = r['mayoria'];
    return RetoCruzar(
      titulo: (r['titulo'] ?? '').toString(),
      enunciado: (r['enunciado'] ?? '').toString(),
      entidades: ents,
      capacidadBarca: (r['capacidad_barca'] as num? ?? 2).toInt(),
      remero: r['remero'] as String?,
      incompatibles: incs,
      mayoria: m is Map
          ? MayoriaRegla(
              debil: (m['debil'] ?? '').toString(),
              fuerte: (m['fuerte'] ?? '').toString())
          : null,
    );
  }
}

class RetoCruzarWidget extends StatefulWidget {
  final RetoCruzar reto;
  final ValueChanged<Map<String, dynamic>>? onMetricas;
  const RetoCruzarWidget({super.key, required this.reto, this.onMetricas});

  @override
  State<RetoCruzarWidget> createState() => _RetoCruzarWidgetState();
}

class _RetoCruzarWidgetState extends State<RetoCruzarWidget> {
  final Map<String, int> _lado = {}; // id -> 0 izquierda / 1 derecha
  final Set<String> _enBarca = {};
  int _barcaLado = 0;
  int _movimientos = 0;
  String? _aviso; // regla rota
  bool _celebrado = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    setState(() {
      for (final e in widget.reto.entidades) {
        _lado[e.id] = 0;
      }
      _enBarca.clear();
      _barcaLado = 0;
      _movimientos = 0;
      _aviso = null;
      _celebrado = false;
    });
  }

  bool get _ganado =>
      _aviso == null && widget.reto.entidades.every((e) => _lado[e.id] == 1);

  CruzarEntidad _ent(String id) =>
      widget.reto.entidades.firstWhere((e) => e.id == id);

  void _tocar(String id) {
    if (_aviso != null) return;
    if (_enBarca.contains(id)) {
      setState(() => _enBarca.remove(id));
      return;
    }
    if (_lado[id] != _barcaLado) return; // no está en la orilla de la barca
    if (_enBarca.length >= widget.reto.capacidadBarca) return;
    HapticFeedback.selectionClick();
    setState(() => _enBarca.add(id));
  }

  bool get _puedeCruzar {
    if (_enBarca.isEmpty) return false;
    if (widget.reto.remero != null) {
      return _enBarca.contains(widget.reto.remero);
    }
    return true;
  }

  /// Nombre de la regla rota en una orilla, o null si es segura.
  String? _rota(int lado) {
    final aqui = widget.reto.entidades
        .where((e) => _lado[e.id] == lado)
        .toList();
    final ids = aqui.map((e) => e.id).toSet();
    final remeroAqui =
        widget.reto.remero != null && ids.contains(widget.reto.remero);
    if (!remeroAqui) {
      for (final par in widget.reto.incompatibles) {
        if (par.length == 2 && ids.contains(par[0]) && ids.contains(par[1])) {
          return '${_ent(par[0]).nombre} y ${_ent(par[1]).nombre} no pueden '
              'quedarse solos.';
        }
      }
    }
    final m = widget.reto.mayoria;
    if (m != null) {
      final nDebil = aqui.where((e) => e.tipo == m.debil).length;
      final nFuerte = aqui.where((e) => e.tipo == m.fuerte).length;
      if (nDebil > 0 && nFuerte > nDebil) {
        return 'En una orilla hay más ${_plural(m.fuerte)} que '
            '${_plural(m.debil)}.';
      }
    }
    return null;
  }

  String _plural(String tipo) {
    // etiqueta legible del tipo (para el aviso)
    final e = widget.reto.entidades.firstWhere((x) => x.tipo == tipo,
        orElse: () => CruzarEntidad(id: '', nombre: tipo, emoji: ''));
    return e.nombre.endsWith('s') ? e.nombre : '${e.nombre}s';
  }

  void _cruzar() {
    if (!_puedeCruzar) return;
    HapticFeedback.selectionClick();
    final destino = 1 - _barcaLado;
    setState(() {
      for (final id in _enBarca) {
        _lado[id] = destino;
      }
      _enBarca.clear();
      _barcaLado = destino;
      _movimientos++;
      _aviso = _rota(0) ?? _rota(1);
      if (_ganado && !_celebrado) {
        _celebrado = true;
        HapticFeedback.mediumImpact();
        widget.onMetricas
            ?.call({'resuelto': true, 'movimientos': _movimientos});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reto;
    if (r.entidades.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Este reto no se puede mostrar.',
              style: TextStyle(fontSize: 18, color: TrazoColors.ink)),
        ),
      );
    }
    return RetoContenedor(child: LayoutBuilder(builder: (context, outer) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: outer.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(r.enunciado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, color: TrazoColors.ink, height: 1.25)),
              ),
              SizedBox(
                height: 300,
                child: Row(
                  children: [
                    Expanded(child: _orilla(0, 'Esta orilla')),
                    _canal(),
                    Expanded(child: _orilla(1, 'La otra orilla')),
                  ],
                ),
              ),
        if (_aviso != null)
          _banner(TrazoColors.coralDark, Icons.warning_amber_rounded,
              '¡Vaya! $_aviso  Probad otra vez.'),
        if (_ganado)
          _banner(TrazoColors.sageDark, Icons.check_circle,
              '¡Lo habéis conseguido!  ($_movimientos movimientos)'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Movimientos: $_movimientos',
                  style: const TextStyle(
                      fontSize: 15, color: TrazoColors.bordeControl)),
              Row(
                children: [
                  if (_aviso == null && !_ganado)
                    ElevatedButton.icon(
                      onPressed: _puedeCruzar ? _cruzar : null,
                      icon: const Icon(Icons.directions_boat),
                      label: const Text('Cruzar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TrazoColors.sageDark,
                        foregroundColor: TrazoColors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                      ),
                    ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('De nuevo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TrazoColors.sageDark,
                      side: const BorderSide(
                          color: TrazoColors.bordeControl, width: 1.6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
          ),
        ),
      );
    }));
  }

  Widget _banner(Color c, IconData ic, String txt) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: TrazoColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c, width: 2.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic, color: c, size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text(txt,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: c)),
            ),
          ],
        ),
      );

  Widget _orilla(int lado, String titulo) {
    final aqui =
        widget.reto.entidades.where((e) => _lado[e.id] == lado).toList();
    final barcaAqui = _barcaLado == lado;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7D6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TrazoColors.sand, width: 1.5),
      ),
      child: Column(
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TrazoColors.bordeControl)),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [for (final e in aqui) _ficha(e, false)],
              ),
            ),
          ),
          if (barcaAqui) _barca(),
        ],
      ),
    );
  }

  Widget _barca() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFDCC9A6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9C7A45), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_boat, size: 18, color: Color(0xFF6E5325)),
              SizedBox(width: 6),
              Text('La barca',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6E5325))),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in _enBarca) _ficha(_ent(id), true),
              if (_enBarca.isEmpty)
                const Text('(vacía · toca a alguien para subirlo)',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF6E5325))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ficha(CruzarEntidad e, bool enBarca) {
    return GestureDetector(
      onTap: () => _tocar(e.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enBarca ? TrazoColors.coralDark : TrazoColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: enBarca ? TrazoColors.coralDark : TrazoColors.bordeControl,
              width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.emoji, style: const TextStyle(fontSize: 30)),
            Text(e.nombre,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enBarca ? TrazoColors.white : TrazoColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _canal() => Container(
        width: 28,
        margin: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF7FC4E8).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
      );
}
