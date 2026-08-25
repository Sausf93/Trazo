// JUGAR como usuario (con keys precisas): búsqueda, memoria y conteo. Captura la
// medición emitida y comprueba que jugar BIEN produce la medición de acierto.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/models.dart';
import 'package:trazo_tablet/widgets/busqueda_visual_widget.dart';
import 'package:trazo_tablet/widgets/memoria_visual_widget.dart';
import 'package:trazo_tablet/widgets/conteo_comparacion_widget.dart';

List<Instancia> _cargar(String tipo) {
  final data = jsonDecode(File('test/actividades_todas.json').readAsStringSync()) as Map<String, dynamic>;
  return (data['actividades'] as List)
      .map((e) => Instancia.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((i) => i.plantilla == tipo)
      .toList();
}

void _tablet(WidgetTester t) {
  t.view.physicalSize = const Size(1024, 768);
  t.view.devicePixelRatio = 1.0;
  addTearDown(() { t.view.resetPhysicalSize(); t.view.resetDevicePixelRatio(); });
}

void main() {
  testWidgets('Jugar BÚSQUEDA: tocar los objetivos mide aciertos sin fallos', (tester) async {
    _tablet(tester);
    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('busqueda_visual')) {
      final celdas = (inst.render['celdas'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final obj = inst.render['objetivo'];
      final objId = (obj is Map ? obj['id'] : obj)?.toString() ?? '';
      final nObj = celdas.where((c) => c['id'].toString() == objId).length;
      if (nObj == 0) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: BusquedaVisualWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      // Toca por ID (la key lleva el id): celdas 'bcelda|<id>|<idx>'.
      final targets = find.byWidgetPredicate((w) {
        final k = w.key;
        if (k is! ValueKey || k.value is! String) return false;
        final parts = (k.value as String).split('|');
        return parts.length == 3 && parts[0] == 'bcelda' && parts[1] == objId;
      });
      final n = targets.evaluate().length;
      if (n != nObj) {
        if (jugadas < 3) debugPrint('DIAG búsqueda "${inst.nombre}": objId=$objId nObj=$nObj encontradas=$n totalCeldas=${celdas.length}');
        continue;
      }
      for (var j = 0; j < n; j++) {
        await tester.ensureVisible(targets.at(j));
        await tester.tap(targets.at(j), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 6));
      }
      jugadas++;
      final ac = (m?['aciertos'] ?? 0) as int, fa = (m?['fallos'] ?? 0) as int;
      if (ac == nObj && fa == 0) { ok++; if (ej.length < 4) ej.add('${inst.nombre} -> $ac aciertos, 0 fallos ✓'); }
      tester.takeException();
    }
    debugPrint('### BÚSQUEDA jugadas=$jugadas · bien medidas=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0), reason: 'el mecanismo jugar->medir debe funcionar en las que caben');
  });

  testWidgets('Jugar MEMORIA: memorizar y tocar las correctas mide bien', (tester) async {
    _tablet(tester);
    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('memoria_visual')) {
      final aRec = (inst.render['a_recordar'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final ids = aRec.map((e) => (e['id'] ?? e['label']).toString()).toList();
      if (ids.isEmpty) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MemoriaVisualWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x, onListoParaAvanzar: (_) {}))));
      await tester.pump(const Duration(milliseconds: 40));
      final btn = find.text('Ya lo recuerdo');
      if (btn.evaluate().isEmpty) continue;
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 40));
      bool todo = true;
      for (final id in ids) {
        final k = find.byKey(ValueKey('mcelda_$id'));
        if (k.evaluate().isEmpty) {
          if (jugadas <= 2) debugPrint('DIAG memoria "${inst.nombre}": no encuentra mcelda_$id · ids=$ids');
          todo = false; break;
        }
        await tester.ensureVisible(k);
        await tester.tap(k, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 6));
      }
      if (!todo) continue;
      jugadas++;
      final ac = (m?['aciertos'] ?? 0) as int, fa = (m?['fallos'] ?? 0) as int;
      if (ac == ids.length && fa == 0) { ok++; if (ej.length < 4) ej.add('${inst.nombre} -> $ac aciertos, 0 fallos ✓'); }
      tester.takeException();
    }
    debugPrint('### MEMORIA jugadas=$jugadas · bien medidas=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0), reason: 'el mecanismo jugar->medir debe funcionar en las que caben');
  });

  testWidgets('Jugar CONTEO (contar/sumar): teclear la respuesta correcta', (tester) async {
    _tablet(tester);
    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('conteo_comparacion')) {
      final co = inst.cantidadObjetivo; final modo = co['modo']?.toString(); final sol = co['solucion'];
      if (modo != 'contar' && modo != 'sumar') continue;
      if (sol is! Map) continue;
      final resp = (modo == 'contar' ? sol['cantidad'] : sol['total']);
      if (resp == null) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ConteoComparacionWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      bool todo = true;
      for (final d in resp.toString().split('')) {
        final k = find.byKey(ValueKey('tecla_$d'));
        if (k.evaluate().isEmpty) { todo = false; break; }
        await tester.tap(k, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 8));
      }
      if (!todo) continue;
      jugadas++;
      if (m != null && m!['respuesta']?.toString() == resp.toString()) { ok++; if (ej.length < 4) ej.add('${inst.nombre} ($modo) -> respondió ${m!['respuesta']} ✓'); }
      tester.takeException();
    }
    debugPrint('### CONTEO(num) jugadas=$jugadas · bien medidas=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0), reason: 'el mecanismo jugar->medir debe funcionar en las que caben');
  });
}
