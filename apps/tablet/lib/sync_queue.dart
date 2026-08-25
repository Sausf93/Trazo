import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';
import 'models.dart';

/// Cola de intentos pendientes de enviar (offline-first).
///
/// Idempotente (cada intento lleva su UUID; reenviar no duplica). Endurecida
/// tras verificación adversarial:
///  - Todas las operaciones sobre la cola se SERIALIZAN con un candado, para que
///    encolar y `flush` no se pisen y no se pierda una medición al reescribir.
///  - La decodificación es por-entrada y tolerante: una entrada corrupta se
///    descarta (no bloquea el reenvío del resto, "poison-pill").
///  - Tope de tamaño de la cola (descarta las más antiguas si se desborda).
class SyncQueue {
  static const _key = 'intentos_pendientes';
  static const _maxCola = 500;

  // Candado: encadena las operaciones para que nunca se solapen.
  static Future<void> _cadena = Future.value();

  static Future<T> _sincronizado<T>(Future<T> Function() accion) {
    final completer = Completer<T>();
    _cadena = _cadena.then((_) async {
      try {
        completer.complete(await accion());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  /// Intenta enviar; si el fallo es transitorio, encola para reintento. Un error
  /// permanente (4xx definitivo) se descarta: reintentarlo nunca funcionaría y
  /// bloquearía la cola martilleando un WiFi ya inestable.
  static Future<void> enviarOEncolar(Intento intento) async {
    EnvioIntento res;
    try {
      res = await ApiClient.instance.registrarIntento(intento);
    } catch (_) {
      res = EnvioIntento.transitorio; // sin red / timeout -> reintentar luego
    }
    if (res == EnvioIntento.creado) {
      // Hay conexión: reenvía también lo que quedó pendiente de antes.
      await flush();
    } else if (res == EnvioIntento.permanente) {
      return; // definitivo: no encolar
    } else {
      await _sincronizado(() async {
        final prefs = await SharedPreferences.getInstance();
        final pend = prefs.getStringList(_key) ?? [];
        pend.add(jsonEncode(intento.toJson()));
        // Tope de seguridad: si se desborda, se descartan las más antiguas.
        final recortada = pend.length > _maxCola
            ? pend.sublist(pend.length - _maxCola)
            : pend;
        await prefs.setStringList(_key, recortada);
      });
    }
  }

  /// Cuántos intentos hay pendientes de enviar (para un aviso discreto).
  static Future<int> pendientes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  static Intento? _decodifica(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Intento(
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
    } catch (_) {
      return null; // entrada corrupta: se descarta, no bloquea el resto
    }
  }

  /// Reintenta enviar todo lo pendiente. Devuelve cuántos quedaron sin enviar.
  static Future<int> flush() {
    return _sincronizado(() async {
      final prefs = await SharedPreferences.getInstance();
      final pend = prefs.getStringList(_key) ?? [];
      if (pend.isEmpty) return 0;

      final restantes = <String>[];
      for (final raw in pend) {
        final intento = _decodifica(raw);
        if (intento == null) continue; // descarta la entrada corrupta
        EnvioIntento res;
        try {
          res = await ApiClient.instance.registrarIntento(intento);
        } catch (_) {
          res = EnvioIntento.transitorio;
        }
        // Solo se conserva lo transitorio; 'creado' y 'permanente' salen de la
        // cola (el permanente se descarta: nunca se enviaría con éxito).
        if (res == EnvioIntento.transitorio) restantes.add(raw);
      }
      await prefs.setStringList(_key, restantes);
      return restantes.length;
    });
  }
}
