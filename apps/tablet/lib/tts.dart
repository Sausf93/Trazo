import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lectura en voz alta de las instrucciones (accesibilidad: muchos mayores no
/// leen bien o "nunca aprendieron a leer"). Todo es best-effort y silencioso: si
/// no hay voz disponible en el dispositivo, la app funciona igual sin sonido.
class Tts {
  Tts._();
  static final Tts instance = Tts._();

  final FlutterTts _tts = FlutterTts();
  bool _preparado = false;
  bool _disponible = true;

  /// Prepara la voz UNA vez, cuanto antes (idealmente al arrancar la app). En
  /// WEB esto es clave: si la preparación (async) ocurre DENTRO del primer toque,
  /// algunos navegadores descartan ese `speak` por no venir "directo" del gesto y
  /// las voces aún no han cargado. Al calentar al inicio, el primer toque ya
  /// habla directo. Best-effort: si algo falla, la app sigue sin sonido.
  Future<void> calienta() => _preparar();

  Future<void> _preparar() async {
    if (_preparado) return;
    _preparado = true;
    try {
      // En es-ES si existe; si el dispositivo/navegador no la tiene, cae a
      // cualquier español disponible (es-MX, es-US…) para no quedar mudo.
      await _fijarIdiomaEspanol();
      await _tts
          .setSpeechRate(0.42); // pausado: se entiende mejor para el mayor
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      try {
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {/* no todas las plataformas lo soportan */}
    } catch (e) {
      _disponible = false;
      if (kDebugMode) debugPrint('TTS no disponible: $e');
    }
  }

  /// Fija español: prueba es-ES y, si no está, busca el primer idioma "es-*"
  /// que ofrezca el dispositivo/navegador.
  Future<void> _fijarIdiomaEspanol() async {
    try {
      final ok = await _tts.isLanguageAvailable('es-ES');
      if (ok == true) {
        await _tts.setLanguage('es-ES');
        return;
      }
    } catch (_) {}
    try {
      final idiomas = await _tts.getLanguages;
      if (idiomas is List) {
        final es = idiomas.map((e) => e.toString()).firstWhere(
            (l) => l.toLowerCase().startsWith('es'),
            orElse: () => 'es-ES');
        await _tts.setLanguage(es);
        return;
      }
    } catch (_) {}
    // Último recurso: intentarlo igualmente.
    try {
      await _tts.setLanguage('es-ES');
    } catch (_) {}
  }

  /// Lee un texto en voz alta (corta lo que estuviera diciendo). No lanza nunca.
  Future<void> hablar(String texto) async {
    final t = texto.trim();
    if (t.isEmpty) return;
    await _preparar();
    if (!_disponible) return;
    try {
      // No se bloquea en `await stop()`: en web eso retrasa el `speak` y puede
      // hacer que el navegador lo descarte. Se pide parar y se habla seguido.
      unawaited(_tts.stop());
      await _tts.speak(t);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak falló: $e');
    }
  }

  /// Detiene la lectura (p. ej. al cambiar de actividad o salir).
  Future<void> parar() async {
    if (!_preparado || !_disponible) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
