import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

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

  // dinero / vuelta
  num _acumulado = 0;
  final List<num> _monedasUsadas = [];

  // reloj
  int _horaElegida = 12;
  int _minutoElegido = 0;

  void _emitirDinero() {
    widget.onMetricas({
      'total_compuesto': _acumulado,
      'monedas_usadas': List<num>.from(_monedasUsadas),
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
    final monedas = (render['monedas'] as List? ?? [1, 2, 5])
        .map((e) => e as num)
        .toList();

    return Column(
      children: [
        Text(instruccion,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, color: TrazoColors.ink)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: TrazoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TrazoColors.sand, width: 1.5),
          ),
          child: Column(
            children: [
              const Text('Llevas',
                  style: TextStyle(fontSize: 18, color: TrazoColors.sageDark)),
              Text('${_formato(_acumulado)} €',
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: TrazoColors.coralDark)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: monedas.map((m) => _moneda(m)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _acumulado == 0
              ? null
              : () {
                  setState(() {
                    _acumulado = 0;
                    _monedasUsadas.clear();
                  });
                  _emitirDinero();
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Empezar de nuevo'),
        ),
      ],
    );
  }

  Widget _moneda(num valor) {
    return InkWell(
      onTap: () {
        setState(() {
          _acumulado += valor;
          _monedasUsadas.add(valor);
        });
        _emitirDinero();
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF0D98C), Color(0xFFD9B24C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFB8912F), width: 3),
        ),
        child: Text('${_formato(valor)} €',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C4A15))),
      ),
    );
  }

  String _formato(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _selector('Hora', _horaElegida, 1, 12, (v) {
              setState(() => _horaElegida = v);
              _emitirReloj();
            }),
            const SizedBox(width: 24),
            _selector('Minutos', _minutoElegido, 0, 55, (v) {
              setState(() => _minutoElegido = v);
              _emitirReloj();
            }, paso: 5),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _selector(String label, int valor, int min, int max,
      ValueChanged<int> onChanged,
      {int paso = 1}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, color: TrazoColors.sageDark)),
        Row(
          children: [
            _btnRedondo(Icons.remove, () {
              final v = valor - paso;
              onChanged(v < min ? max : v);
            }),
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
              final v = valor + paso;
              onChanged(v > max ? min : v);
            }),
          ],
        ),
      ],
    );
  }

  Widget _btnRedondo(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: TrazoColors.sage,
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 28, color: Colors.white),
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
    final radio = math.min(size.width, size.height) / 2 - 8;

    final esfera = Paint()
      ..style = PaintingStyle.fill
      ..color = TrazoColors.white;
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = TrazoColors.sageDark;
    canvas.drawCircle(centro, radio, esfera);
    canvas.drawCircle(centro, radio, borde);

    // Marcas y números.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angulo = (i / 12) * 2 * math.pi - math.pi / 2;
      final marcaEx = centro +
          Offset(math.cos(angulo), math.sin(angulo)) * radio;
      final marcaIn = centro +
          Offset(math.cos(angulo), math.sin(angulo)) * (radio - 14);
      canvas.drawLine(
          marcaIn,
          marcaEx,
          Paint()
            ..strokeWidth = 3
            ..color = TrazoColors.sand);

      tp.text = TextSpan(
          text: '$i',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: TrazoColors.ink));
      tp.layout();
      final posNum = centro +
          Offset(math.cos(angulo), math.sin(angulo)) * (radio - 36);
      tp.paint(canvas,
          posNum - Offset(tp.width / 2, tp.height / 2));
    }

    // Aguja de la hora.
    final anguloHora =
        ((hora % 12) + minuto / 60) / 12 * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
        centro,
        centro + Offset(math.cos(anguloHora), math.sin(anguloHora)) * radio * 0.5,
        Paint()
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = TrazoColors.ink);

    // Aguja de los minutos.
    final anguloMin = (minuto / 60) * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
        centro,
        centro + Offset(math.cos(anguloMin), math.sin(anguloMin)) * radio * 0.78,
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = TrazoColors.coralDark);

    canvas.drawCircle(centro, 8, Paint()..color = TrazoColors.sageDark);
  }

  @override
  bool shouldRepaint(_RelojPainter old) =>
      old.hora != hora || old.minuto != minuto;
}
