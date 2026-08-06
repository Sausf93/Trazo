// Prueba de humo: la app arranca en la pantalla de acceso del personal
// (sin token guardado) sin lanzar excepciones.

import 'package:flutter_test/flutter_test.dart';

import 'package:trazo_tablet/main.dart';

void main() {
  testWidgets('Arranca en el acceso del personal', (WidgetTester tester) async {
    await tester.pumpWidget(const TrazoApp());

    // La pantalla de login muestra el título y el botón de entrar.
    expect(find.text('Trazo'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
