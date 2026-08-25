// JUGAR como usuario mayor: manejo_cantidad (dinero -> tocar monedas hasta el
// importe exacto; reloj -> poner la hora con los selectores) y trazo (seguir la
// guía con el dedo). Comprueba la MEDICIÓN emitida por cada widget.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';

import 'package:trazo_tablet/models.dart';
import 'package:trazo_tablet/widgets/manejo_cantidad_widget.dart';
import 'package:trazo_tablet/widgets/trazo_widget.dart';

List<Instancia> _cargar(String tipo) {
  final data = jsonDecode(File('test/actividades_todas.json').readAsStringSync()) as Map<String, dynamic>;
  return (data['actividades'] as List)
      .map((e) => Instancia.fromJson(Map<String, dynamic>.from(e as Map)))
      .where((i) => i.plantilla == tipo)
      .toList();
}

void main() {
  testWidgets('Jugar DINERO: componer el importe exacto con monedas mide bien', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    int jugadas = 0, ok = 0; final ej = <String>[];
    for (final inst in _cargar('manejo_cantidad')) {
      final modo = inst.render['modo']?.toString() ?? 'dinero';
      if (modo == 'reloj') continue;
      final importeC = (inst.render['importe_c'] as num?)?.toInt();
      if (importeC == null || importeC <= 0) continue;
      // Denominaciones disponibles (en céntimos).
      final denoms = <int>{};
      final dl = inst.render['denominaciones'];
      if (dl is List) {
        for (final d in dl) {
          if (d is Map && d['valor_c'] != null) denoms.add((d['valor_c'] as num).toInt());
        }
      }
      if (denoms.isEmpty) continue;
      final orden = denoms.toList()..sort((a, b) => b.compareTo(a)); // mayor->menor
      // Compone el importe exacto de forma voraz.
      final plan = <int>[]; int resto = importeC;
      for (final v in orden) { while (resto >= v) { plan.add(v); resto -= v; } }
      if (resto != 0) continue; // no alcanzable exacto con estas monedas -> se salta
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        ManejoCantidadWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      bool todo = true;
      for (final v in plan) {
        final k = find.byKey(ValueKey('moneda|$v'));
        if (k.evaluate().isEmpty) { todo = false; break; }
        await tester.ensureVisible(k.first);
        await tester.tap(k.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 6));
      }
      if (!todo) continue;
      jugadas++;
      final total = m?['total_compuesto'];
      if (total is num && (total * 100).round() == importeC) {
        ok++; if (ej.length < 5) ej.add('${inst.nombre} -> reunió ${importeC / 100} € con ${plan.length} piezas ✓');
      }
      tester.takeException();
    }
    debugPrint('### DINERO jugadas=$jugadas · importe exacto medido=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0));
  });

  testWidgets('Jugar RELOJ: poner la hora del reloj mide bien', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    int jugadas = 0, ok = 0; final ej = <String>[];
    Future<void> tapN(WidgetTester t, String key, int n) async {
      for (var i = 0; i < n; i++) {
        await t.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 4));
      }
    }
    for (final inst in _cargar('manejo_cantidad')) {
      if ((inst.render['modo']?.toString() ?? 'dinero') != 'reloj') continue;
      final hora = (inst.render['hora'] as num?)?.toInt() ?? 12;
      final minuto = (inst.render['minuto'] as num?)?.toInt() ?? 0;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        ManejoCantidadWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      // Hora: arranca en 12 (rango 1..12). Minutos: arranca en 0 (0..55 paso 5).
      var subeHora = ((hora - 12) % 12 + 12) % 12;   // nº de toques '+'
      if (subeHora == 0) subeHora = 12;              // vuelta entera para que EMITA y acabe en su sitio
      var subeMin = (minuto ~/ 5);
      if (subeMin == 0) subeMin = 12;                // 12 valores (0..55) -> vuelta entera
      await tapN(tester, 'reloj|hora|mas', subeHora);
      await tapN(tester, 'reloj|min|mas', subeMin);
      jugadas++;
      if (m?['hora_elegida'] == hora && m?['minuto_elegido'] == minuto) {
        ok++; if (ej.length < 5) ej.add('${inst.nombre} -> puso $hora:${minuto.toString().padLeft(2, '0')} ✓');
      }
      tester.takeException();
    }
    debugPrint('### RELOJ jugadas=$jugadas · hora correcta medida=$ok\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0));
  });

  testWidgets('Jugar TRAZO: seguir la guía con el dedo mide precisión alta', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    int jugadas = 0, ok = 0; final ej = <String>[]; double sumaPrec = 0;
    for (final inst in _cargar('trazo')) {
      final gp = inst.render['guide_path'];
      if (gp is! String || gp.isEmpty) continue;
      final vb = (inst.render['viewbox'] as String? ?? '0 0 300 140').split(' ');
      final vbW = (vb.length > 2 ? double.tryParse(vb[2]) : null) ?? 300;
      final vbH = (vb.length > 3 ? double.tryParse(vb[3]) : null) ?? 140;
      // Muestrea la guía igual que el widget (paso 3) para "repasarla" exacta.
      final path = parseSvgPathData(gp);
      final muestras = <Offset>[];
      for (final metric in path.computeMetrics()) {
        double d = 0;
        while (d < metric.length) {
          final t = metric.getTangentForOffset(d);
          if (t != null) muestras.add(t.position);
          d += 3.0;
        }
      }
      if (muestras.length < 2) continue;
      Map<String, dynamic>? m;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        TrazoWidget(key: ValueKey(inst.nombre), instancia: inst, onMetricas: (x) => m = x))));
      await tester.pump(const Duration(milliseconds: 40));
      // Área de dibujo (GestureDetector) y su escala/offset (idénticos al widget).
      final rect = tester.getRect(find.byKey(const ValueKey('trazo-lienzo')));
      final escala = (rect.width / vbW).clamp(0.0, rect.height / vbH);
      final ox = (rect.width - vbW * escala) / 2;
      final oy = (rect.height - vbH * escala) / 2;
      Offset aGlobal(Offset vbp) =>
          rect.topLeft + Offset(ox + vbp.dx * escala, oy + vbp.dy * escala);
      // El dedo repasa la guía punto a punto.
      final g = await tester.startGesture(aGlobal(muestras.first));
      for (final s in muestras.skip(1)) {
        await g.moveTo(aGlobal(s));
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 20));
      jugadas++;
      final prec = (m?['precision'] as num?)?.toDouble();
      if (prec != null) sumaPrec += prec;
      if (prec != null && prec >= 0.9) {
        ok++; if (ej.length < 5) ej.add('${inst.nombre} -> precisión ${prec.toStringAsFixed(2)} ✓');
      }
      tester.takeException();
    }
    debugPrint('### TRAZO jugadas=$jugadas · precisión>=0.9 en=$ok · media=${jugadas > 0 ? (sumaPrec / jugadas).toStringAsFixed(2) : "-"}\n  ${ej.join('\n  ')}');
    expect(ok, greaterThan(0));
  });
}
