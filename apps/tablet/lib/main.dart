import 'package:flutter/material.dart';

import 'api/client.dart';
import 'screens/login_screen.dart';
import 'screens/rol_screen.dart';
import 'theme.dart';

/// Para poder navegar al login desde fuera del árbol de widgets (p. ej. cuando
/// la API responde 401 por token caducado).
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.cargarSesionGuardada();
  // Si el token caduca/es inválido (401), la app cierra sesión y vuelve al login
  // automáticamente, en vez de quedarse en un error.
  ApiClient.onNoAutorizado = () {
    navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };
  runApp(const TrazoApp());
}

class TrazoApp extends StatelessWidget {
  const TrazoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trazo',
      navigatorKey: navKey,
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
      // Lo primero SIEMPRE es elegir el rol de la tablet. El login solo se pide
      // si se elige MAESTRA (la persona participante nunca hace login).
      home: const RolScreen(),
    );
  }
}
