// Aviso de nueva versión del APK (distribución sin Play Store).
//
// Sin tienda no hay auto-actualización, así que al abrir la app comprobamos un
// `version.json` alojado por nosotros (Config.updateUrl). Si su `version_code`
// es mayor que el de la app instalada, devolvemos la info para mostrar un
// aviso con el enlace de descarga. Todo es best-effort: si no hay red o la URL
// no está configurada, no molesta.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';

class ActualizacionDisponible {
  final String versionName;
  final String apkUrl;
  final String notas;

  ActualizacionDisponible(
      {required this.versionName, required this.apkUrl, required this.notas});
}

class ServicioActualizacion {
  /// Devuelve la actualización si hay una más nueva; null en cualquier otro caso
  /// (URL sin configurar, sin red, JSON inválido, o ya estás al día).
  static Future<ActualizacionDisponible?> comprobar() async {
    if (Config.updateUrl.isEmpty) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final actual = int.tryParse(info.buildNumber) ?? 0;

      final resp = await http
          .get(Uri.parse(Config.updateUrl))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final remoto = (j['version_code'] as num?)?.toInt() ?? 0;
      final apkUrl = (j['apk_url'] ?? '') as String;
      if (remoto <= actual || apkUrl.isEmpty) return null;

      return ActualizacionDisponible(
        versionName: (j['version_name'] ?? '') as String,
        apkUrl: apkUrl,
        notas: (j['notas'] ?? '') as String,
      );
    } catch (_) {
      return null; // best-effort: nunca bloquea el arranque
    }
  }
}
