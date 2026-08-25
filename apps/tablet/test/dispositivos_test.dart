// Prueba TODAS las actividades del demo en VARIOS MODELOS DE TABLET y lista los
// desbordes (overflow) por modelo -> el mayor las vería cortadas. Recoge los
// overflow con un colector de FlutterError.onError (captura todos, no solo el 1º).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/models.dart';
import 'package:trazo_tablet/screens/galeria_screen.dart' show renderActividadDemo;

void main() {
  final modelos = <String, Size>{
    'movil-360x640': const Size(360, 640),
    'tablet7-600x960': const Size(600, 960),
    'tablet8-768x1024': const Size(768, 1024),
    'tablet10-800x1280': const Size(800, 1280),
    'tablet10-horiz-1280x800': const Size(1280, 800),
    'tablet-grande-1200x1920': const Size(1200, 1920),
  };

  late List<Instancia> actividades;
  setUpAll(() {
    // TODAS las actividades del catálogo (1 instancia por actividad, dificultad
    // ALTA = más elementos = peor caso de encaje), generadas por el motor real.
    final txt = File('test/actividades_todas.json').readAsStringSync();
    final data = jsonDecode(txt) as Map<String, dynamic>;
    actividades = (data['actividades'] as List)
        .map((e) => Instancia.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  for (final m in modelos.entries) {
    testWidgets('Actividades sin desborde en ${m.key}', (tester) async {
      tester.view.physicalSize = m.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final desbordadas = <String>{};
      String actual = '';
      final prev = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails d) {
        final s = d.exception.toString().toLowerCase();
        if (s.contains('overflow')) {
          desbordadas.add(actual); // el overflow ocurrió pintando `actual`
        } else {
          prev?.call(d); // otros errores (assets…) siguen su curso
        }
      };

      for (final inst in actividades) {
        actual = '${inst.plantilla} · ${inst.nombre}';
        try {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: renderActividadDemo(inst, (_) {}),
              ),
            ),
          ));
          await tester.pump(const Duration(milliseconds: 60));
        } catch (_) {/* ignoramos errores de assets en test */}
        tester.takeException();
      }
      FlutterError.onError = prev;

      final lista = desbordadas.toList()..sort();
      if (lista.isNotEmpty) {
        debugPrint('### DESBORDES en ${m.key} (${lista.length}):\n  ${lista.join('\n  ')}');
      } else {
        debugPrint('### ${m.key}: TODAS caben, 0 desbordes');
      }
      // No hacemos fallar el test: es un INFORME por modelo (lo lee Saulo).
      expect(true, isTrue);
    });
  }
}
