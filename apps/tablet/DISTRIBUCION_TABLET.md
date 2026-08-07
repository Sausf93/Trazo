# Distribución de la app de tablet por APK (sin Play Store)

Trazo se instala en las tablets de los centros **por APK** (sideload). No hace
falta publicar en Google Play: es una flota gestionada y privada (datos de salud
de mayores → mejor que no esté en una tienda pública). Esto ahorra la cuota y las
revisiones de Google, y permite actualizar al instante.

Lo que "pierdes" respecto a la Play Store y cómo se cubre:

| Play Store da… | Aquí lo cubrimos con… |
|---|---|
| Auto-actualización | Chequeo de versión dentro de la app (avisa si hay APK nueva) |
| Confianza de instalación | Firmamos el APK con nuestra clave |
| Distribución | Un enlace de descarga (web propia / GitHub Release) |

---

## 1. Crear la clave de firma (UNA sola vez, guárdala a buen recaudo)

Sin firma propia no se puede **actualizar** el APK encima del anterior, así que
esto es importante hacerlo bien la primera vez y **no perder el `.jks`**.

```bash
keytool -genkey -v -keystore trazo-release.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias trazo
```

Guarda `trazo-release.jks` en un sitio seguro (NO en el repo) y copia
`android/key.properties.example` a `android/key.properties` con tus datos:

```
storeFile=C:/claves/trazo-release.jks
storePassword=...
keyAlias=trazo
keyPassword=...
```

> ⚠️ Si pierdes la clave, la única salida es reinstalar desde cero en cada
> tablet (desinstalar la app y volver a instalar). Haz copia de seguridad.

---

## 2. Construir el APK para un centro

**Requisitos en el equipo que construye** (una vez):
- **Flutter SDK** (ya lo usáis para desarrollar).
- **Android SDK** — lo más fácil es instalar **Android Studio**, que lo trae.
  Luego `flutter doctor` debe mostrar "Android toolchain" en verde. Sin el
  Android SDK, `flutter build apk` falla con *"No Android SDK found"*.
- **JDK 17** (Android Studio lo incluye).


Cada centro tiene su **URL de backend** y puede tener su **PIN de kiosco**. Se
inyectan al construir:

```bash
# Linux/macOS
./build_apk.sh https://api.tucentro.es 4821
```
```powershell
# Windows
.\build_apk.ps1 -ApiUrl "https://api.tucentro.es" -KioskPin "4821"
```

Resultado: `build/app/outputs/flutter-apk/app-release.apk`

> Sin `key.properties` el APK se firma con la clave de **debug** (solo pruebas).
> Para distribuir a un centro, usa siempre la clave de release del paso 1.

---

## 3. Aprovisionar cada tablet (primera vez)

1. **Permitir instalar APKs**: Ajustes → Aplicaciones → acceso especial →
   *Instalar apps desconocidas* → habilita el navegador o el gestor de archivos
   desde el que abrirás el APK.
2. **Pasar el APK** a la tablet: por USB, o descargándolo de un enlace vuestro.
3. **Instalar**: abre el APK y acepta.
4. **Abrir Trazo** y emparejar el kiosco al centro (token de dispositivo) o
   entrar como maestra según el rol de esa tablet.
5. **Fijar en modo kiosco** (recomendado para las tablets de los mayores):
   Android tiene *Fijar pantalla* (Ajustes → Seguridad → Fijar apps). Así el
   residente no sale de la app. La salida del kiosco dentro de Trazo ya pide PIN.

---

## 4. Actualizar a una versión nueva

1. Sube el `versionCode`/`versionName` en `pubspec.yaml`.
2. Reconstruye el APK (paso 2) **con la misma clave de release**.
3. Publica `version.json` + el APK nuevo (ver abajo). La app avisará sola.
4. En cada tablet: abre el APK nuevo → *Actualizar* (mantiene datos y ajustes).

### Aviso automático de actualización

La app comprueba al abrir un `version.json` alojado por vosotros y, si hay una
versión mayor, muestra un aviso con el enlace de descarga. Config al construir:

```
--dart-define=UPDATE_URL=https://sausf93.github.io/Trazo/app/version.json
```

Formato de `version.json`:

```json
{
  "version_code": 3,
  "version_name": "1.2.0",
  "apk_url": "https://sausf93.github.io/Trazo/app/trazo-1.2.0.apk",
  "notas": "Monitor en vivo y notas de sesión."
}
```

Si no defines `UPDATE_URL`, el chequeo se desactiva (no molesta en desarrollo).
