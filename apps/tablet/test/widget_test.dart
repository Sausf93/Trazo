// Prueba de humo: una tablet SIN emparejar arranca en la pantalla de
// emparejamiento (lo primero y obligatorio) sin lanzar excepciones ni
// desbordar el layout.

import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/main.dart';

void main() {
  testWidgets('Arranca en el emparejamiento', (WidgetTester tester) async {
    await tester.pumpWidget(const TrazoApp());
    await tester.pump();

    // Tablet sin emparejar: se pide emparejar antes que nada.
    expect(find.text('Primero, empareja esta tablet'), findsOneWidget);
    expect(find.text('Emparejar esta tablet al centro'), findsOneWidget);
  });
}
