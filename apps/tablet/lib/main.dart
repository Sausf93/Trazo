import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'api/client.dart';
import 'screens/galeria_screen.dart';
import 'screens/login_screen.dart';
import 'screens/rol_screen.dart';
import 'theme.dart';
import 'tts.dart';

/// La web comercial sirve la app bajo la ruta `/demo/` (local y en el deploy):
/// ahí la app abre directa una muestra de actividades (vitrina), sin la pantalla
/// de rol/login interna. Se detecta por la RUTA (robusto a caché y a que se
/// pierda un parámetro) y también admite `?vitrina=1` como respaldo.
bool get _esVitrina =>
    kIsWeb &&
    (Uri.base.path.contains('/demo') ||
        Uri.base.queryParameters.containsKey('vitrina'));

/// Banco de revisión (solo el equipo): recorre las actividades por bloque para
/// valorarlas desde el móvil. No muestra datos reales, solo la muestra del catálogo.
///
/// Carrusel de PENDIENTES de valorar: solo las actividades que el revisor aún NO
/// ha marcado. Entra por la ruta `/actividades-pendientes-valoracion`.
bool get _esLaboratorio =>
    kIsWeb && Uri.base.path.contains('pendientes-valoracion');

/// Vitrina de APROBADAS: solo las ya validadas, para el filtro final (jugarlas
/// todas cuando esté perfecto). Entra por la ruta `/actividades`.
bool get _esAprobadas =>
    kIsWeb &&
    !_esLaboratorio &&
    Uri.base.path.contains('/actividades') &&
    !Uri.base.path.contains('pendientes');

/// Para poder navegar al login desde fuera del árbol de widgets (p. ej. cuando
/// la API responde 401 por token caducado).
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Si un widget de actividad falla al DIBUJARSE (render mal formado: un SVG
  // roto, un elemento de lista que no es Map…), Flutter pintaría una caja gris
  // de error fea en el kiosco. En su lugar mostramos un aviso digno y contenido,
  // para que el mayor nunca vea una pantalla rota.
  ErrorWidget.builder = (FlutterErrorDetails details) => Container(
        color: TrazoColors.ivory,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Esta actividad no se pudo mostrar.\nPasa a la siguiente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: TrazoColors.ink),
        ),
      );
  // Calienta la voz cuanto antes (sobre todo en web): así el primer toque del
  // altavoz ya lee directo, sin perder el gesto ni esperar a que carguen voces.
  unawaited(Tts.instance.calienta());
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
      home: _esLaboratorio
          ? const BancoPruebasScreen()
          : _esAprobadas
              ? const BancoPruebasScreen(modoAprobadas: true)
              : _esVitrina
                  ? const GaleriaScreen(vitrina: true)
                  : const RolScreen(),
    );
  }
}
