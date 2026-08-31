import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Envoltorio para los RETOS: son juegos anchos, de grupo, pensados para
/// HORIZONTAL. En móvil vertical se ven apretados/recortados, así que:
///  - Fuerza la orientación horizontal mientras el reto está abierto (en la
///    tablet/móvil físico rota solo; en la web es un no-op inofensivo).
///  - Si aun así la pantalla es estrecha y vertical (web en móvil sin poder
///    rotar), muestra un aviso amable "Gira el móvil" en vez del reto apretado.
/// Al cerrar el reto restaura todas las orientaciones.
class RetoContenedor extends StatefulWidget {
  final Widget child;
  const RetoContenedor({super.key, required this.child});

  @override
  State<RetoContenedor> createState() => _RetoContenedorState();
}

class _RetoContenedorState extends State<RetoContenedor> {
  @override
  void initState() {
    super.initState();
    _fijar(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _fijar(DeviceOrientation.values); // restaurar todas
    super.dispose();
  }

  void _fijar(List<DeviceOrientation> o) {
    try {
      SystemChrome.setPreferredOrientations(o);
    } catch (_) {
      // En web puede no estar soportado: no pasa nada, el aviso cubre el caso.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final estrechoVertical =
          cons.maxWidth < 560 && cons.maxHeight > cons.maxWidth;
      if (estrechoVertical) return _avisoGirar();
      return widget.child;
    });
  }

  Widget _avisoGirar() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_rotation,
                size: 68, color: TrazoColors.sageDark),
            SizedBox(height: 18),
            Text('Gira el móvil',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: TrazoColors.ink)),
            SizedBox(height: 10),
            Text(
              'Este reto se juega mejor con el móvil en horizontal. '
              'Gíralo y tendréis sitio de sobra.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: TrazoColors.bordeControl),
            ),
          ],
        ),
      ),
    );
  }
}
