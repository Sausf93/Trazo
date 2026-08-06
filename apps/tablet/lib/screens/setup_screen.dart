import 'package:flutter/material.dart';

import '../api/client.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'participante_screen.dart';

/// Pantalla de preparación (rol facilitadora): elegir participante + ejercicio
/// y lanzar la vista participante. En uso real esto lo controla la integradora.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  List<UsuarioFinal> _usuarios = [];
  List<Ejercicio> _ejercicios = [];
  UsuarioFinal? _usuario;
  Ejercicio? _ejercicio;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final u = await ApiClient.instance.usuariosDelCentro();
      final e = await ApiClient.instance.ejercicios();
      setState(() {
        _usuarios = u;
        _ejercicios = e;
        _usuario = u.isNotEmpty ? u.first : null;
        _ejercicio = e.isNotEmpty ? e.first : null;
        _cargando = false;
      });
    } catch (err) {
      setState(() {
        _error = err.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _empezar() async {
    if (_usuario == null || _ejercicio == null) return;
    // Sesión individual con este participante.
    final sesionId = await ApiClient.instance.crearSesion(
      tipo: 'individual',
      participantes: [_usuario!.id],
    );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ParticipanteScreen(
        usuario: _usuario!,
        ejercicio: _ejercicio!,
        sesionId: sesionId,
      ),
    ));
  }

  Future<void> _salir() async {
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparar sesión'),
        backgroundColor: TrazoColors.ivory,
        actions: [
          IconButton(
              onPressed: _salir,
              icon: const Icon(Icons.logout),
              tooltip: 'Salir'),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudo cargar:\n$_error',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: TrazoColors.coralDark)),
                ))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Participante',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: TrazoColors.sageDark)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<UsuarioFinal>(
                            initialValue: _usuario,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder()),
                            items: _usuarios
                                .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u.aliasInterno)))
                                .toList(),
                            onChanged: (v) => setState(() => _usuario = v),
                          ),
                          const SizedBox(height: 22),
                          const Text('Ejercicio',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: TrazoColors.sageDark)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Ejercicio>(
                            initialValue: _ejercicio,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                border: OutlineInputBorder()),
                            items: _ejercicios
                                .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text('${e.nombre}  ·  ${e.bloque}',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => _ejercicio = v),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _empezar,
                            child: const Text('Empezar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
