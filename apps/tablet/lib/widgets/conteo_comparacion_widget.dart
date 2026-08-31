import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import 'ilustracion.dart';

/// Renderiza `conteo_comparacion`: pinta los grupos (cada objeto como un emoji
/// repetido `cantidad` veces). Según `modo`:
///  - cual_tiene_mas: la persona toca el grupo que cree mayor.
///  - contar / sumar: introduce un número con el teclado numérico grande.
/// No se autocorrige → registra {respuesta, modo}.
class ConteoComparacionWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const ConteoComparacionWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<ConteoComparacionWidget> createState() =>
      _ConteoComparacionWidgetState();
}

class _ConteoComparacionWidgetState extends State<ConteoComparacionWidget> {
  final DateTime _inicio = DateTime.now();
  int? _grupoElegido;
  String _numero = '';
  // Coherencia visual: si NO todas las figuras de la actividad tienen foto,
  // se pintan TODAS como dibujo (nunca mezclar fotos y dibujos en la misma).
  late final bool _soloDibujo;

  @override
  void initState() {
    super.initState();
    final ids = (widget.instancia.render['grupos'] as List? ?? [])
        .whereType<Map>()
        .map((e) => (e['objeto'] ?? '').toString())
        .where((s) => s.isNotEmpty);
    _soloDibujo = !IlustracionResolver.todasConFoto(ids);
  }

  void _emitir(dynamic respuesta) {
    widget.onMetricas({
      'respuesta': respuesta,
      'modo': widget.instancia.render['modo'],
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion =
        render['instruccion'] as String? ?? '¿Cuál tiene más?';
    final modo = render['modo'] as String? ?? 'cual_tiene_mas';
    // 'cual_tiene_mas' y 'cual_tiene_menos' se responden TOCANDO un grupo; solo
    // 'sumar' y 'contar' usan el teclado numérico. (Antes 'menos' caía al teclado
    // y su respuesta nunca cuadraba -> siempre no_logrado e irresoluble.)
    final esComparacion = modo == 'cual_tiene_mas' || modo == 'cual_tiene_menos';
    final grupos = (render['grupos'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final grupoRow = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < grupos.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _grupoCard(i, grupos[i], seleccionable: esComparacion),
            ),
          ),
      ],
    );
    final titulo = Text(instruccion,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, color: TrazoColors.ink));

    return LayoutBuilder(
      builder: (context, c) {
        final estrecho = c.maxWidth < 520 || c.maxHeight < 640;
        // Móvil: todo en SCROLL, con las figuras en una altura fija cómoda y el
        // teclado debajo (así no se solapan ni quedan fuera de pantalla).
        if (estrecho) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),
                titulo,
                const SizedBox(height: 16),
                SizedBox(height: esComparacion ? 320 : 240, child: grupoRow),
                if (!esComparacion) ...[
                  const SizedBox(height: 16),
                  _tecladoNumerico(),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        }
        // Tablet: layout que llena la pantalla.
        return Column(
          children: [
            titulo,
            const SizedBox(height: 20),
            Expanded(child: grupoRow),
            if (!esComparacion) ...[
              const SizedBox(height: 16),
              _tecladoNumerico(),
            ],
          ],
        );
      },
    );
  }

  Widget _grupoCard(int i, Map<String, dynamic> grupo,
      {required bool seleccionable}) {
    final objeto = (grupo['objeto'] ?? '').toString();
    final cantidad = (grupo['cantidad'] as num?)?.toInt() ?? 0;
    final sel = _grupoElegido == i;

    return InkWell(
      key: ValueKey('cgrupo|$objeto'),
      onTap: seleccionable
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _grupoElegido = i);
              _emitir({'grupo': i, 'objeto': objeto});
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFBEFE4) : TrazoColors.card,
          border: Border.all(
              color: sel ? TrazoColors.coralDark : TrazoColors.sand,
              width: sel ? 3 : 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Marca de "elegido" (además del borde) para que sea inequívoco.
            SizedBox(
              height: 26,
              child: sel
                  ? const Icon(Icons.check_circle,
                      color: TrazoColors.coralDark, size: 24)
                  : null,
            ),
            // Los objetos a contar SIEMPRE se ven enteros: se ajusta su tamaño
            // para que quepan todos sin scroll (nunca ocultar lo que hay que contar).
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final s = _tamObjeto(c.maxWidth, c.maxHeight, cantidad);
                  return Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(
                        cantidad,
                        (_) => Ilustracion(objeto, size: s, soloDibujo: _soloDibujo),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Sin etiqueta de texto bajo el grupo: la persona cuenta lo que VE.
            // (Nombres como "moneda dorada" solo confundían al mayor.)
          ],
        ),
      ),
    );
  }

  Widget _tecladoNumerico() {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          width: 160,
          decoration: BoxDecoration(
            color: TrazoColors.white,
            border: Border.all(color: TrazoColors.bordeControl, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_numero.isEmpty ? '—' : _numero,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: TrazoColors.ink)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16, // más aire entre teclas (temblor)
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
              _tecla(d, () {
                setState(() => _numero += d);
                _emitir(int.tryParse(_numero));
              }),
            _tecla('⌫', () {
              setState(() => _numero = _numero.isEmpty
                  ? ''
                  : _numero.substring(0, _numero.length - 1));
              _emitir(int.tryParse(_numero));
            }),
          ],
        ),
      ],
    );
  }

  Widget _tecla(String label, VoidCallback onTap) {
    return SizedBox(
      key: ValueKey('tecla_$label'),
      width: 66,
      height: 62,
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.selectionClick(); // confirma el toque (temblor)
          onTap();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: TrazoColors.ink,
          side: const BorderSide(color: TrazoColors.bordeControl, width: 1.5),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

/// Tamaño de cada objeto para que los `n` quepan en un área `w`×`h` SIN scroll
/// (nunca ocultar objetos que hay que contar). Baja el tamaño hasta que caben.
double _tamObjeto(double w, double h, int n, {double sp = 4}) {
  if (n <= 0 || w <= 0 || h <= 0) return 40;
  // Suelo de 26px (antes 18): contar figuras diminutas es muy exigente para
  // baja visión; se prioriza que lo contable se vea aun a costa de apretar.
  for (double s = 62; s >= 26; s -= 2) {
    final cols = ((w + sp) / (s + sp)).floor().clamp(1, n);
    final rows = (n / cols).ceil();
    if (rows * (s + sp) <= h + sp) return s;
  }
  return 26;
}
