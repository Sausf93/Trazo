import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client.dart';
import '../models.dart';
import '../services/actualizacion.dart';
import '../theme.dart';
import '../widgets/trazo_logo.dart';
import 'maestra_picker_screen.dart';
import 'maestra_screen.dart';
import 'participante_screen.dart';

/// Pantalla de inicio de la tablet.
///
/// Flujo (modelo del centro): PRIMERO se empareja la tablet al centro (una sola
/// vez, con el código del panel). SOLO cuando está emparejada aparece la
/// elección de rol MAESTRA / PARTICIPANTE, que se decide en CADA uso (la misma
/// tablet sirve para las dos cosas).
class RolScreen extends StatefulWidget {
  const RolScreen({super.key});

  @override
  State<RolScreen> createState() => _RolScreenState();
}

class _RolScreenState extends State<RolScreen> {
  bool get _emparejado => ApiClient.instance.emparejado;

  Future<void> _salir() async {
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RolScreen()),
      (_) => false,
    );
  }

  /// MAESTRA: exige identidad de STAFF (no basta el emparejamiento de la tablet).
  /// - Si ya hay login de staff en esta tablet, entra directo.
  /// - Si no, en una tablet emparejada muestra el selector "¿quién eres?" (elige
  ///   tu nombre y entra; queda registrado quién dio la actividad).
  void _irMaestra() {
    if (ApiClient.instance.staffLogueado) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MaestraScreen()));
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const MaestraPickerScreen()));
    }
  }

  /// PARTICIPANTE: nunca hace login; funciona porque la tablet está emparejada.
  void _irParticipante() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ParticipanteScreen()));
  }

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
                'Pega el código de emparejamiento que da la responsable desde '
                'el panel, en la sección «Tablets».',
                style: TextStyle(fontSize: 15, color: TrazoColors.sageDark)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), hintText: 'código'),
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
      setState(() {}); // ahora ya aparece la elección de rol
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tablet emparejada a su centro (${yo.nombre}).')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _quitarEmparejamiento() async {
    await ApiClient.instance.desemparejar();
    if (!mounted) return;
    setState(() {});
  }

  /// Desemparejar es destructivo (hay que volver a pedir el código del panel).
  /// Se confirma para que un mayor confundido no deje la tablet sin vincular.
  Future<void> _confirmarQuitar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desemparejar esta tablet?'),
        content: const Text(
            'La tablet dejará de estar vinculada al centro. Para volver a '
            'usarla haría falta el código de emparejamiento del panel.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: TrazoColors.coralDark),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, desemparejar')),
        ],
      ),
    );
    if (ok == true) await _quitarEmparejamiento();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Centrado cuando cabe; con scroll cuando la pantalla es baja
            // (móvil en horizontal / ventanas cortas) para no recortar nada.
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: _emparejado ? _vistaRoles() : _vistaEmparejar(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Salir (cierra el login de la maestra) — solo si hay login de staff.
            if (ApiClient.instance.staffLogueado)
              Positioned(
                top: 8,
                right: 8,
                child: TextButton.icon(
                  onPressed: _salir,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Cerrar acceso'),
                  style: TextButton.styleFrom(
                      foregroundColor: TrazoColors.sageDark),
                ),
              ),
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

  /// Tablet SIN emparejar: puesta a punto. Es lo único que se ofrece.
  Widget _vistaEmparejar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TrazoLogo(size: 84),
        const SizedBox(height: 18),
        const Text('Primero, empareja esta tablet',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: TrazoColors.ink)),
        const SizedBox(height: 12),
        const Text(
            'Vincula la tablet a tu centro una sola vez, con el código que da la '
            'responsable desde el panel («Tablets»). Después, esta misma tablet '
            'podrá usarse como maestra o como participante.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: TrazoColors.sageDark)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _emparejar,
          icon: const Icon(Icons.link, size: 22),
          label: const Text('Emparejar esta tablet al centro'),
          style: ElevatedButton.styleFrom(
            backgroundColor: TrazoColors.sageDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  /// Tablet YA emparejada: se elige el rol para este uso.
  Widget _vistaRoles() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TrazoLogo(size: 84),
        const SizedBox(height: 16),
        const Text('¿Cómo se usa ahora?',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: TrazoColors.ink)),
        const SizedBox(height: 8),
        const Text(
            'La misma tablet sirve para las dos cosas: cada vez eliges si es '
            'maestra o participante.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: TrazoColors.sageDark)),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: _RolCard(
                icono: Icons.co_present,
                titulo: 'MAESTRA',
                subtitulo: 'Abrir sala y seguir al grupo',
                color: TrazoColors.sageDark,
                onTap: _irMaestra,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _RolCard(
                icono: Icons.emoji_people,
                titulo: 'PARTICIPANTE',
                subtitulo: 'Hacer los ejercicios',
                color: TrazoColors.coralDark,
                onTap: _irParticipante,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                size: 18, color: TrazoColors.sageDark),
            const SizedBox(width: 8),
            Text(
                (ApiClient.instance.nombreDispositivo?.trim().isNotEmpty ??
                        false)
                    ? 'Esta tablet: «${ApiClient.instance.nombreDispositivo}»'
                    : 'Tablet emparejada al centro',
                style: const TextStyle(
                    color: TrazoColors.sageDark, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            TextButton(
                onPressed: _confirmarQuitar, child: const Text('Desemparejar')),
          ],
        ),
      ],
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
      color: TrazoColors.sageDark,
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: upd.apkUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace copiado')));
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
                      fontSize: 26, fontWeight: FontWeight.w800, color: color)),
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
