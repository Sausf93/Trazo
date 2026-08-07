#!/usr/bin/env bash
# Construye el APK de release de la tablet Trazo, ya configurado para un centro.
#
# Uso:
#   ./build_apk.sh https://api.tucentro.es 4821 https://.../app/version.json
#     $1 = URL del backend (API_URL)                 [obligatorio]
#     $2 = PIN de salida del kiosco                  [opcional, por defecto 1379]
#     $3 = URL del version.json (aviso de update)    [opcional]
#
# Requiere haber creado android/key.properties (ver DISTRIBUCION_TABLET.md).
# El APK final queda en build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail

API_URL="${1:-}"
KIOSK_PIN="${2:-1379}"
UPDATE_URL="${3:-}"

if [[ -z "$API_URL" ]]; then
  echo "ERROR: falta la URL del backend."
  echo "Uso: ./build_apk.sh https://api.tucentro.es [PIN] [UPDATE_URL]"
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "AVISO: no hay android/key.properties -> el APK se firmará con la clave"
  echo "       de DEBUG (solo para pruebas, NO para distribuir a los centros)."
  echo "       Crea la clave siguiendo DISTRIBUCION_TABLET.md."
fi

echo "Construyendo APK  ·  API_URL=$API_URL  ·  KIOSK_PIN=$KIOSK_PIN"
DEFINES=(--dart-define=API_URL="$API_URL" --dart-define=KIOSK_PIN="$KIOSK_PIN")
if [[ -n "$UPDATE_URL" ]]; then
  DEFINES+=(--dart-define=UPDATE_URL="$UPDATE_URL")
fi
flutter build apk --release "${DEFINES[@]}"

echo ""
echo "OK -> build/app/outputs/flutter-apk/app-release.apk"
