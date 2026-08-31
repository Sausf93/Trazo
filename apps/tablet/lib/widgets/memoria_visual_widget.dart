import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../tts.dart';
import 'ilustracion.dart';

/// Renderiza `memoria_visual`: muestra `a_recordar` durante `segundos_memorizar`
/// (con cuenta atrás), las oculta y presenta `rejilla_seleccion` para que la
/// persona toque las que cree recordar. Puntúa en cliente comparando con los
/// ids de `a_recordar` (que sí vienen en el render).
class MemoriaVisualWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;
  // Avisa al contenedor de si se puede mostrar el botón global "Siguiente":
  // false mientras se memoriza (para no saltarse la selección), true al elegir.
  final ValueChanged<bool>? onListoParaAvanzar;

  const MemoriaVisualWidget(
      {super.key,
      required this.instancia,
      required this.onMetricas,
      this.onListoParaAvanzar});

  @override
  State<MemoriaVisualWidget> createState() => _MemoriaVisualWidgetState();
}

class _MemoriaVisualWidgetState extends State<MemoriaVisualWidget> {
  late final List<Map<String, dynamic>> _aRecordar;
  late final List<Map<String, dynamic>> _rejilla;
  late final Set<String> _idsCorrectos;
  late final bool _soloDibujo;

  bool _memorizando = true;
  int _restante = 0;
  Timer? _timer;
  final Set<String> _seleccionadas = {};
  final DateTime _inicio = DateTime.now();
  // Veces que la persona pidió "volver a mirar" las figuras. Se registra como
  // apoyo usado (no falsea la medición: la integradora lo ve en el intento).
  int _vecesMiradas = 0;

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _aRecordar = _comoLista(render['a_recordar']);
    _rejilla = _comoLista(render['rejilla_seleccion']);
    // Coherencia visual: si NO todas las figuras de la actividad tienen foto,
    // se pintan TODAS como dibujo (nunca se mezclan fotos y dibujos).
    _soloDibujo = !IlustracionResolver.todasConFoto(
        [..._aRecordar, ..._rejilla].map((e) => _idDe(e)));
    _idsCorrectos = _aRecordar.map((e) => _idDe(e)).toSet();
    _restante = (render['segundos_memorizar'] as num?)?.toInt() ?? 10;
    // Empieza memorizando: oculta el botón global "Siguiente" hasta que la
    // persona pase a la selección con "Ya lo recuerdo".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onListoParaAvanzar?.call(false);
      // Voz: guía a quien no lee ("nunca aprendieron a leer", apunte de Laura).
      Tts.instance.hablar('Mira estas figuras con calma. Cuando las recuerdes, '
          'pulsa Ya lo recuerdo.');
    });
    // La cuenta atrás es solo ORIENTATIVA: al llegar a 0 no se ocultan las
    // figuras (no penalizamos la lentitud, apunte de Laura). Solo avanza la
    // persona pulsando "Ya lo recuerdo".
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_restante > 0) {
          _restante--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _comoLista(dynamic v) => (v as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  String _idDe(Map<String, dynamic> e) =>
      (e['id'] ?? e['label'] ?? '').toString();

  String _labelDe(Map<String, dynamic> e) =>
      (e['label'] ?? e['id'] ?? '').toString();

  void _emitir() {
    int aciertos = 0;
    int fallos = 0;
    for (final id in _seleccionadas) {
      if (_idsCorrectos.contains(id)) {
        aciertos++;
      } else {
        fallos++;
      }
    }
    widget.onMetricas({
      'aciertos': aciertos,
      'fallos': fallos,
      'seleccionadas': _seleccionadas.toList(),
      'veces_volvio_a_mirar': _vecesMiradas,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  /// Deja volver a ver las figuras (reduce frustración; "nunca atrapado"). Se
  /// conservan las selecciones ya hechas y se cuenta el apoyo.
  void _volverAMirar() {
    HapticFeedback.selectionClick();
    Tts.instance.hablar('Míralas otra vez con calma.');
    setState(() {
      _memorizando = true;
      _vecesMiradas++;
    });
    widget.onListoParaAvanzar?.call(false);
  }

  void _terminarMemorizacion() {
    _timer?.cancel();
    Tts.instance.hablar('Ahora toca las figuras que estaban antes.');
    setState(() {
      _memorizando = false;
      _restante = 0;
    });
    // Ya está en la selección: ahora sí se muestra el botón global "Siguiente".
    widget.onListoParaAvanzar?.call(true);
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion = render['instruccion'] as String? ?? 'Memoriza';
    return _memorizando ? _vistaMemorizar(instruccion) : _vistaSeleccion();
  }

  Widget _vistaMemorizar(String instruccion) {
    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 12),
        // Indicador tranquilo (sin cuenta atrás roja: el número descendente
        // transmitía prisa y asustaba). Solo un recordatorio amable en verde.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          decoration: BoxDecoration(
            color: TrazoColors.sageDark,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Míralas con calma',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _rejillaTarjetas(_aRecordar, seleccionable: false)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _terminarMemorizacion,
          style: FilledButton.styleFrom(
            backgroundColor: TrazoColors.sageDark,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.check),
          label: const Text('Ya lo recuerdo'),
        ),
      ],
    );
  }

  Widget _vistaSeleccion() {
    return Column(
      children: [
        const Text('Toca las que estaban antes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 12),
        // "Volver a mirar": si no se acuerda, puede repasar en vez de quedarse
        // bloqueada o rendirse. Digno y sin prisa.
        TextButton.icon(
          onPressed: _volverAMirar,
          icon: const Icon(Icons.visibility, size: 24),
          label: const Text('Volver a mirar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(foregroundColor: TrazoColors.sageDark),
        ),
        const SizedBox(height: 8),
        Expanded(child: _rejillaTarjetas(_rejilla, seleccionable: true)),
      ],
    );
  }

  Widget _rejillaTarjetas(List<Map<String, dynamic>> items,
      {required bool seleccionable}) {
    // Rejilla que SIEMPRE cabe en pantalla (sin scroll) con tarjetas cuadradas
    // e imágenes GRANDES: se calcula el nº de columnas/filas y el tamaño de celda
    // a partir del espacio disponible; la imagen ocupa ~62% de la celda.
    final n = items.length;
    return LayoutBuilder(
      builder: (context, c) {
        // Responsive: en móvil vertical (estrecho) usamos menos columnas para que
        // las tarjetas no se hagan diminutas y no se recorten las etiquetas.
        final estrecho = c.maxWidth < 520;
        final columnas = min(
            estrecho ? (n <= 4 ? 2 : 3) : (n <= 6 ? 3 : (n <= 12 ? 4 : 5)), n);
        final filas = (n / columnas).ceil();
        final gap = estrecho ? 12.0 : 22.0;
        final anchoCelda = (c.maxWidth - gap * (columnas - 1)) / columnas;
        final altoCelda = (c.maxHeight - gap * (filas - 1)) / filas;
        // Celda cómoda: nunca por debajo de 104 (si no cabe, habrá scroll en vez
        // de recortar) ni por encima de 230.
        final lado = min(anchoCelda, altoCelda).clamp(104.0, 230.0);
        final imgSize = (lado * 0.56).clamp(44.0, 150.0);

        final filasWidgets = <Widget>[];
        for (var f = 0; f < filas; f++) {
          final celdas = <Widget>[];
          for (var col = 0; col < columnas; col++) {
            final idx = f * columnas + col;
            if (idx >= n) break; // sin celdas vacías: la última fila se centra
            if (celdas.isNotEmpty) celdas.add(SizedBox(width: gap));
            celdas.add(_celdaMemoria(items[idx], lado, imgSize, seleccionable));
          }
          if (f > 0) filasWidgets.add(SizedBox(height: gap));
          filasWidgets.add(Row(
              mainAxisAlignment: MainAxisAlignment.center, children: celdas));
        }
        final grid = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: filasWidgets);
        final altoTotal = lado * filas + gap * (filas - 1);
        // Si no cabe en alto (típico en móvil), permite SCROLL en vez de cortar.
        if (altoTotal > c.maxHeight) {
          return SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(child: grid)),
          );
        }
        return Center(child: grid);
      },
    );
  }

  Widget _celdaMemoria(Map<String, dynamic> it, double lado, double imgSize,
      bool seleccionable) {
    final id = _idDe(it);
    final sel = _seleccionadas.contains(id);
    final tieneDibujo = IlustracionResolver.tiene(id);
    return SizedBox(
      key: ValueKey('mcelda_$id'),
      width: lado,
      height: lado,
      child: InkWell(
        onTap: seleccionable
            ? () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (sel) {
                    _seleccionadas.remove(id);
                  } else {
                    _seleccionadas.add(id);
                  }
                });
                _emitir();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
            border: Border.all(
                color: sel ? TrazoColors.coralDark : TrazoColors.sand,
                width: sel ? 3 : 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tieneDibujo) ...[
                    Ilustracion(id, size: imgSize, soloDibujo: _soloDibujo),
                    const SizedBox(height: 4),
                  ],
                  // Banda de altura fija para la etiqueta: así NUNCA se recorta el
                  // texto por más pequeña que sea la tarjeta.
                  SizedBox(
                    height: tieneDibujo ? 22 : 30,
                    child: Center(
                      child: Text(_labelDe(it),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: tieneDibujo ? 16 : 22,
                              fontWeight: FontWeight.w600,
                              color: TrazoColors.ink)),
                    ),
                  ),
                ],
              ),
              if (seleccionable && sel)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.check_circle,
                      color: TrazoColors.coralDark, size: 30),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
