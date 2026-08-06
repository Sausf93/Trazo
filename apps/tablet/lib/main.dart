import 'package:flutter/material.dart';

import 'api/client.dart';
import 'screens/login_screen.dart';
import 'screens/setup_screen.dart';
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
      home: ApiClient.instance.autenticado
          ? const SetupScreen()
          : const LoginScreen(),
    );
  }
}
