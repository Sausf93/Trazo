# Trazo — Dónde lo dejamos (para retomar)

> Punto de continuación. Al volver: enciende el PC, dime **"sigue con Trazo"** y
> retomo desde aquí. Todo lo confirmado está en GitHub (github.com/Sausf93/Trazo).

## Estado global
- Último commit **subido y estable**: `f6d9238` (backend de A+B+C completo y verificado).
- Backend, panel web y web comercial: OK. App tablet: OK salvo la UI de A+B+C (ver abajo).

## ⚠️ LO PRIMERO al retomar: terminar la UI de la tablet (A+B+C)
Un agente estaba montando la **UI de la tablet** de las 3 mejoras (A+B+C) cuando se
apagó el PC. Sus cambios quedaron **en el disco pero SIN verificar ni commitear**
(ya tocó `apps/tablet/lib/models.dart` y `lib/api/client.dart`, y probablemente
`maestra_screen.dart`, `participante_screen.dart`, `evocacion_libre_widget.dart`).

**Pasos para cerrarlo:**
1. `git status` para ver qué archivos de `apps/tablet` quedaron modificados.
2. `cd apps/tablet` y `C:/Users/Saulo.Santacruz/flutter/bin/flutter.bat analyze` +
   `... build web --dart-define=API_URL=http://localhost:8000`.
3. Si compila limpio → revisar que estén las 3 features (abajo) y **commit + push**.
4. Si NO compila o falta algo → terminar la UI a mano (el contrato backend ya existe,
   ver `docs/API.md`) hasta que `analyze` y `build` estén limpios, y commit.

## Qué son A + B + C (backend YA hecho; falta rematar la UI)
**A) Config por participante en la maestra ("Abrir sala").**
Por cada participante, elegir **nivel** (bajo/medio/alto) + **categorías** (bloques)
y **nº** de actividades para ESA sesión. Por defecto se pre-rellena desde su PLAN
(`GET /usuarios/{id}/plan`). Se envía en `POST /sesiones` -> `configs`. La cola sale
de la config si existe; si no, del plan.

**B) "Enviar más" en el monitor.**
Cuando un participante `terminado=true` (visible en `/live`), la maestra ve "Terminó ✓"
y un botón **Enviar más** (`PATCH /sesiones/{id}/participantes/{uid}/mas`) -> le manda
otra tanda (sube `ronda`), sin que espere a los demás.

**C) Participante: espera al terminar + evocación clara.**
Al acabar su cola: `POST .../terminado`, mensaje "¡Muy bien! Espera un momento…", y
**polling** a `.../estado`; si sube la `ronda`, pide cola otra vez y sigue. La
**evocación** (refranes/listar): quitar el contador +/- confuso; mostrar solo el
enunciado grande + "Siguiente". El backend ya distingue `modo` "completar" (pide 1,
no aplica la banda) vs "listar".

## Contrato backend nuevo (todo en `docs/API.md`, ya en producción)
- `POST /sesiones` acepta `configs: [{usuario_final_id, nivel?, lineas:[{bloque,n}]}]`.
- `GET /sesiones/{id}/participantes/{uid}/estado` -> `{iniciada, ronda, terminado}`.
- `POST /sesiones/{id}/participantes/{uid}/terminado`.
- `PATCH /sesiones/{id}/participantes/{uid}/mas` (body opcional `{nivel, lineas}`).
- `/live` fichas ahora traen `terminado` y `ronda`.
- `/ejercicios/{id}/instancia?nivel=bajo|medio|alto` -> banda de cantidad (3 / 6-8 / 10-12).

## Recordatorios importantes
- **Re-login**: se reinició la BD (esquema nuevo), así que las tablets necesitan
  volver a entrar (admin@trazo.local / trazo1234). Ya hay auto-recuperación: ante un
  401 la app va sola al login.
- **NO volver a resetear la BD** en los reinicios (el esquema ya está estable) para
  que los logins duren. Arrancar backend SIN borrar `trazo.db`.
- **Arranque local**: backend (venv + uvicorn + sqlite), panel `npm run dev`, tablet
  servir `build/web` en :3000. Script: `scripts/arrancar-local.ps1`. URLs de siempre.
- **Ilustraciones**: 121 dibujos SVG + arquitectura "foto primero" (soltar foto en
  `apps/tablet/assets/fotos/{id}.png` + una línea en `ilustracion.dart` -> sustituye
  al dibujo). Estrategia: ir metiendo fotos reales poco a poco.

## Pendiente de dibujos (feedback del cliente)
- Round 2 (11 rehechos) enviados en galería; Saulo aún tenía que decir cuáles le
  cuadran y cuáles pasar a **foto real**.
- Objetos que ya dio por buenos: cepillo_dientes, llave_inglesa, patata, perro,
  sierra, tarta, toalla, tomate, tren (round 1).

## Otros pendientes (ver PENDIENTE.md)
- Grafomotricidad: guía de dirección ya hecha (punto de inicio + flechas).
- Docker: stack preparado; falta instalar Docker Desktop para ejecutarlo.
- RGPD producción (HTTPS, cifrado en reposo) antes de piloto.
- Logo/colores definitivos (a decidir con la pareja).
