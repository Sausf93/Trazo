<#
Construye el APK de release de la tablet Trazo, ya configurado para un centro.

Uso:
  .\build_apk.ps1 -ApiUrl "https://api.tucentro.es" -KioskPin "4821"
    -ApiUrl    URL del backend (API_URL)                [obligatorio]
    -KioskPin  PIN de salida del kiosco                 [opcional, por defecto 1379]
    -UpdateUrl URL del version.json (aviso de update)   [opcional]

Requiere haber creado android\key.properties (ver DISTRIBUCION_TABLET.md).
El APK final queda en build\app\outputs\flutter-apk\app-release.apk
#>
param(
    [Parameter(Mandatory = $true)][string]$ApiUrl,
    [string]$KioskPin = "1379",
    [string]$UpdateUrl = ""
)

if (-not (Test-Path "android\key.properties")) {
    Write-Host "AVISO: no hay android\key.properties -> el APK se firmara con la" -ForegroundColor Yellow
    Write-Host "       clave de DEBUG (solo pruebas, NO para distribuir)." -ForegroundColor Yellow
    Write-Host "       Crea la clave siguiendo DISTRIBUCION_TABLET.md." -ForegroundColor Yellow
}

Write-Host "Construyendo APK  ·  API_URL=$ApiUrl  ·  KIOSK_PIN=$KioskPin"
$defines = @("--dart-define=API_URL=$ApiUrl", "--dart-define=KIOSK_PIN=$KioskPin")
if ($UpdateUrl -ne "") {
    $defines += "--dart-define=UPDATE_URL=$UpdateUrl"
}
flutter build apk --release @defines

if ($?) {
    Write-Host ""
    Write-Host "OK -> build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
}
