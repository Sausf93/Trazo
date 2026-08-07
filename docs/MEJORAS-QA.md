# Trazo — Jornada de pulido QA (autónoma)

Sesión de mejoras basada en auditorías de usabilidad/accesibilidad hechas por
agentes QA especializados (tablet, panel, landing, backend), con foco en el
usuario real: personas mayores 65+ con Alzheimer y las integradoras del centro.
Todo verificado (analyze/tsc/build/tests) y subido a GitHub (rama `main`).

## Novedad: sesiones programadas (idea de Laura)
Dejar una sala **creada y configurada por participante** para otro día; ese día
solo se abre y se reparten tablets.
- **Backend**: `Sesion.abierta` (False = programada) + `Sesion.programada_para`;
  `POST /sesiones` con `programar`/`programada_para`; `GET /sesiones/programadas`;
  `PATCH /sesiones/{id}/abrir`; `PUT /sesiones/{id}/config` (editar antes del día);
  `DELETE` (descartar). Micro‑migración idempotente al arranque (no borra la BD).
- **Tablet maestra**: en "Abrir sala", interruptor **"Guardar para otro día"** (con
  fecha opcional); pantalla **"Programadas"** que lista las salas preparadas (con
  participantes, nivel y categorías) y permite **abrir y repartir** con un toque.
- **Pendiente (opcional)**: crear/programar también desde el panel web (hoy se hace
  desde la tablet maestra, que es donde se abre la sala).

## Arreglado por superficie

### Backend (RGPD / robustez)
- **IDOR (crítico)**: control de centro añadido en `/sesiones/{id}/live`,
  `/usuarios/{id}/evolucion`, `/usuarios/{id}/alertas`, `/grupos/{id}/evolucion`,
  `/intentos/{id}/estado`, `/alertas/{id}/revisar`, y validación de participantes
  al crear/editar sesión. Helper común `deps.usuario_del_centro`.
- Config con **solo nivel** (sin líneas) ya no deja la cola vacía: cae al plan.
- **Cota de `n`** (1..50) en esquemas + tope defensivo en la cola.
- **Fail‑fast** del secreto JWT en producción (`ENTORNO!=dev`).
- **Validación** de `bloque`/`nivel` de la config → 422 (no cola vacía silenciosa).
- Tests: 35 → **46 en verde** (config por participante, rondas, programadas, IDOR,
  cotas y validación).

### Tablet (accesibilidad para mayores)
- **Timeout de red (12s)** en TODAS las llamadas: si el WiFi se cuelga, sale error
  con "Reintentar" en vez de dejar al mayor atrapado en "Preparando…".
- **Contraste WCAG**: píldoras coral (evocación/memoria) y estados del monitor a
  `coralDark`.
- **Marca de "elegido"** (check) en selección múltiple y conteo (no solo el borde).
- **Trazo**: botón "Empezar de nuevo" (un temblor ya no arruina el intento).
- **Memoria**: la cuenta atrás es orientativa; ya no oculta las figuras al llegar a
  0 (no penaliza ir lento); solo avanza con "Ya lo recuerdo".
- **Confirmación** antes de "Terminar" la última actividad (evita cierres por toque
  accidental).

### Panel web
- Foco de teclado (reset parcial, no `all:unset`), contraste AA (sageDark), Login
  con `<Navigate>` en vez de navegar en render, éxitos anunciados (`role=status`),
  confirmación al revocar tablet, texto secundario más legible, `<th scope>`,
  credenciales demo solo en DEV, **ErrorBoundary** global.

### Landing comercial
- Quitado teléfono/badges placeholder; **páginas legales** (aviso‑legal.html,
  privacidad.html) con estructura RGPD (borrador marcado, datos fiscales TODO);
  labels asociadas; contraste AA en CTA; `:focus-visible`; Open Graph/Twitter/
  canonical; jerarquía de encabezados; `aria-hidden` en SVG decorativos; menú
  hamburguesa accesible.

## Pendiente (siguiente pasada, priorizado)
**Tablet**: alternativa por toque en `arrastrar_posicion` (evitar el drag); ampliar
`Semantics` (nombres, teclado numérico, reloj); TTS opcional del enunciado; teclas
numéricas ≥64px; quitar botón redundante "Marcar hecho" del genérico.
**Panel**: alta de personas usuarias (hoy solo se listan); aviso de cambios sin
guardar en el editor de plan; listar sesiones activas (evitar pegar id a mano);
token JWT en cookie HttpOnly; a11y de la gráfica de evolución.
**Backend**: auth por **token de dispositivo** para el kiosco (hoy usa el JWT de
staff); N+1 en `live`/`activa`; idempotencia de intentos ante carrera; check de
centro en `generar_instancia`.
**Landing**: prueba social/testimonios; auto‑alojar fuentes (RGPD); formulario a
backend sin servidor (Formspree/Netlify) en vez de `mailto:`.
**General**: Docker Desktop; RGPD producción (HTTPS, cifrado en reposo); logo/colores
definitivos; ir sustituyendo dibujos por fotos reales.
