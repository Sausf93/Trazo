import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `manejo_cantidad` según su `modo`:
///  - dinero / vuelta: botones de monedas que se van sumando; muestra el
///    acumulado. Registra {total_compuesto, monedas_usadas}.
///  - reloj: reloj analógico que marca hora:minuto; la persona indica la hora
///    con selectores. Registra {hora_elegida, minuto_elegido}.
/// No se autocorrige en cliente.
class ManejoCantidadWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const ManejoCantidadWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<ManejoCantidadWidget> createState() => _ManejoCantidadWidgetState();
}

class _ManejoCantidadWidgetState extends State<ManejoCantidadWidget> {
  final DateTime _inicio = DateTime.now();

  // dinero / vuelta — SIEMPRE en céntimos enteros (evita la basura de coma
  // flotante al sumar euros como double: 0,10+0,20 = 0.30000000000000004).
  int _acumuladoC = 0;
  final List<int> _monedasUsadasC = [];
  // Objetivo en céntimos, para confirmar cuándo la persona lo ha alcanzado.
  int? _objetivoC;

  // reloj
  int _horaElegida = 12;
  int _minutoElegido = 0;

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    // El reloj NO se auto-registra: si la persona no toca ningún selector, el
    // intento debe quedar 'sin_valorar' (no tocó nada), no 'no_logrado' (12:00).
    // Solo emite al mover un selector (_emitirReloj en onChanged).
    final imp = render['importe_c'];
    if (imp is num) _objetivoC = imp.toInt();
  }

  bool get _objetivoAlcanzado =>
      _objetivoC != null && _acumuladoC == _objetivoC;

  void _emitirDinero() {
    // El contrato con el backend sigue siendo en EUROS (correccion.py acepta
    // euros o céntimos); se deriva de los céntimos sin error de redondeo.
    widget.onMetricas({
      'total_compuesto': _acumuladoC / 100,
      'monedas_usadas': _monedasUsadasC.map((c) => c / 100).toList(),
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  void _emitirReloj() {
    widget.onMetricas({
      'hora_elegida': _horaElegida,
      'minuto_elegido': _minutoElegido,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final modo = render['modo'] as String? ?? 'dinero';
    if (modo == 'reloj') return _vistaReloj(render);
    return _vistaDinero(render, modo);
  }

  // --- Dinero / vuelta ---
  Widget _vistaDinero(Map<String, dynamic> render, String modo) {
    final instruccion = render['instruccion'] as String? ?? 'Junta el dinero';
    final denoms = _denominacionesC(render);
    final objetivoTexto = _objetivoTexto(render);

    final tituloW = Text(instruccion,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, color: TrazoColors.ink));
    final objetivoW = objetivoTexto == null
        ? null
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: TrazoColors.sageDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Tienes que reunir',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
                const SizedBox(height: 2),
                Text(objetivoTexto,
                    style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          );
    final llevasW = Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: _objetivoAlcanzado
            ? TrazoColors.sage.withValues(alpha: 0.22)
            : TrazoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _objetivoAlcanzado ? TrazoColors.sageDark : TrazoColors.sand,
            width: _objetivoAlcanzado ? 2.5 : 1.5),
      ),
      child: Column(
        children: [
          Text(_objetivoAlcanzado ? '¡Justo! Llevas' : 'Llevas',
              style:
                  const TextStyle(fontSize: 18, color: TrazoColors.sageDark)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_objetivoAlcanzado) ...[
                const Icon(Icons.check_circle,
                    color: TrazoColors.sageDark, size: 40),
                const SizedBox(width: 8),
              ],
              Text('${_fmtEurC(_acumuladoC)} €',
                  style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: _objetivoAlcanzado
                          ? TrazoColors.sageDark
                          : TrazoColors.coralDark)),
            ],
          ),
        ],
      ),
    );
    final monedasW = Center(
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: denoms.map((c) => _pieza(c)).toList(),
      ),
    );
    final botonesW = Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Deshacer solo la última: un toque de más no obliga a rehacerlo todo.
        OutlinedButton.icon(
          onPressed: _monedasUsadasC.isEmpty
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final ultima = _monedasUsadasC.removeLast();
                    _acumuladoC -= ultima;
                    if (_acumuladoC < 0) _acumuladoC = 0;
                  });
                  _emitirDinero();
                },
          icon: const Icon(Icons.undo),
          label: const Text('Quitar la última'),
          style: _estiloBotonRescate(),
        ),
        OutlinedButton.icon(
          onPressed: _acumuladoC == 0
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _acumuladoC = 0;
                    _monedasUsadasC.clear();
                  });
                  _emitirDinero();
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Empezar de nuevo'),
          style: _estiloBotonRescate(),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final estrecho = c.maxWidth < 520 || c.maxHeight < 640;
        // Móvil: TODO en scroll de página (carteles + monedas + botones), para que
        // las monedas nunca se queden fuera de pantalla bajo los carteles grandes.
        if (estrecho) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),
                tituloW,
                if (objetivoW != null) ...[
                  const SizedBox(height: 16),
                  objetivoW,
                ],
                const SizedBox(height: 16),
                llevasW,
                const SizedBox(height: 16),
                monedasW,
                const SizedBox(height: 16),
                botonesW,
                const SizedBox(height: 8),
              ],
            ),
          );
        }
        // Tablet: carteles arriba, monedas ocupan el resto (con scroll interno).
        return Column(
          children: [
            tituloW,
            if (objetivoW != null) ...[
              const SizedBox(height: 16),
              objetivoW,
            ],
            const SizedBox(height: 20),
            llevasW,
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: monedasW)),
            const SizedBox(height: 12),
            botonesW,
          ],
        );
      },
    );
  }

  /// Denominaciones disponibles en CÉNTIMOS. Prefiere `denominaciones`
  /// (formato actual del backend: [{valor_c, etiqueta}]); si no, acepta el
  /// formato antiguo `monedas` (lista de euros). Ordena de menor a mayor.
  List<int> _denominacionesC(Map<String, dynamic> render) {
    final set = <int>{};
    final denom = render['denominaciones'];
    if (denom is List) {
      for (final d in denom) {
        if (d is Map && d['valor_c'] != null) {
          set.add((d['valor_c'] as num).toInt());
        } else if (d is num) {
          set.add((d * 100).round());
        }
      }
    }
    if (set.isEmpty) {
      final monedas = render['monedas'];
      if (monedas is List) {
        for (final m in monedas) {
          if (m is num) set.add((m * 100).round());
        }
      }
    }
    if (set.isEmpty) {
      set.addAll([1, 2, 5, 10, 20, 50, 100, 200].map((e) => e * 1));
    }
    final lista = set.where((c) => c > 0).toList()..sort();
    return lista;
  }

  /// Una pieza de dinero (moneda o billete) con su ilustración; al tocarla se
  /// suma su valor al acumulado.
  Widget _pieza(int valorC) {
    final esBillete = valorC >= 500;
    final id = IlustracionResolver.dineroPorCentimos(valorC);
    return InkWell(
      key: ValueKey('moneda|$valorC'),
      onTap: () {
        setState(() {
          _acumuladoC += valorC;
          _monedasUsadasC.add(valorC);
        });
        // Háptico distinto al ACERTAR el importe exacto (confirma "¡ya está!").
        if (_objetivoAlcanzado) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
        _emitirDinero();
      },
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        label: _etiquetaDenom(valorC),
        button: true,
        child: id != null
            ? Ilustracion(id, size: esBillete ? 118 : 82)
            : _piezaFallback(valorC),
      ),
    );
  }

  Widget _piezaFallback(int valorC) {
    return Container(
      width: 82,
      height: 82,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE0A94A),
        border: Border.all(color: const Color(0xFFB8912F), width: 3),
      ),
      child: Text(_etiquetaDenom(valorC),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C4A15))),
    );
  }

  String _etiquetaDenom(int c) {
    if (c < 100) return '$c céntimos';
    if (c % 100 == 0) return '${c ~/ 100} €';
    return '${c ~/ 100},${(c % 100).toString().padLeft(2, '0')} €';
  }

  /// Formatea céntimos como euros con coma decimal española ('6,82'). Igual que
  /// el backend (_fmt_eur): evita el 'punto' ajeno y la basura de coma flotante.
  String _fmtEurC(int c) =>
      '${c ~/ 100},${(c % 100).toString().padLeft(2, '0')}';

  /// Botones de rescate del dinero grandes y con buen contraste (son la red de
  /// seguridad ante un toque de más con temblor: deben leerse y acertarse).
  ButtonStyle _estiloBotonRescate() => OutlinedButton.styleFrom(
        foregroundColor: TrazoColors.sageDark,
        side: const BorderSide(color: TrazoColors.sand, width: 1.5),
        textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      );

  /// Objetivo a reunir, bien visible. Usa el texto del backend
  /// (`importe_texto`) o, si no, formatea `importe_c` (céntimos).
  String? _objetivoTexto(Map<String, dynamic> render) {
    final texto = render['importe_texto'];
    if (texto is String && texto.isNotEmpty) return texto;
    final c = render['importe_c'];
    if (c is num) return _etiquetaDenom(c.toInt());
    return null;
  }

  // --- Reloj ---
  Widget _vistaReloj(Map<String, dynamic> render) {
    final instruccion = render['instruccion'] as String? ?? '¿Qué hora marca?';
    final hora = (render['hora'] as num?)?.toInt() ?? 12;
    final minuto = (render['minuto'] as num?)?.toInt() ?? 0;

    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 8),
        const Text('Mira el reloj y pon la misma hora abajo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: TrazoColors.sageDark)),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _RelojPainter(hora: hora, minuto: minuto),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Wrap (no Row) para que en móvil estrecho los dos selectores bajen a
        // una segunda línea en vez de desbordar la pantalla.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            _selector('Hora', _horaElegida, 1, 12, (v) {
              setState(() => _horaElegida = v);
              _emitirReloj();
            }, clave: 'hora'),
            _selector('Minutos', _minutoElegido, 0, 55, (v) {
              setState(() => _minutoElegido = v);
              _emitirReloj();
            }, paso: 5, clave: 'min'),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _selector(
      String label, int valor, int min, int max, ValueChanged<int> onChanged,
      {int paso = 1, String? clave}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, color: TrazoColors.sageDark)),
        Row(
          children: [
            _btnRedondo(Icons.remove, () {
              HapticFeedback.selectionClick();
              final v = valor - paso;
              onChanged(v < min ? max : v);
            }, clave: clave == null ? null : 'reloj|$clave|menos'),
            Container(
              width: 72,
              alignment: Alignment.center,
              child: Text(valor.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: TrazoColors.ink)),
            ),
            _btnRedondo(Icons.add, () {
              HapticFeedback.selectionClick();
              final v = valor + paso;
              onChanged(v > max ? min : v);
            }, clave: clave == null ? null : 'reloj|$clave|mas'),
          ],
        ),
      ],
    );
  }

  Widget _btnRedondo(IconData icon, VoidCallback onTap, {String? clave}) {
    return SizedBox(
      key: clave == null ? null : ValueKey(clave),
      width: 64,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: TrazoColors.sageDark,
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 32, color: Colors.white),
      ),
    );
  }
}

class _RelojPainter extends CustomPainter {
  final int hora;
  final int minuto;

  _RelojPainter({required this.hora, required this.minuto});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) / 2 - 10;

    // Esfera blanca con borde grueso (todo escalado al radio para verse bien a
    // cualquier tamaño). Reloj analógico CLÁSICO: las dos agujas oscuras (la de
    // la hora gruesa y corta, la del minuto fina y larga), como un reloj de pared.
    canvas.drawCircle(centro, radio,
        Paint()..color = TrazoColors.white);
    canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radio * 0.05
          ..color = TrazoColors.ink);

    // Marcas: 60 rayitas; las de las horas gruesas y oscuras, las de los minutos
    // finas y suaves.
    for (int i = 0; i < 60; i++) {
      final a = (i / 60) * 2 * math.pi - math.pi / 2;
      final esHora = i % 5 == 0;
      final ini = radio * (esHora ? 0.90 : 0.95);
      canvas.drawLine(
          centro + Offset(math.cos(a), math.sin(a)) * ini,
          centro + Offset(math.cos(a), math.sin(a)) * (radio * 0.98),
          Paint()
            ..strokeWidth = esHora ? radio * 0.03 : radio * 0.012
            ..color = esHora ? TrazoColors.ink : TrazoColors.sage);
    }

    // Números grandes (1..12).
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final a = (i / 12) * 2 * math.pi - math.pi / 2;
      tp.text = TextSpan(
          text: '$i',
          style: TextStyle(
              fontSize: radio * 0.17,
              fontWeight: FontWeight.w800,
              color: TrazoColors.ink));
      tp.layout();
      final pos = centro + Offset(math.cos(a), math.sin(a)) * (radio * 0.78);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Aguja de la hora: gruesa y corta.
    final anguloHora =
        ((hora % 12) + minuto / 60) / 12 * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
        centro,
        centro + Offset(math.cos(anguloHora), math.sin(anguloHora)) * radio * 0.52,
        Paint()
          ..strokeWidth = radio * 0.055
          ..strokeCap = StrokeCap.round
          ..color = TrazoColors.ink);

    // Aguja de los minutos: fina y larga.
    final anguloMin = (minuto / 60) * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
        centro,
        centro + Offset(math.cos(anguloMin), math.sin(anguloMin)) * radio * 0.80,
        Paint()
          ..strokeWidth = radio * 0.03
          ..strokeCap = StrokeCap.round
          ..color = TrazoColors.ink);

    canvas.drawCircle(centro, radio * 0.05, Paint()..color = TrazoColors.ink);
    canvas.drawCircle(centro, radio * 0.022, Paint()..color = TrazoColors.coralDark);
  }

  @override
  bool shouldRepaint(_RelojPainter old) =>
      old.hora != hora || old.minuto != minuto;
}
