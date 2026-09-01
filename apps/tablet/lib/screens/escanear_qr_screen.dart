import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme.dart';

/// Pantalla de cámara para escanear el QR de emparejamiento que muestra el panel.
/// Devuelve (Navigator.pop) el texto del QR (el código de emparejamiento) o null
/// si la responsable cancela. No teclea nada: apuntar y listo.
class EscanearQrScreen extends StatefulWidget {
  const EscanearQrScreen({super.key});

  @override
  State<EscanearQrScreen> createState() => _EscanearQrScreenState();
}

class _EscanearQrScreenState extends State<EscanearQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hecho = false; // evita devolver el código dos veces (varias lecturas/frame)

  void _alDetectar(BarcodeCapture captura) {
    if (_hecho) return;
    final codigo = captura.barcodes.isNotEmpty
        ? captura.barcodes.first.rawValue
        : null;
    if (codigo == null || codigo.trim().isEmpty) return;
    _hecho = true;
    Navigator.of(context).pop(codigo.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: TrazoColors.sageDark,
        foregroundColor: Colors.white,
        title: const Text('Escanea el QR del panel'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _alDetectar),
          // Marco guía para centrar el QR.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Text(
              'Apunta la cámara al código QR que aparece en el panel, '
              'en la sección «Tablets».',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
