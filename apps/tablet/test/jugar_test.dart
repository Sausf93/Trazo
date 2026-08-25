// JUGAR como usuario: pulsa la respuesta CORRECTA en cada actividad de selección
// y comprueba que el widget EMITE la medición esperada (eleccion == correcta, que
// la autocorrección del backend puntúa como 'logrado'). Es el eslabón real
// "jugar -> medir" a nivel de widget, sobre TODAS las actividades de selección.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/models.dart';
import 'package:trazo_tablet/widgets/seleccion_multiple_widget.dart';

void main() {
  late List<Instancia> seleccion;
  setUpAll(() {
    final txt = File('test/actividades_todas.json').readAsStringSync();
    final data = jsonDecode(txt) as Map<String, dynamic>;
    seleccion = (data['actividades'] as List)
        .map((e) => Instancia.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((i) => i.plantilla == 'seleccion_multiple')
        .toList();
  });

  testWidgets('Jugar TODAS las de selección: la respuesta correcta se mide bien',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 768); // tablet
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    int jugadas = 0, correctas = 0, sinCorrecta = 0;
    final ejemplos = <String>[];

    for (final inst in seleccion) {
      final correcta = inst.cantidadObjetivo['correcta']?.toString();
      final opciones =
          (inst.render['opciones'] as List? ?? const []).map((e) => e.toString()).toList();
      if (correcta == null || !opciones.contains(correcta)) {
        sinCorrecta++;
        continue;
      }
      Map<String, dynamic>? emitido;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SeleccionMultipleWidget(
            key: ValueKey(inst.nombre),
            instancia: inst,
            onMetricas: (m) => emitido = m,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 40));

      // La persona toca la opción CORRECTA.
      final f = find.text(correcta);
      if (f.evaluate().isEmpty) {
        sinCorrecta++;
        continue;
      }
      await tester.tap(f.last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 40));
      jugadas++;

      // Medición emitida por el widget al jugar bien:
      if (emitido != null && emitido!['eleccion']?.toString() == correcta) {
        correctas++;
        if (ejemplos.length < 5) {
          ejemplos.add('${inst.nombre} -> eligió "${emitido!['eleccion']}" (correcta) ✓');
        }
      } else {
        debugPrint('FALLO medición: ${inst.nombre} -> emitido=$emitido esperado=$correcta');
      }
      tester.takeException();
    }

    debugPrint('### JUGADAS ${jugadas} de selección · MEDICIÓN CORRECTA en $correctas · sin correcta jugable: $sinCorrecta');
    debugPrint('### Ejemplos de medición real al jugar:\n  ${ejemplos.join('\n  ')}');
    // Todas las jugadas deben medir bien (jugar correcto -> eleccion=correcta -> logrado).
    expect(correctas, jugadas,
        reason: 'Alguna jugada correcta no emitió la medición esperada');
    expect(jugadas, greaterThan(100), reason: 'Se jugaron pocas (¿fixture?)');
  });
}
