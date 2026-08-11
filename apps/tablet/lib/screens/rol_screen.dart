import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client.dart';
import '../models.dart';
import '../services/actualizacion.dart';
import '../theme.dart';
import '../widgets/trazo_logo.dart';
import 'galeria_screen.dart';
import 'login_screen.dart';
import 'maestra_screen.dart';
import 'participante_screen.dart';

/// Selección del rol de la tablet: MAESTRA (control de la integradora) o
/// PARTICIPANTE (kiosco para el usuario mayor).
class RolScreen extends StatelessWidget {
  const RolScreen({super.key});

  Future<void> _salir(BuildContext context) async {
    await ApiClient.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RolScreen()),
      (_) => false,
    );
  }

  /// MAESTRA: si aún no hay sesión iniciada, pide login; si ya la hay, entra.
  void _irMaestra(BuildContext context) {
    if (ApiClient.instance.autenticado) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MaestraScreen()));
    } else {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  /// PARTICIPANTE: NUNCA hace login. Funciona si la tablet está vinculada al
  /// centro (emparejada) o si la responsable ya entró como maestra en esta
  /// tablet. Si no, se explica en lugar de pedir credenciales.
  void _irParticipante(BuildContext context) {
    if (ApiClient.instance.autenticado || ApiClient.instance.emparejado) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ParticipanteScreen()));
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Esta tablet aún no está lista'),
          content: const Text(
              'Para que esta tablet muestre las actividades, la responsable debe '
              'vincularla al centro una vez (botón "Emparejar esta tablet"), o '
              'entrar como MAESTRA en ella. Luego ya no hará falta.',
              style: TextStyle(fontSize: 16, color: TrazoColors.sageDark)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TrazoLogo(size: 84),
                      const SizedBox(height: 16),
                      const Text('Esta tablet es…',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: TrazoColors.ink)),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: _RolCard(
                              icono: Icons.co_present,
                              titulo: 'MAESTRA',
                              subtitulo: 'Abrir sala y seguir al grupo',
                              color: TrazoColors.sage,
                              onTap: () => _irMaestra(context),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _RolCard(
                              icono: Icons.emoji_people,
                              titulo: 'PARTICIPANTE',
                              subtitulo: 'Hacer los ejercicios',
                              color: TrazoColors.coralDark,
                              onTap: () => _irParticipante(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const _EmparejarBar(),
                      const SizedBox(height: 4),
                      // Modo demo: probar las actividades sin login ni sala.
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const GaleriaScreen()),
                        ),
                        icon: const Icon(Icons.grid_view, size: 18),
                        label: const Text('Ver actividades (demo)'),
                        style: TextButton.styleFrom(
                            foregroundColor: TrazoColors.sageDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton.icon(
                onPressed: () => _salir(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Cerrar acceso'),
                style: TextButton.styleFrom(
                    foregroundColor: TrazoColors.sageDark),
              ),
            ),
            // Aviso de nueva versión del APK (distribución sin Play Store).
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _AvisoActualizacion(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comprueba al abrir si hay una versión más nueva del APK y, si la hay, muestra
/// un banner con las notas y el enlace de descarga (copiable). Best-effort.
class _AvisoActualizacion extends StatefulWidget {
  const _AvisoActualizacion();

  @override
  State<_AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<_AvisoActualizacion> {
  ActualizacionDisponible? _upd;
  bool _oculto = false;

  @override
  void initState() {
    super.initState();
    _comprobar();
  }

  Future<void> _comprobar() async {
    final upd = await ServicioActualizacion.comprobar();
    if (!mounted || upd == null) return;
    setState(() => _upd = upd);
  }

  @override
  Widget build(BuildContext context) {
    final upd = _upd;
    if (upd == null || _oculto) return const SizedBox.shrink();
    return Material(
      color: TrazoColors.sage,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva versión disponible'
                    '${upd.versionName.isNotEmpty ? " (${upd.versionName})" : ""}'
                    '${upd.notas.isNotEmpty ? " — ${upd.notas}" : ""}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  SelectableText(
                    upd.apkUrl,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: upd.apkUrl));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enlace copiado')));
              },
              icon: const Icon(Icons.copy, size: 16, color: Colors.white),
              label: const Text('Copiar enlace',
                  style: TextStyle(color: Colors.white)),
            ),
            IconButton(
              onPressed: () => setState(() => _oculto = true),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Ocultar',
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra opcional para EMPAREJAR esta tablet al centro con un código. Una vez
/// emparejada, el rol PARTICIPANTE funciona sin login de la integradora.
class _EmparejarBar extends StatefulWidget {
  const _EmparejarBar();

  @override
  State<_EmparejarBar> createState() => _EmparejarBarState();
}

class _EmparejarBarState extends State<_EmparejarBar> {
  bool get _emparejado => ApiClient.instance.emparejado;

  Future<void> _emparejar() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Emparejar esta tablet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Pega el código de emparejamiento que te da la integradora '
                'desde el panel (Dispositivos).',
                style: TextStyle(fontSize: 15, color: TrazoColors.sageDark)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'código',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Emparejar')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final DispositivoYo yo =
          await ApiClient.instance.emparejarDispositivo(code);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tablet emparejada a su centro (${yo.nombre}).')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _quitar() async {
    await ApiClient.instance.desemparejar();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_emparejado) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tablet_android, size: 18, color: TrazoColors.sageDark),
          const SizedBox(width: 8),
          const Text('Tablet emparejada al centro',
              style: TextStyle(
                  color: TrazoColors.sageDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          TextButton(
              onPressed: _quitar,
              child: const Text('Quitar')),
        ],
      );
    }
    return TextButton.icon(
      onPressed: _emparejar,
      icon: const Icon(Icons.link, size: 18),
      label: const Text('Emparejar esta tablet (opcional)'),
      style: TextButton.styleFrom(foregroundColor: TrazoColors.sageDark),
    );
  }
}

class _RolCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  const _RolCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrazoColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 220,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 72, color: color),
              const SizedBox(height: 16),
              Text(titulo,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 8),
              Text(subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, color: TrazoColors.sageDark)),
            ],
          ),
        ),
      ),
    );
  }
}
