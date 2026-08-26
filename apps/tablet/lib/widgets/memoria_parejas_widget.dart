import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../tts.dart';
import 'ilustracion.dart';

/// Renderiza `parejas` (el clásico juego de memoria/concentración): primero se
/// ven todas las cartas destapadas un momento; al pulsar «Empezar» se giran
/// boca abajo y la persona las destapa de dos en dos buscando las iguales. Si
/// casan, se quedan; si no, se vuelven a girar. Termina al encontrar todas.
///
/// Puntúa en cliente por ERRORES (destapes fallidos), no por si acabó: dejarlo
/// a medias no es fallar (`sin_valorar`). Digno, sin prisa y sin quedarse
/// atrapado (siempre se puede «Volver a verlas»).
class MemoriaParejasWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;
  // Igual que en memoria: oculta el botón global «Siguiente» hasta terminar el
  // tablero, para no saltarse la actividad a medias.
  final ValueChanged<bool>? onListoParaAvanzar;

  const MemoriaParejasWidget(
      {super.key,
      required this.instancia,
      required this.onMetricas,
      this.onListoParaAvanzar});

  @override
  State<MemoriaParejasWidget> createState() => _MemoriaParejasWidgetState();
}

enum _Estado { abajo, arriba, emparejada }

class _Carta {
  final String id; // carta única
  final String par; // id de la pareja
  final String label;
  _Estado estado;
  _Carta(this.id, this.par, this.label, this.estado);
}

class _MemoriaParejasWidgetState extends State<MemoriaParejasWidget> {
  late final List<_Carta> _cartas;
  late final int _nPares;
  late final int _columnasBase;

  bool _preview = true; // fase inicial: se ven todas
  bool _bloqueado = false; // durante el giro tras un fallo
  int? _primera; // índice de la 1ª carta destapada esperando pareja
  int _errores = 0;
  final Set<String> _encontradas = {};
  DateTime? _inicio;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    _nPares = (render['n_pares'] as num?)?.toInt() ?? 0;
    _columnasBase = (render['columnas'] as num?)?.toInt() ?? 4;
    _cartas = ((render['cartas'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => _Carta(
              (m['carta'] ?? m['par'] ?? '').toString(),
              (m['par'] ?? '').toString(),
              (m['label'] ?? m['par'] ?? '').toString(),
              _Estado.arriba, // durante el preview se ven destapadas
            ))
        .toList();
    // Aún no se puede avanzar: primero hay que jugar el tablero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onListoParaAvanzar?.call(false);
      Tts.instance.hablar('Mira las figuras con calma y pulsa Empezar.');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _empezar() {
    HapticFeedback.selectionClick();
    Tts.instance.hablar('Ahora busca las parejas iguales, de dos en dos.');
    _timer?.cancel();
    setState(() {
      _preview = false;
      _inicio = DateTime.now();
      for (final c in _cartas) {
        if (c.estado != _Estado.emparejada) c.estado = _Estado.abajo;
      }
      _primera = null;
      _bloqueado = false;
    });
    // Nunca atrapado: una vez empieza el juego se puede avanzar aunque no cierre
    // el tablero (dejarlo a medias NO es fallar; el intento nace sin_valorar).
    widget.onListoParaAvanzar?.call(true);
  }

  /// Vuelve a mostrar todas un momento (no quedarse atrapado). Conserva las ya
  /// emparejadas y no cuenta como error; solo re-muestra las que faltan.
  void _volverAVerlas() {
    if (_bloqueado) return;
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _preview = true;
      _primera = null;
      for (final c in _cartas) {
        if (c.estado != _Estado.emparejada) c.estado = _Estado.arriba;
      }
    });
    widget.onListoParaAvanzar?.call(false);
  }

  void _emitir() {
    widget.onMetricas({
      'pares_encontrados': _encontradas.length,
      'errores': _errores,
      'tiempo_ms': _inicio == null
          ? 0
          : DateTime.now().difference(_inicio!).inMilliseconds,
    });
  }

  void _tocarCarta(int i) {
    if (_bloqueado) return;
    // Durante el preview, tocar una carta responde (háptico) para que no parezca
    // que la app se ha colgado; el juego arranca con el botón «Empezar».
    if (_preview) {
      HapticFeedback.selectionClick();
      return;
    }
    final c = _cartas[i];
    if (c.estado != _Estado.abajo) return; // ya está arriba o emparejada
    if (_primera == i) return;
    HapticFeedback.selectionClick();
    setState(() => c.estado = _Estado.arriba);

    if (_primera == null) {
      _primera = i;
      return;
    }
    // Segunda carta: ¿casan?
    final a = _cartas[_primera!];
    final b = _cartas[i];
    if (a.par == b.par) {
      HapticFeedback.mediumImpact();
      setState(() {
        a.estado = _Estado.emparejada;
        b.estado = _Estado.emparejada;
        _encontradas.add(a.par);
        _primera = null;
      });
      _emitir();
      if (_encontradas.length >= _nPares) {
        // Tablero completo: ahora sí se puede avanzar.
        widget.onListoParaAvanzar?.call(true);
      }
    } else {
      // Fallo: cuenta un error y, tras un momento para verlas, se giran.
      _errores++;
      _bloqueado = true;
      _emitir();
      final pa = _primera!;
      _primera = null;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _cartas[pa].estado = _Estado.abajo;
          _cartas[i].estado = _Estado.abajo;
          _bloqueado = false;
        });
      });
    }
  }

  bool get _completado => _encontradas.length >= _nPares;

  @override
  Widget build(BuildContext context) {
    final instruccion = widget.instancia.render['instruccion'] as String? ??
        'Encuentra las parejas iguales';
    return Column(
      children: [
        Text(
          _completado
              ? '¡Muy bien! Has encontrado todas'
              : (_preview
                  ? 'Míralas con calma y pulsa «Empezar»'
                  : instruccion),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _completado ? TrazoColors.sageDark : TrazoColors.ink),
        ),
        const SizedBox(height: 10),
        _barraEstado(),
        const SizedBox(height: 14),
        Expanded(child: _rejilla()),
        const SizedBox(height: 12),
        _accion(),
      ],
    );
  }

  Widget _barraEstado() {
    if (_preview) {
      return const SizedBox(height: 4);
    }
    // Parejas encontradas de total (sin cronómetro: nada de prisa).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: TrazoColors.sageDark,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text('Parejas: ${_encontradas.length} de $_nPares',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _accion() {
    if (_preview) {
      return FilledButton.icon(
        onPressed: _empezar,
        style: FilledButton.styleFrom(
          backgroundColor: TrazoColors.coralDark,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 15),
          textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 26),
        label: const Text('Empezar'),
      );
    }
    if (_completado) {
      return const SizedBox(height: 4);
    }
    // Durante el juego: apoyo «Volver a verlas» (digno, no quedarse atrapado).
    return TextButton.icon(
      onPressed: _bloqueado ? null : _volverAVerlas,
      icon: const Icon(Icons.visibility, size: 24),
      label: const Text('Volver a verlas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(foregroundColor: TrazoColors.sageDark),
    );
  }

  Widget _rejilla() {
    final n = _cartas.length;
    return LayoutBuilder(
      builder: (context, c) {
        // Responsive: en móvil vertical bajamos columnas para que las cartas no
        // queden diminutas (mejor scroll que recorte).
        final estrecho = c.maxWidth < 520;
        final columnas =
            min(estrecho ? min(_columnasBase, 3) : _columnasBase, n);
        final filas = (n / columnas).ceil();
        final gap = estrecho ? 10.0 : 18.0;
        final anchoCelda = (c.maxWidth - gap * (columnas - 1)) / columnas;
        final altoCelda = (c.maxHeight - gap * (filas - 1)) / filas;
        final lado = min(anchoCelda, altoCelda).clamp(84.0, 220.0);
        final imgSize = (lado * 0.58).clamp(40.0, 150.0);

        final filasWidgets = <Widget>[];
        for (var f = 0; f < filas; f++) {
          final celdas = <Widget>[];
          for (var col = 0; col < columnas; col++) {
            final idx = f * columnas + col;
            if (idx >= n) break;
            if (celdas.isNotEmpty) celdas.add(SizedBox(width: gap));
            celdas.add(_celda(idx, lado, imgSize));
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

  Widget _celda(int i, double lado, double imgSize) {
    final c = _cartas[i];
    final destapada = c.estado != _Estado.abajo;
    final emparejada = c.estado == _Estado.emparejada;
    final tieneDibujo = IlustracionResolver.tiene(c.par);

    final cara = destapada
        ? Container(
            key: ValueKey('up_${c.id}'),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: emparejada ? const Color(0xFFEDF3EE) : TrazoColors.card,
              border: Border.all(
                  color: emparejada ? TrazoColors.sageDark : TrazoColors.sand,
                  width: emparejada ? 3 : 1.5),
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
                      Ilustracion(c.par, size: imgSize),
                      const SizedBox(height: 4),
                    ],
                    SizedBox(
                      height: tieneDibujo ? 22 : 30,
                      child: Center(
                        child: Text(c.label,
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
                if (emparejada)
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(Icons.check_circle,
                        color: TrazoColors.sageDark, size: 30),
                  ),
              ],
            ),
          )
        : _reverso(c.id);

    return SizedBox(
      width: lado,
      height: lado,
      child: InkWell(
        onTap: (!_preview && !_bloqueado && c.estado == _Estado.abajo)
            ? () => _tocarCarta(i)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: cara,
        ),
      ),
    );
  }

  // Reverso de la carta: salvia con un motivo neutro (nada que distraiga ni
  // dé pistas). Todas iguales.
  Widget _reverso(String id) {
    return Container(
      key: ValueKey('down_$id'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TrazoColors.sageDark,
        border: Border.all(color: TrazoColors.sage, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.help_outline_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }
}
