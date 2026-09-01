import 'dart:math' show min, max, cos, sin, pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../tts.dart';
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
  // Coherencia visual: dentro de una misma actividad, o TODAS las piezas-objeto
  // llevan ilustración o NINGUNA (nada de mezclar dibujo/foto con texto pelado,
  // que descuadraba la pantalla —feedback de Saulo). Si alguna no tiene dibujo,
  // se muestran todas como texto.
  late final bool _todasConDibujo;
  // Nunca mezclar foto y dibujo en la misma actividad: si NO todas las figuras
  // (piezas-objeto) tienen foto, se pintan TODAS como dibujo (coherentes).
  late final bool _soloDibujo;

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
    final objetos = _piezas.where((p) => _formaDe(_idDe(p)) == null).toList();
    _todasConDibujo = objetos.isNotEmpty &&
        objetos.every((p) => IlustracionResolver.tiene(_idDe(p)));
    _soloDibujo =
        !IlustracionResolver.todasConFoto(objetos.map((p) => _idDe(p)));
  }

  List<Map<String, dynamic>> _comoLista(dynamic v) => (v as List? ?? [])
      .map((e) => e is Map
          ? Map<String, dynamic>.from(e)
          : {'id': e.toString(), 'label': e.toString()})
      .toList();

  /// Si el id es una pieza de FORMA (`forma_circulo`…), devuelve el nombre de la
  /// figura a pintar; si no, null (se pinta como ilustración/texto normal).
  static const _formasGeom = {
    'circulo', 'cuadrado', 'triangulo', 'estrella', 'corazon', 'rombo', 'ovalo',
    'rectangulo'
  };
  String? _formaDe(String id) {
    if (!id.startsWith('forma_')) return null;
    final f = id.substring(6);
    return _formasGeom.contains(f) ? f : null;
  }

  String _idDe(Map<String, dynamic> e) =>
      (e['id'] ?? e['label'] ?? e['nombre'] ?? '').toString();

  String _labelDe(Map<String, dynamic> e) =>
      (e['label'] ?? e['nombre'] ?? e['id'] ?? '').toString();

  /// Actividad ESPACIAL: todas las zonas traen `pos:[x,y]` (fracciones 0..1). Se
  /// pintan en su sitio real (p. ej. "Poner la mesa": plato al centro, cubiertos
  /// a los lados) en vez de tarjetas de texto sueltas -> más intuitivo y digno.
  bool get _esEspacial =>
      _zonas.isNotEmpty &&
      _zonas.every((z) {
        final p = z['pos'];
        return p is List && p.length == 2 && p[0] is num && p[1] is num;
      });

  void _emitir() {
    widget.onMetricas({
      'colocaciones': Map<String, String>.from(_colocaciones),
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  /// Etiqueta legible de una pieza / zona por su id (para la voz). Cae al id.
  String _labelPieza(String id) {
    for (final p in _piezas) {
      if (_idDe(p) == id) return (p['label'] ?? id).toString();
    }
    return id;
  }

  String _labelZona(String id) {
    for (final z in _zonas) {
      if ((z['id'] ?? '').toString() == id) {
        return (z['label'] ?? id).toString();
      }
    }
    return id;
  }

  /// Toca una pieza disponible: la coge, o la suelta si ya estaba cogida.
  void _seleccionar(String piezaId) {
    HapticFeedback.selectionClick(); // confirma "he cogido esto"
    final yaEstaba = _seleccionada == piezaId;
    setState(() {
      _seleccionada = yaEstaba ? null : piezaId;
    });
    // Voz: quien depende del audio necesita oír que cogió algo y qué hacer.
    Tts.instance.hablar(yaEstaba
        ? 'Lo has soltado.'
        : 'Has cogido: ${_labelPieza(piezaId)}. Ahora toca su sitio.');
  }

  /// Toca una zona: si hay una pieza cogida, la coloca ahí.
  void _colocarEnZona(String zonaId) {
    final pieza = _seleccionada;
    if (pieza == null) return;
    HapticFeedback.mediumImpact(); // confirma "colocado"
    setState(() {
      _colocaciones[pieza] = zonaId;
      _seleccionada = null;
    });
    Tts.instance
        .hablar('${_labelPieza(pieza)}, colocado en ${_labelZona(zonaId)}.');
    _emitir();
  }

  void _quitar(String piezaId) {
    HapticFeedback.selectionClick();
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

    // Cabecera (enunciado + pista + panel de piezas): idéntica en tablet y móvil.
    final encabezado = <Widget>[
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
      _panelPiezas(sinColocar),
      const SizedBox(height: 20),
    ];

    return LayoutBuilder(builder: (context, c) {
      // Responsive: en móvil vertical (viewport estrecho o bajo) hacemos scroll de
      // toda la pantalla y damos a la zona destino una altura cómoda FIJA, para
      // que nada se recorte ni quede fuera. En tablet apaisada, layout idéntico.
      final estrecho = c.maxWidth < 520 || c.maxHeight < 640;
      if (estrecho) {
        return SingleChildScrollView(
          child: Column(
            children: [
              ...encabezado,
              // Zona destino. El layout espacial es un Stack: necesita una altura
              // acotada cómoda (scroll externo si no cabe). El de tarjetas fluye
              // a su altura natural dentro del scroll (nada se recorta).
              if (_esEspacial)
                SizedBox(
                  height: max(360.0, c.maxHeight * 0.75),
                  child: _zonasEspaciales(),
                )
              else
                _zonasWrap(),
              const SizedBox(height: 8),
            ],
          ),
        );
      }
      return Column(
        children: [
          ...encabezado,
          // Zonas destino: tarjetas de tamaño FIJO y centradas, que se reparten en
          // filas. Antes se estiraban a toda la altura y quedaban cajas enormes
          // vacías; ahora son compactas y ordenadas en cualquier pantalla.
          Expanded(
            child: _esEspacial
                ? _zonasEspaciales()
                : SingleChildScrollView(child: _zonasWrap()),
          ),
        ],
      );
    });
  }

  /// Panel de piezas disponibles (Wrap que fluye a varias filas solo).
  Widget _panelPiezas(List<Map<String, dynamic>> sinColocar) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TrazoColors.ivory,
        border: Border.all(color: TrazoColors.bordeControl),
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
                      style:
                          TextStyle(fontSize: 18, color: TrazoColors.sageDark)),
                )
              ]
            : sinColocar.map((p) {
                final id = _idDe(p);
                return InkWell(
                  key: ValueKey('apieza|$id'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _seleccionar(id),
                  child: _chipPieza(id, _labelDe(p),
                      seleccionada: _seleccionada == id),
                );
              }).toList(),
      ),
    );
  }

  /// Zonas destino no espaciales: tarjetas fijas centradas en un Wrap.
  Widget _zonasWrap() {
    return Center(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: _zonas
            .map((z) => SizedBox(width: 240, height: 150, child: _zona(z)))
            .toList(),
      ),
    );
  }

  /// Coloca las zonas en su posición real dentro del área disponible.
  // Separación mínima real entre posiciones distintas de un eje (para dimensionar
  // las zonas sin que se solapen, sea cual sea el nº de zonas y el ancho).
  double _huecoMin(List<double> vs) {
    final s = [...vs]..sort();
    double m = 1.0;
    for (var i = 1; i < s.length; i++) {
      final d = s[i] - s[i - 1];
      if (d > 0.001 && d < m) m = d;
    }
    return m;
  }

  Widget _zonasEspaciales() {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final xs = _zonas.map((z) => (z['pos'][0] as num).toDouble()).toList();
      final ys = _zonas.map((z) => (z['pos'][1] as num).toDouble()).toList();
      final gx = _huecoMin(xs), gy = _huecoMin(ys);
      // Sin solape: las zonas se colocan por su esquina (left=fx*spanX), así que la
      // separación entre columnas contiguas es gx*spanX = gx*(w-zw). Para que la
      // caja no invada la de al lado: zw <= gx*(w-zw) -> zw <= gx*w/(1+gx). Igual
      // en vertical. Se deja un pequeño margen (0.9) para que se vea el hueco.
      final zwMax = gx > 0 ? gx / (1 + gx) * w * 0.90 : w;
      final zhMax = gy > 0 ? gy / (1 + gy) * h * 0.90 : h;
      final zw = min(min(w / 3.0, zwMax), 200.0).clamp(70.0, 200.0);
      final zh = min(min(h / 3.6, zhMax), 130.0).clamp(60.0, 130.0);
      final spanX = (w - zw).clamp(0.0, double.infinity);
      final spanY = (h - zh).clamp(0.0, double.infinity);
      return Stack(
        children: _zonas.map((z) {
          final pos = z['pos'] as List;
          final fx = (pos[0] as num).toDouble().clamp(0.0, 1.0);
          final fy = (pos[1] as num).toDouble().clamp(0.0, 1.0);
          return Positioned(
            left: fx * spanX,
            top: fy * spanY,
            width: zw,
            height: zh,
            child: _zona(z),
          );
        }).toList(),
      );
    });
  }

  Widget _chipPieza(String id, String label,
      {bool seleccionada = false, bool compacto = false}) {
    // Piezas de FORMA (encaja la pieza): se pinta la figura geométrica LIMPIA y
    // SIN texto; el nombre va en la zona ("Círculo"). Así se asocia figura→nombre
    // (feedback de Saulo: "hueco círculo" confundía porque no hay hueco redondo).
    final forma = _formaDe(id);
    if (forma != null) {
      final tam = compacto ? 46.0 : 64.0;
      return Material(
        color: Colors.transparent,
        child: Container(
          width: compacto ? 84.0 : 108.0,
          padding: EdgeInsets.all(compacto ? 8 : 12),
          decoration: BoxDecoration(
            color: seleccionada ? TrazoColors.coralDark : TrazoColors.card,
            border: Border.all(
                color: seleccionada ? TrazoColors.coralDark : TrazoColors.bordeControl,
                width: seleccionada ? 4 : 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CustomPaint(
              size: Size(tam, tam),
              painter: _FormaPintada(forma,
                  color: seleccionada ? Colors.white : TrazoColors.sageDark),
            ),
          ),
        ),
      );
    }
    final tieneDibujo = _todasConDibujo && IlustracionResolver.tiene(id);
    final tamDibujo = compacto ? 40.0 : 52.0;
    // Ancho FIJO: así una etiqueta larga ("cepillo de dientes") no ensancha la
    // caja ni descuadra la fila; el texto se ajusta a 2 líneas.
    final ancho = compacto ? 92.0 : 116.0;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: ancho,
        padding:
            EdgeInsets.symmetric(horizontal: 8, vertical: compacto ? 8 : 12),
        decoration: BoxDecoration(
          color: seleccionada ? TrazoColors.coralDark : TrazoColors.card,
          border: Border.all(
              color: seleccionada ? TrazoColors.coralDark : TrazoColors.bordeControl,
              width: seleccionada ? 4 : 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tieneDibujo) ...[
              Ilustracion(id, size: tamDibujo, soloDibujo: _soloDibujo),
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
      key: ValueKey('azona|$zonaId'),
      borderRadius: BorderRadius.circular(14),
      onTap: _seleccionada != null ? () => _colocarEnZona(zonaId) : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: resaltar ? const Color(0xFFEDF3EE) : TrazoColors.white,
          border: Border.all(
              color: resaltar ? TrazoColors.sage : TrazoColors.bordeControl,
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
                    final pieza = _piezas.firstWhere((p) => _idDe(p) == piezaId,
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
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TrazoColors.coralDark,
                ),
                child: const Icon(Icons.close, size: 26, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Figura geométrica limpia (para las piezas de "encaja la pieza"): relleno +
/// contorno oscuro, grande y con buen contraste.
class _FormaPintada extends CustomPainter {
  final String nombre;
  final Color color;
  _FormaPintada(this.nombre, {required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borde = Paint()
      ..color = TrazoColors.ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, size.width * 0.03);
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2;
    final r = min(w, h) / 2;
    void fs(Path path) {
      canvas.drawPath(path, p);
      canvas.drawPath(path, borde);
    }

    switch (nombre) {
      case 'circulo':
        canvas.drawCircle(Offset(cx, cy), r, p);
        canvas.drawCircle(Offset(cx, cy), r, borde);
        break;
      case 'ovalo':
        final rect =
            Rect.fromCenter(center: Offset(cx, cy), width: w, height: h * 0.7);
        canvas.drawOval(rect, p);
        canvas.drawOval(rect, borde);
        break;
      case 'cuadrado':
        fs(Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: w * 0.92, height: h * 0.92),
              const Radius.circular(4))));
        break;
      case 'rectangulo':
        fs(Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, cy), width: w, height: h * 0.62),
              const Radius.circular(4))));
        break;
      case 'triangulo':
        fs(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy + r)
          ..lineTo(cx - r, cy + r)
          ..close());
        break;
      case 'rombo':
        fs(Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close());
        break;
      case 'corazon':
        final path = Path()..moveTo(cx, cy + r * 0.75);
        path.cubicTo(
            cx - r * 1.4, cy - r * 0.2, cx - r * 0.5, cy - r, cx, cy - r * 0.35);
        path.cubicTo(
            cx + r * 0.5, cy - r, cx + r * 1.4, cy - r * 0.2, cx, cy + r * 0.75);
        fs(path);
        break;
      case 'estrella':
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final rr = i.isEven ? r : r * 0.42;
          final a = -pi / 2 + i * pi / 5;
          final pt = Offset(cx + cos(a) * rr, cy + sin(a) * rr);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        fs(path);
        break;
    }
  }

  @override
  bool shouldRepaint(_FormaPintada old) =>
      old.nombre != nombre || old.color != color;
}
