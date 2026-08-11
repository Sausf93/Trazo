import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme.dart';
import '../widgets/trazo_logo.dart';
import 'galeria_screen.dart';
import 'maestra_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'integradora@trazo.local');
  final _pass = TextEditingController(text: 'trazo1234');
  bool _cargando = false;
  String? _error;

  Future<void> _entrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      // Se llega aquí solo desde el botón MAESTRA, así que tras entrar se va
      // directo al control de la maestra.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MaestraScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: TrazoLogo(size: 88)),
                const SizedBox(height: 14),
                const Text('Trazo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: TrazoColors.ink)),
                const SizedBox(height: 6),
                const Text('Acceso del personal',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TrazoColors.sageDark)),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(
                      labelText: 'Contraseña', border: OutlineInputBorder()),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: TrazoColors.coralDark)),
                  ),
                ElevatedButton(
                  onPressed: _cargando ? null : _entrar,
                  child: _cargando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 12),
                // Acceso al modo demo sin credenciales (para probar/enseñar las
                // actividades, también en la versión web alojada).
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GaleriaScreen()),
                  ),
                  icon: const Icon(Icons.grid_view, size: 18),
                  label: const Text('Ver actividades de ejemplo'),
                  style: TextButton.styleFrom(
                      foregroundColor: TrazoColors.sageDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
