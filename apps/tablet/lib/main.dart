import 'package:flutter/material.dart';

import 'api/client.dart';
import 'screens/login_screen.dart';
import 'screens/rol_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.cargarSesionGuardada();
  runApp(const TrazoApp());
}

class TrazoApp extends StatelessWidget {
  const TrazoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trazo',
      debugShowCheckedModeBanner: false,
      theme: buildTrazoTheme(),
      // Texto un 15% más grande en toda la app (público mayor), respetando
      // ampliaciones de accesibilidad del sistema si son mayores.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final escala = mq.textScaler.scale(1.0);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(escala < 1.15 ? 1.15 : escala),
          ),
          child: child!,
        );
      },
      // El login se pide UNA sola vez: si ya hay token, se va directo a
      // elegir el rol de la tablet (maestra o participante).
      home: ApiClient.instance.autenticado
          ? const RolScreen()
          : const LoginScreen(),
    );
  }
}
