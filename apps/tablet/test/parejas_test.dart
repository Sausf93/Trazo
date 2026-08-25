// Prueba de comportamiento del juego de PAREJAS: preview -> Empezar (se giran)
// -> destapar de dos en dos -> acierto (se queda) -> completar el tablero.
// Verifica las métricas emitidas y el candado de «avanzar».
//
// Tablero fijo (2 parejas) para tocar posiciones concretas:
//   pos0=A  pos1=B  pos2=A  pos3=B

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/models.dart';
import 'package:trazo_tablet/widgets/memoria_parejas_widget.dart';

Instancia _inst() => Instancia(
      ejercicioId: 'test',
      nombre: 'Parejas de prueba',
      bloque: 'atencion_memoria',
      plantilla: 'parejas',
      render: {
        'instruccion': 'Encuentra las parejas iguales',
        'columnas': 2,
        'n_pares': 2,
        'segundos_preview': 5,
        'cartas': [
          {'carta': 'A_0', 'par': 'A', 'label': 'manzana'},
          {'carta': 'B_0', 'par': 'B', 'label': 'pera'},
          {'carta': 'A_1', 'par': 'A', 'label': 'manzana'},
          {'carta': 'B_1', 'par': 'B', 'label': 'pera'},
        ],
      },
      cantidadObjetivo: const {'n_pares': 2, 'n_cartas': 4},
      metricas: const ['pares_encontrados', 'errores', 'tiempo_ms'],
    );

// Toca la carta en la posición [i] (0..3): las cartas son las InkWell cuyo
// tamaño renderizado es cuadrado y grande (>70px), en orden de aparición.
Future<void> _tapCarta(WidgetTester tester, int i) async {
  final cartas = find.byType(InkWell).evaluate().where((e) {
    final s = e.size;
    return s != null && s.width > 70 && (s.width - s.height).abs() < 4;
  }).toList();
  expect(cartas.length >= i + 1, isTrue,
      reason: 'se esperaban >= ${i + 1} cartas, hay ${cartas.length}');
  await tester.tap(find.byWidget(cartas[i].widget));
}

void main() {
  testWidgets('Parejas: acierto y tablero completo', (tester) async {
    Map<String, dynamic> ultimas = {};
    bool? puedeAvanzar;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MemoriaParejasWidget(
          instancia: _inst(),
          onMetricas: (m) => ultimas = m,
          onListoParaAvanzar: (v) => puedeAvanzar = v,
        ),
      ),
    ));
    await tester.pump();

    // Fase preview: se ve «Empezar» y aún NO se puede avanzar.
    expect(find.text('Empezar'), findsOneWidget);
    expect(puedeAvanzar, isFalse);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 de 2'), findsOneWidget);

    // ACIERTO: pos0 (A) + pos2 (A).
    await _tapCarta(tester, 0);
    await tester.pump();
    await _tapCarta(tester, 2);
    await tester.pumpAndSettle();
    expect(ultimas['pares_encontrados'], 1);
    expect(ultimas['errores'], 0);
    expect(find.textContaining('1 de 2'), findsOneWidget);

    // Segundo acierto: pos1 (B) + pos3 (B) -> tablero completo.
    await _tapCarta(tester, 1);
    await tester.pump();
    await _tapCarta(tester, 3);
    await tester.pumpAndSettle();

    expect(ultimas['pares_encontrados'], 2);
    expect(puedeAvanzar, isTrue);
    expect(find.textContaining('¡Muy bien!'), findsOneWidget);
  });

  testWidgets('Parejas: fallo cuenta error y se giran', (tester) async {
    Map<String, dynamic> ultimas = {};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MemoriaParejasWidget(
          instancia: _inst(),
          onMetricas: (m) => ultimas = m,
          onListoParaAvanzar: (_) {},
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    // FALLO: pos0 (A) + pos1 (B) no casan -> error, y tras el giro vuelven boca
    // abajo (no queda ninguna "manzana"/"pera" visible).
    await _tapCarta(tester, 0);
    await tester.pump();
    await _tapCarta(tester, 1);
    await tester.pump(); // registra el fallo
    expect(ultimas['errores'], 1);
    expect(ultimas['pares_encontrados'], 0);

    // Pasa el tiempo del giro (2 s) y la transición: las cartas se ocultan.
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    expect(find.text('manzana'), findsNothing);
    expect(find.text('pera'), findsNothing);
    expect(find.textContaining('0 de 2'), findsOneWidget);
  });
}
