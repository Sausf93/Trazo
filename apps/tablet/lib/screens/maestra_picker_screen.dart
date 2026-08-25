import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/trazo_logo.dart';
import 'login_screen.dart';
import 'maestra_screen.dart';

/// "¿Quién eres?" para la MAESTRA en una tablet emparejada: elige tu nombre de la
/// lista del centro y entras. Así queda registrado quién dio la actividad. El PIN
/// solo se pide si ese profesional lo tiene puesto (opcional). Como alternativa,
/// se puede entrar con email y contraseña (p. ej. el admin, o si no estás en la
/// lista).
class MaestraPickerScreen extends StatefulWidget {
  const MaestraPickerScreen({super.key});

  @override
  State<MaestraPickerScreen> createState() => _MaestraPickerScreenState();
}

class _MaestraPickerScreenState extends State<MaestraPickerScreen> {
  List<StaffPick>? _equipo;
  String? _error;
  bool _entrando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final e = await ApiClient.instance.equipoDelCentro();
      if (!mounted) return;
      setState(() => _equipo = e);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  Future<void> _elegir(StaffPick s) async {
    if (_entrando) return;
    HapticFeedback.selectionClick();
    String? pin;
    if (s.tienePin) {
      pin = await _pedirPin(s.nombre);
      if (pin == null) return; // canceló
    }
    setState(() => _entrando = true);
    try {
      await ApiClient.instance.loginTablet(s.id, pin: pin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MaestraScreen()));
    } catch (err) {
      if (!mounted) return;
      final msg = err is ApiException && err.mensaje == 'PIN'
          ? 'PIN incorrecto. Inténtalo de nuevo.'
          : (err is ApiException ? err.mensaje : 'No se pudo entrar.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  Future<String?> _pedirPin(String nombre) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('PIN de $nombre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: '4 dígitos'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Entrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: const Text('¿Quién eres?'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _error != null
                  ? _errorView()
                  : _equipo == null
                      ? const CircularProgressIndicator()
                      : _lista(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No se pudo cargar el equipo.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TrazoColors.coralDark)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );

  Widget _lista() {
    final equipo = _equipo!;
    return Column(
      children: [
        const TrazoLogo(size: 56),
        const SizedBox(height: 12),
        const Text('Toca tu nombre para dar la actividad',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: TrazoColors.sageDark)),
        const SizedBox(height: 20),
        Expanded(
          child: equipo.isEmpty
              ? const Center(
                  child: Text('Aún no hay profesionales en este centro.',
                      style: TextStyle(fontSize: 16, color: TrazoColors.sageDark)))
              : ListView.separated(
                  itemCount: equipo.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final s = equipo[i];
                    return Material(
                      color: TrazoColors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _entrando ? null : () => _elegir(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          child: Row(
                            children: [
                              const Icon(Icons.person,
                                  color: TrazoColors.sageDark, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(s.nombre,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: TrazoColors.ink)),
                              ),
                              if (s.tienePin)
                                const Icon(Icons.lock_outline,
                                    size: 18, color: TrazoColors.sageDark),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right,
                                  color: TrazoColors.sageDark),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen())),
          icon: const Icon(Icons.alternate_email, size: 18),
          label: const Text('Entrar con email y contraseña'),
          style: TextButton.styleFrom(foregroundColor: TrazoColors.sageDark),
        ),
      ],
    );
  }
}
