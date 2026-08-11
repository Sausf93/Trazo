import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `arrastrar_posicion`: piezas que se colocan en zonas.
/// Interacción por TOQUE (no arrastrar, muy difícil con temblor/Alzheimer):
/// la persona TOCA una pieza (queda "cogida", resaltada) y luego TOCA la zona
/// donde colocarla. Tocar otra pieza cambia la selección; tocar la misma la
/// suelta. Una pieza colocada se quita con su botón (✕) visible.
/// No se autocorrige aquí → registra {colocaciones:{piezaId:zonaId}}.
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
  // Pieza "cogida" ahora mismo (pendiente de colocar). null = ninguna.
  String? _seleccionada;
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

  /// Toca una pieza disponible: la coge, o la suelta si ya estaba cogida.
  void _seleccionar(String piezaId) {
    setState(() {
      _seleccionada = _seleccionada == piezaId ? null : piezaId;
    });
  }

  /// Toca una zona: si hay una pieza cogida, la coloca ahí.
  void _colocarEnZona(String zonaId) {
    final pieza = _seleccionada;
    if (pieza == null) return;
    setState(() {
      _colocaciones[pieza] = zonaId;
      _seleccionada = null;
    });
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
        render['instruccion'] as String? ?? 'Toca una cosa y luego su sitio';

    final sinColocar =
        _piezas.where((p) => !_colocaciones.containsKey(_idDe(p))).toList();

    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 6),
        Text(
            _seleccionada == null
                ? 'Toca una cosa para cogerla'
                : 'Ahora toca el sitio donde va',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: TrazoColors.sageDark)),
        const SizedBox(height: 14),
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
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _seleccionar(id),
                      child: _chipPieza(id, _labelDe(p),
                          seleccionada: _seleccionada == id),
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
            children: _zonas.map(_zona).toList(),
          ),
        ),
      ],
    );
  }

  Widget _chipPieza(String id, String label,
      {bool seleccionada = false, bool compacto = false}) {
    final tieneDibujo = IlustracionResolver.tiene(id);
    final tamDibujo = compacto ? 40.0 : 52.0;
    // Ancho FIJO: así una etiqueta larga ("cepillo de dientes") no ensancha la
    // caja ni descuadra la fila; el texto se ajusta a 2 líneas.
    final ancho = compacto ? 92.0 : 116.0;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: ancho,
        padding: EdgeInsets.symmetric(
            horizontal: 8, vertical: compacto ? 8 : 12),
        decoration: BoxDecoration(
          color: seleccionada ? TrazoColors.coral : TrazoColors.card,
          border: Border.all(
              color: seleccionada ? TrazoColors.coralDark : TrazoColors.sand,
              width: seleccionada ? 4 : 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tieneDibujo) ...[
              Ilustracion(id, size: tamDibujo),
              const SizedBox(height: 4),
            ],
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: compacto ? 13 : (tieneDibujo ? 15 : 19),
                    height: 1.05,
                    fontWeight:
                        seleccionada ? FontWeight.bold : FontWeight.w500,
                    color: seleccionada ? Colors.white : TrazoColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _zona(Map<String, dynamic> zona) {
    final zonaId = _idDe(zona);
    final piezasAqui = _colocaciones.entries
        .where((e) => e.value == zonaId)
        .map((e) => e.key)
        .toList();

    // Cuando hay una pieza cogida, la zona invita a soltarla ahí.
    final resaltar = _seleccionada != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _seleccionada != null ? () => _colocarEnZona(zonaId) : null,
      child: Container(
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
                    return _piezaColocada(pieza);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pieza ya colocada, con un botón ✕ visible para quitarla. El toque para
  /// quitar es SOLO sobre la ✕, así un roce en la zona no la borra.
  Widget _piezaColocada(Map<String, dynamic> pieza) {
    final piezaId = _idDe(pieza);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _chipPieza(piezaId, _labelDe(pieza), compacto: true),
        Positioned(
          top: -8,
          right: -8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _quitar(piezaId),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TrazoColors.coralDark,
                ),
                child: const Icon(Icons.close, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
