import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `arrastrar_posicion`: piezas que se arrastran a zonas
/// (Draggable / DragTarget). No se autocorrige aquí → registra
/// {colocaciones:{piezaId:zonaId}}.
class ArrastrarPosicionWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const ArrastrarPosicionWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<ArrastrarPosicionWidget> createState() =>
      _ArrastrarPosicionWidgetState();
}

class _ArrastrarPosicionWidgetState extends State<ArrastrarPosicionWidget> {
  late final List<Map<String, dynamic>> _piezas;
  late final List<Map<String, dynamic>> _zonas;

  // piezaId -> zonaId
  final Map<String, String> _colocaciones = {};
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _piezas = _comoLista(render['piezas']);
    _zonas = _comoLista(render['zonas']);
  }

  List<Map<String, dynamic>> _comoLista(dynamic v) => (v as List? ?? [])
      .map((e) => e is Map
          ? Map<String, dynamic>.from(e)
          : {'id': e.toString(), 'label': e.toString()})
      .toList();

  String _idDe(Map<String, dynamic> e) =>
      (e['id'] ?? e['label'] ?? e['nombre'] ?? '').toString();

  String _labelDe(Map<String, dynamic> e) =>
      (e['label'] ?? e['nombre'] ?? e['id'] ?? '').toString();

  void _emitir() {
    widget.onMetricas({
      'colocaciones': Map<String, String>.from(_colocaciones),
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  void _colocar(String piezaId, String zonaId) {
    setState(() => _colocaciones[piezaId] = zonaId);
    _emitir();
  }

  void _quitar(String piezaId) {
    setState(() => _colocaciones.remove(piezaId));
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion =
        render['instruccion'] as String? ?? 'Arrastra cada cosa a su sitio';

    final sinColocar =
        _piezas.where((p) => !_colocaciones.containsKey(_idDe(p))).toList();

    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 20),
        // Piezas disponibles.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TrazoColors.ivory,
            border: Border.all(color: TrazoColors.sand),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: sinColocar.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Todas colocadas',
                          style: TextStyle(
                              fontSize: 18, color: TrazoColors.sageDark)),
                    )
                  ]
                : sinColocar.map((p) {
                    final id = _idDe(p);
                    return Draggable<String>(
                      data: id,
                      feedback: _chipPieza(id, _labelDe(p), arrastrando: true),
                      childWhenDragging: Opacity(
                          opacity: 0.3, child: _chipPieza(id, _labelDe(p))),
                      child: _chipPieza(id, _labelDe(p)),
                    );
                  }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        // Zonas destino.
        Expanded(
          child: GridView.count(
            crossAxisCount: _zonas.length <= 2 ? _zonas.length.clamp(1, 2) : 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: _zonas.map(_zonaTarget).toList(),
          ),
        ),
      ],
    );
  }

  Widget _chipPieza(String id, String label, {bool arrastrando = false}) {
    final tieneDibujo = IlustracionResolver.tiene(id);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: tieneDibujo ? 12 : 20, vertical: tieneDibujo ? 10 : 14),
        decoration: BoxDecoration(
          color: arrastrando ? TrazoColors.coral : TrazoColors.card,
          border: Border.all(
              color: arrastrando ? TrazoColors.coralDark : TrazoColors.sand,
              width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tieneDibujo) ...[
              Ilustracion(id, size: 56),
              const SizedBox(height: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: tieneDibujo ? 16 : 22,
                    color: arrastrando ? Colors.white : TrazoColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _zonaTarget(Map<String, dynamic> zona) {
    final zonaId = _idDe(zona);
    final piezasAqui = _colocaciones.entries
        .where((e) => e.value == zonaId)
        .map((e) => e.key)
        .toList();

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _colocar(d.data, zonaId),
      builder: (context, candidatas, __) {
        final resaltar = candidatas.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: resaltar ? const Color(0xFFEDF3EE) : TrazoColors.white,
            border: Border.all(
                color: resaltar ? TrazoColors.sage : TrazoColors.sand,
                width: resaltar ? 3 : 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(_labelDe(zona),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: TrazoColors.sageDark)),
              const Divider(color: TrazoColors.sand),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: piezasAqui.map((piezaId) {
                      final pieza = _piezas.firstWhere(
                          (p) => _idDe(p) == piezaId,
                          orElse: () => {'label': piezaId});
                      return InkWell(
                        onTap: () => _quitar(piezaId),
                        child: _chipPieza(_idDe(pieza), _labelDe(pieza)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
