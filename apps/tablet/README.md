# Trazo — App de tablet (Flutter)

> ✅ **Estado: compila y arranca.** Verificado con Flutter 3.44.8:
> `flutter build web` termina sin errores y la app bootea (login → preparación →
> modo participante). Falta la prueba visual de dibujo/interacción (hazla abriendo
> la app en el navegador) y completar renderers específicos de algunas plantillas.
>
> Flutter está instalado en `C:\Users\Saulo.Santacruz\flutter`. Para usar el
> comando `flutter` cómodo, añade `C:\Users\Saulo.Santacruz\flutter\bin` al PATH.

## Qué hace (Fase 1 — modo participante)

- **Login** de staff contra la API.
- **Preparación**: elegir participante + ejercicio (esto en real lo hará la
  facilitadora; aquí es la pantalla de arranque).
- **Modo participante** a pantalla completa, sin menús:
  - Pide una *instancia* del ejercicio a la API (`/ejercicios/{id}/instancia`),
    con cantidades cambiantes.
  - Renderiza según la `plantilla`:
    - `trazo`: dibuja la guía y captura el trazo del dedo; calcula una precisión
      aproximada (fracción de puntos dentro de la tolerancia).
    - `seleccion_multiple`: enunciado + opciones tocables.
    - resto de plantillas: vista genérica legible (a completar por tipo).
  - Registra el **intento** con estado `solo`/`con_ayuda`/`no_completado`, UUID
    generado en cliente. Si no hay red, lo encola localmente y reintenta.

## Cómo ejecutarlo (cuando el SDK esté instalado)

```bash
# 1) Instalar Flutter (ver https://docs.flutter.dev/get-started/install)
flutter --version

cd apps/tablet

# (Las carpetas de plataforma web/android ya están generadas. Si faltaran:
#  flutter create . --project-name trazo_tablet --platforms web,android --org com.trazo )

flutter pub get

# Opción 1 — abrir en Chrome directamente (recomendado para probar):
flutter run -d chrome --dart-define=API_URL=http://localhost:8000

# Opción 2 — compilar y servir el build estático (lo que se hizo aquí):
flutter build web --dart-define=API_URL=http://localhost:8000
#   luego servirlo en el puerto 3000 (aceptado por el CORS del backend):
cd build/web && python -m http.server 3000
#   y abrir http://localhost:3000

# En una tablet Android conectada:
flutter run --dart-define=API_URL=http://<IP-del-backend>:8000
```

La URL de la API se pasa con `--dart-define=API_URL=...` (por defecto
`http://localhost:8000`).

## Pendiente (fases siguientes)

- Modo facilitadora (vista en vivo de participantes, botón de ayuda, aviso de
  atascado) — el backend ya expone `/sesiones/{id}/live`.
- Offline-first robusto con `drift`/`sqflite` (aquí hay una cola mínima con
  `shared_preferences` como punto de partida).
- Modo kiosco (Guided Access iPad / kiosk Android).
- Renderers específicos para las 8 plantillas con imágenes/audio reales.
