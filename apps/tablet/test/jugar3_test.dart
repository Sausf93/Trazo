// JUGAR arrastrar (tocar pieza -> tocar su zona correcta) y comprobar la medición.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/models.dart';
import 'package:trazo_tablet/widgets/arrastrar_posicion_widget.dart';
import 'package:trazo_tablet/widgets/conteo_comparacion_widget.dart';
import 'package:trazo_tablet/widgets/secuencia_ordenar_widget.dart';

List<Instancia> _cargar(String tipo) {
  final data = jsonDecode(File('test/actividades_todas.json').readAsStringSync()) as Map<String, dynamic>;
  return (data['actividades'] as List)
      .map((e) => Instancia.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((i) => i.plantilla == tipo)
      .toList();
}

void main() {
  testWidgets('Jugar ARRASTRAR: colocar cada pieza en su zona mide bien', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });

    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('arrastrar_posicion')) {
      final piezas = (inst.render['piezas'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final zonas = inst.render['zonas'];
      if (piezas.isEmpty || zonas == null) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        ArrastrarPosicionWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));

      bool todo = true;
      for (final p in piezas) {
        final pid = (p['id']).toString();
        final zc = (p['zona_correcta']).toString();
        final pk = find.byKey(ValueKey('apieza|$pid'));
        final zk = find.byKey(ValueKey('azona|$zc'));
        if (pk.evaluate().isEmpty || zk.evaluate().isEmpty) { todo = false; break; }
        await tester.ensureVisible(pk);
        await tester.tap(pk, warnIfMissed: false); // coge la pieza
        await tester.pump(const Duration(milliseconds: 6));
        await tester.ensureVisible(zk);
        await tester.tap(zk, warnIfMissed: false); // la coloca en su zona
        await tester.pump(const Duration(milliseconds: 6));
      }
      if (!todo) continue;
      jugadas++;

      final col = m?['colocaciones'];
      final bien = col is Map &&
          piezas.every((p) => col[(p['id']).toString()] == (p['zona_correcta']).toString());
      if (bien) {
        ok++;
        if (ej.length < 5) ej.add('${inst.nombre} -> ${piezas.length} piezas en su zona ✓');
      }
      tester.takeException();
    }
    debugPrint('### ARRASTRAR jugadas=$jugadas · bien colocadas=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0), reason: 'jugar arrastrar debe colocar y medir bien');
  });

  testWidgets('Jugar CONTEO-COMPARACIÓN: tocar el grupo correcto', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('conteo_comparacion')) {
      final co = inst.cantidadObjetivo; final modo = co['modo']?.toString(); final sol = co['solucion'];
      if (modo != 'cual_tiene_mas' && modo != 'cual_tiene_menos') continue;
      if (sol is! Map) continue;
      final answer = (modo == 'cual_tiene_mas' ? sol['objeto_mayor'] : sol['objeto_menor'])?.toString();
      if (answer == null) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        ConteoComparacionWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      final k = find.byKey(ValueKey('cgrupo|$answer'));
      if (k.evaluate().isEmpty) continue;
      await tester.tap(k.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
      jugadas++;
      final r = m?['respuesta'];
      if (r is Map && r['objeto']?.toString() == answer) { ok++; if (ej.length < 4) ej.add('${inst.nombre} -> tocó "$answer" ✓'); }
      tester.takeException();
    }
    debugPrint('### CONTEO-COMPARACIÓN jugadas=$jugadas · bien=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0));
  });

  testWidgets('Jugar SECUENCIA: ordenar los pasos con ↑↓ mide bien', (tester) async {
    // Alto generoso (como una tablet en vertical): así las secuencias de 7 pasos
    // caben sin scroll y el toque-y-coloca es determinista.
    tester.view.physicalSize = const Size(1024, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('secuencia_ordenar')) {
      // pasos_barajados = lista de mapas {paso: "..."}; el widget usa el campo 'paso'.
      final barajados = (inst.render['pasos_barajados'] as List? ?? const [])
          .map((e) => e is Map ? (e['paso'] ?? '').toString() : e.toString()).toList();
      final target = (inst.cantidadObjetivo['orden_correcto_pasos'] as List? ?? const [])
          .map((e) => e is Map ? (e['paso'] ?? '').toString() : e.toString()).toList();
      if (barajados.isEmpty || target.length != barajados.length) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        SecuenciaOrdenarWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      // Ordena con TOCA-Y-COLOCA (la interacción nueva): para cada posición,
      // coge el paso objetivo (1er toque en su fila) y lo suelta en su sitio (2º
      // toque en la fila destino). El widget hace removeAt(cogido)+insert(destino).
      final current = List<String>.from(barajados);
      bool todo = true;
      for (var pos = 0; pos < target.length && todo; pos++) {
        final j = current.indexOf(target[pos]);
        if (j == pos) continue; // ya está en su sitio
        final kCoge = find.byKey(ValueKey('fila|$j'));
        final kSuelta = find.byKey(ValueKey('fila|$pos'));
        if (kCoge.evaluate().isEmpty || kSuelta.evaluate().isEmpty) {
          todo = false;
          break;
        }
        await tester.tap(kCoge, warnIfMissed: false); // coge
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(kSuelta, warnIfMissed: false); // suelta en su sitio
        await tester.pump(const Duration(milliseconds: 20));
        final item = current.removeAt(j);
        current.insert(pos, item); // espejo
      }
      if (!todo) continue;
      jugadas++;
      final of = (m?['orden_final'] as List?)?.map((e) => e.toString()).toList();
      if (of != null && of.length == target.length && List.generate(target.length, (k) => of[k] == target[k]).every((b) => b)) {
        ok++; if (ej.length < 5) ej.add('${inst.nombre} -> ordenada correcta ✓');
      } else if (ej.length < 8) {
        ej.add('FALLA ${inst.nombre}: target=$target final=$of espejo=$current');
      }
      tester.takeException();
    }
    debugPrint('### SECUENCIA jugadas=$jugadas · bien ordenadas=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0));
  });
}
