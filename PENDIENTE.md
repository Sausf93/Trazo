# Trazo — Pendientes

Lista viva. `[x]` = hecho. Actualizada 2026-08-07 tras la jornada de pulido QA.
Para el detalle de lo hecho recientemente, ver `docs/MEJORAS-QA.md`.

## Hecho recientemente (para que no se pida dos veces)
- [x] Páginas legales reales (aviso-legal.html, privacidad.html) enlazadas en la landing (borrador, datos fiscales como TODO).
- [x] Landing: quitado teléfono placeholder y badges; labels de formulario; contraste AA; Open Graph/SEO.
- [x] Niveles de dificultad por CANTIDAD (bajo 3 / medio 6-8 / alto 10-12) end-to-end.
- [x] Grafomotricidad: punto de inicio + flechas de dirección en el trazo.
- [x] Librería de ilustraciones (123 SVG) + arquitectura "foto primero"; 8 dibujos poco claros redibujados; casa y reloj añadidos.
- [x] Sesiones programadas (dejar sala lista para otro día) — backend + tablet maestra.
- [x] Config por participante + rondas ("Enviar más") + espera del participante (A+B+C).
- [x] RGPD: control de acceso por centro (IDOR) cerrado en todos los endpoints de datos de salud.
- [x] Web: aprobar sugerencias de nivel, editor de plan, gestión de dispositivos.
- [x] +10 actividades nuevas (catálogo = 81) y sincronización de catálogo al arranque sin borrar la BD.
- [x] Tablet: timeouts de red, contraste, marca de "elegido", confirmar "Terminar", memoria sin auto-ocultar.
- [x] Panel: accesibilidad (foco, contraste, role=status), ErrorBoundary, confirmación al revocar tablet.

## Web comercial (`apps/landing/`)
- [ ] **Email propio de dominio** (hoy `saulodlsf@gmail.com`) — registrar `hola@trazo.app`/`info@trazo.es` y cambiarlo en la landing y páginas legales.
- [ ] **Dominio + hosting** (Netlify/Vercel/GitHub Pages sirven para el HTML estático).
- [ ] **Precio del plan "Centro"** en la landing (hoy "Consúltanos"). Depende de fijar tarifas (ver abajo).
- [ ] **Formulario de contacto real** (hoy `mailto:`) — conectar Formspree/Netlify Forms para recibir leads.
- [ ] **Datos fiscales** en las páginas legales (razón social, NIF/CIF, domicilio) cuando exista la empresa.
- [ ] **Logo definitivo** (a decidir con Laura) — está centralizado, cambiarlo es rápido.
- [ ] Revisar copy con Laura; añadir capturas reales del producto; testimonios cuando haya piloto (NO inventar).

## Antes del piloto con datos reales (RGPD — ver `docs/MEJORAS-EXPERTO.md` §6)
- [ ] **HTTPS/TLS** extremo a extremo (API, tablets, web).
- [ ] **Cifrado en reposo** de BD y backups; valorar cifrado por columna en `datos_identificativos`.
- [ ] **Secretos fuera del repo** (JWT_SECRET, BD) — ya hay fail-fast en prod; falta el despliegue real.
- [ ] **Contrato de encargo de tratamiento (art. 28)** con el centro + **DPIA/EIPD** (categoría especial).
- [ ] Piloto inicial **solo con alias** (sin nombre real) hasta firmar el marco legal.

## Backend / infra
- [ ] **Autenticación por token de dispositivo** para el kiosco (hoy la tablet participante usa el JWT de la integradora) — es el pendiente técnico más relevante del modelo operativo.
- [ ] Migraciones con **Alembic** (hoy: create_all + micro-migraciones idempotentes al arranque).
- [ ] **Desplegar en servidor** (Oracle Cloud + Coolify, según el plan) con Docker.
- [ ] Ejecutar/probar el **stack Docker** (compose listo; falta instalar Docker Desktop).
- [ ] Rendimiento: quitar N+1 en `/live` y `/activa` (polling cada 3-5s).
- [ ] (Opcional) Bot de Telegram para alertas técnicas (servidor caído, sync fallida).

## App tablet (`apps/tablet/`)
- [ ] **Offline robusto** con `drift`/`sqflite` (hoy: cola simple + `shared_preferences`).
- [ ] **Modo kiosco real** (Guided Access iPad / kiosk Android) para bloquear la tablet.
- [ ] Pulido de accesibilidad restante (ver `docs/MEJORAS-QA.md`): alternativa por toque en `arrastrar_posicion`, más `Semantics`, TTS opcional del enunciado.
- [ ] Ir sustituyendo dibujos por **fotos reales** poco a poco (soltar foto en `assets/fotos/{id}.png`).

## Panel web (`apps/web/`)
- [ ] **Alta de personas usuarias** desde el panel (hoy solo se listan; vienen del seed).
- [ ] Aviso de **cambios sin guardar** en el editor de plan.
- [ ] Listar sesiones activas en el monitor (hoy hay que pegar el id a mano).
- [ ] (Opcional) Crear/programar sesiones también desde el panel (hoy se hace desde la tablet maestra).

## Producto / negocio
- [ ] **Fijar tarifas** (en discusión: modelo por tramos de pacientes; ver notas de la conversación).
- [ ] Fase 0: **piloto informal** en el centro de Laura (empresa con 5 centros, ~30 pacientes/centro).
- [ ] Editor de catálogo de actividades en la web (alta/edición sin tocar JSON) — POST /ejercicios ya existe, falta UI.

## Datos de contacto actuales (temporales)
- Nombre: Saulo Santacruz · Email: saulodlsf@gmail.com · Teléfono: (pendiente)
