import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';
import 'models.dart';

/// Cola de intentos pendientes de enviar (MVP offline-first).
///
/// Punto de partida simple con SharedPreferences. En producción se migrará a
/// `drift`/`sqflite` para robustez. Por diseño es idempotente: cada intento
/// lleva su UUID, así que reenviar no duplica en el backend.
class SyncQueue {
  static const _key = 'intentos_pendientes';

  /// Intenta enviar; si falla, encola para reintento posterior.
  static Future<void> enviarOEncolar(Intento intento) async {
    bool ok = false;
    try {
      ok = await ApiClient.instance.registrarIntento(intento);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      final prefs = await SharedPreferences.getInstance();
      final pend = prefs.getStringList(_key) ?? [];
      pend.add(jsonEncode(intento.toJson()));
      await prefs.setStringList(_key, pend);
    }
  }

  /// Reintenta enviar todo lo pendiente. Devuelve cuántos quedaron sin enviar.
  static Future<int> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final pend = prefs.getStringList(_key) ?? [];
    if (pend.isEmpty) return 0;

    final restantes = <String>[];
    for (final raw in pend) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final intento = Intento(
        id: j['id'] as String,
        usuarioFinalId: j['usuario_final_id'] as String,
        sesionId: j['sesion_id'] as String,
        ejercicioId: j['ejercicio_id'] as String,
        estado: j['estado'] as String,
        timestampInicio: DateTime.parse(j['timestamp_inicio'] as String),
        timestampFin: j['timestamp_fin'] != null
            ? DateTime.parse(j['timestamp_fin'] as String)
            : null,
        valores: Map<String, dynamic>.from(j['valores_json'] as Map),
        cantidadObjetivo:
            Map<String, dynamic>.from(j['cantidad_objetivo_json'] as Map),
      );
      bool ok = false;
      try {
        ok = await ApiClient.instance.registrarIntento(intento);
      } catch (_) {
        ok = false;
      }
      if (!ok) restantes.add(raw);
    }
    await prefs.setStringList(_key, restantes);
    return restantes.length;
  }
}
