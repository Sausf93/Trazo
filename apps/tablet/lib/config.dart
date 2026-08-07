/// Configuración global de la app.
class Config {
  /// URL base de la API. Se inyecta en compilación:
  ///   flutter run --dart-define=API_URL=http://localhost:8000
  static const String apiUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

  /// Segundos sin interacción tras los que se considera "atascado".
  static const int segundosAtascado = 30;

  /// URL de un `version.json` alojado por nosotros para avisar de nuevas
  /// versiones del APK (distribución sin Play Store). Vacío = chequeo apagado.
  ///   flutter build apk --dart-define=UPDATE_URL=https://.../app/version.json
  static const String updateUrl =
      String.fromEnvironment('UPDATE_URL', defaultValue: '');
}
