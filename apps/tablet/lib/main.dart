import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'api/client.dart';
import 'screens/galeria_screen.dart';
import 'screens/login_screen.dart';
import 'screens/rol_screen.dart';
import 'theme.dart';

/// La web comercial sirve la app bajo la ruta `/demo/` (local y en el deploy):
/// ahí la app abre directa una muestra de actividades (vitrina), sin la pantalla
/// de rol/login interna. Se detecta por la RUTA (robusto a caché y a que se
/// pierda un parámetro) y también admite `?vitrina=1` como respaldo.
bool get _esVitrina =>
    kIsWeb &&
    (Uri.base.path.contains('/demo') ||
        Uri.base.queryParameters.containsKey('vitrina'));

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
      // Desde la web comercial (?vitrina=1) se entra directo a la muestra de
      // actividades. En la app normal, lo primero SIEMPRE es elegir el rol de la
      // tablet; el login solo se pide si se elige MAESTRA (la persona
      // participante nunca hace login).
      home: _esVitrina ? const GaleriaScreen(vitrina: true) : const RolScreen(),
    );
  }
}
