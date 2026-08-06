import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme.dart';
import '../widgets/trazo_logo.dart';
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
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const MaestraScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _RolCard(
                              icono: Icons.emoji_people,
                              titulo: 'PARTICIPANTE',
                              subtitulo: 'Hacer los ejercicios',
                              color: TrazoColors.coralDark,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ParticipanteScreen()),
                              ),
                            ),
                          ),
                        ],
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
