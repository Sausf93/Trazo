# Plan de cambio de nombre (rebrand) — Trazo → «NUEVO»

> Preparado para ejecutar **de una vez** cuando Saulo y Laura decidan el nombre.
> Sustituir «NUEVO» por el nombre elegido. La **paleta verde agua NO cambia**
> (teal #12A99B · coral #F08A6B). Todo se hace en una rama y un despliegue.

## Principio: 3 capas
- **A) Visible** (nombre + logo que ve el cliente) → **hay que cambiarlo sí o sí**. Barato.
- **B) Interno** (identificadores de código como `TrazoColors`) → **opcional**, por limpieza. El cliente no lo ve.
- **C) Infra/URLs** (dominios, id de app, GCP, Cloudflare) → **delicado**; decisión aparte (ver notas).

---

## A. Nombre y logo VISIBLE (obligatorio)

### A.1 Logo (rediseñar con el nombre nuevo, misma paleta)
- `apps/tablet/lib/widgets/trazo_logo.dart` — logo de la tablet (Flutter).
- `apps/web/src/components/Logo.tsx` — logo del panel (React).
- SVG **inline** (símbolo `logoMark`) en: `apps/landing/index.html`, `apps/landing/aviso-legal.html`, `apps/landing/privacidad.html`.
- **Favicons e íconos** (PNG): `apps/tablet/web/favicon.png`, `apps/tablet/web/icons/Icon-*.png`, `apps/landing/demo/favicon.png`, `apps/landing/demo/icons/Icon-*.png`, favicon del panel (`apps/web`) y del superadmin (favicon data-URI en el HTML).
- **Íconos de app Android** (launcher): `apps/tablet/android/app/src/main/res/mipmap-*/` (se regeneran con la herramienta de íconos de Flutter).

### A.2 Nombre en textos y títulos
- Títulos `<title>`: `apps/web/index.html` ("Trazo — Panel del centro"), `apps/tablet/web/index.html` ("Trazo"), `apps/landing/index.html`, `aviso-legal.html`, `privacidad.html`, `apps/superadmin/index.html`.
- `apps/tablet/web/manifest.json` → `name` y `short_name` (hoy "trazo_tablet").
- `AndroidManifest.xml` → `android:label` (nombre bajo el ícono en la tablet).
- **Landing**: copy visible + datos estructurados SEO (`"name": "Trazo"` en el JSON-LD, ~líneas 355/364) + metadescripciones.
- **Strings "Trazo" visibles** en UI: React (`apps/web/src`), Flutter (`apps/tablet/lib`), superadmin. Find-replace SOLO del texto mostrado (no de identificadores).
- **Documentos legales**: nombre comercial en `apps/landing/aviso-legal.html`, `privacidad.html`, `legal/00-CHECKLIST.md`, `legal/01…04`, DPIA. (El titular sigue siendo Saulo; cambia el "nombre comercial".)

### A.3 Marca en servicios externos
- **Stripe**: renombrar el producto "Trazo — Centro" (relabel, 1 clic; el `price_…` no cambia).
- Correo de contacto / firma si lleva "Trazo".

---

## B. Identificadores de código (OPCIONAL, por limpieza)
- `TrazoColors` → p. ej. `MarcaColors` (30 ficheros en `apps/tablet/lib`) — find/replace mecánico. **No visible**; se puede dejar tal cual.
- Nombre del paquete Flutter `trazo_tablet` (pubspec + imports `package:trazo_tablet/…`) — cambiarlo es ruidoso; **opcional**.
- Clases/variables con "Trazo" en su nombre.
> Recomendación: hacer B solo si queda tiempo; no aporta al cliente.

---

## C. Infraestructura, URLs y todo lo demás (¿se puede cambiar TODO? — sí, con matices)

**Idea central:** todo lo que **ve el cliente** se puede cambiar 100 %. Lo que NO ve
(ids internos) o bien da igual, o bien —en un caso (el id de proyecto de Google)—
**es inmutable** y solo cambia migrando a un proyecto nuevo. La forma limpia de
"cambiar todas las URLs" es poner un **DOMINIO PROPIO** delante: entonces el cliente
solo ve `nuevo.app` y desaparecen de su vista los `*.pages.dev` y `*.run.app`.

| Elemento | ¿Se puede cambiar? | ¿Lo ve el cliente? | Cómo | Recom. |
|---|---|---|---|---|
| **Dominio público** (URLs) | **Sí** | **Sí** | Registrar `nuevo.app`/.com/.es y apuntar panel, landing, tablet y (opc.) API vía Cloudflare | **Hacerlo** — es EL cambio de cara al cliente |
| **App id Android** `com.trazo.trazo_tablet` | **Sí, ahora** | No (pero define la identidad en Play) | Editar `build.gradle.kts` `applicationId` | **Hacerlo ANTES de publicar en Play** (luego = app nueva) |
| **Nombre del repo GitHub** `Trazo` | **Sí** | No | GitHub → Settings → Rename; GitHub **redirige** las URLs viejas. Luego `git remote set-url` local + actualizar enlaces al APK y badges | Opcional; fácil, sin riesgo |
| **Proyectos Cloudflare Pages** (`trazo-panel/tablet/web/admin`) | Sí (creando nuevos) | Solo el `*.pages.dev` (se oculta con dominio propio) | No hay "renombrar": se **crea proyecto nuevo** con el nombre nuevo, se despliega, se actualizan referencias y CORS, y se borra el viejo | **No hace falta** si pones dominio propio. Solo si quieres los internos limpios |
| **Servicio Cloud Run** `trazo-api` (→ `trazo-api-….run.app`) | Sí (creando nuevo) | Solo el `run.app` (se oculta con dominio API propio) | No se renombra: se **despliega un servicio nuevo** con el nombre nuevo (nueva URL), se actualiza `API_URL` en todos los builds + CORS, y se retira el viejo. O más limpio: **dominio `api.nuevo.app`** delante | Poner **dominio API propio**; no recrear el servicio |
| **Proyecto GCP** `trazo-505414` (id) | **NO (inmutable)** | No (solo en el `run.app`) | El **id de proyecto no se puede renombrar**. El *nombre* de display sí. Cambiar el id = crear **proyecto nuevo** y migrar Cloud Run + Artifact Registry + secretos + conexión Aiven | **NO tocar** — mudanza enorme, cero valor visible (con dominio propio, el `trazo-505414` no se ve) |
| **Artifact Registry** `.../trazo/api` | Sí (repo nuevo) | No | Crear repo de artefactos nuevo + apuntar el `cloudbuild` | Opcional; interno |
| **Servicio Aiven** (BD) | Sí (recrear/migrar) | No | Migrar datos a un servicio nuevo | **NO** — interno, nunca se ve |
| **Tokens/secretos** (`PLATFORM_TOKEN`, `trazo-lab-2026`…) | Sí (rotar) | No | Rotar valores | Opcional (seguridad, no marca) |

### Resumen de la capa C
- **Para que el cliente vea TODO con el nombre nuevo** basta: **dominio propio** (oculta pages.dev y run.app) + **app id** + los cambios visibles de la capa A. Eso es 100 % del "todas las URLs".
- **Renombrar los internos** (Cloudflare projects, Cloud Run, GitHub) es posible pero solo por pulcritud; el único **imposible sin migrar** es el **id de proyecto GCP** (y no se ve).
- Si quieres **también** limpiar los internos, se puede planificar como una segunda fase (crear proyectos/servicios nuevos y cortar), pero conviene hacerlo **con calma**, no el día del lanzamiento.

### Ficheros con URLs/ids a actualizar cuando cambie el dominio
- `apps/tablet` build: `--dart-define=API_URL=…` (en `.github/workflows/apk.yml` y comandos de build).
- `apps/web/src/api/client.ts` / config del panel (`API_URL`).
- `apps/landing` enlaces al demo/API.
- Backend **CORS_ORIGINS** (Cloud Run env) — CRÍTICO: si el origen del panel cambia y no se actualiza, se rompe el login.
- `AGENTS.md`, `DESPLIEGUE-CLOUDRUN.md` y skills `desplegar` (documentan las URLs y nombres de proyecto).

---

## D. Documentos y material comercial (PPT, guía, PDF)

> Clave: **el PPT y los PDF se GENERAN desde fuente** (no se editan a mano). Se
> rebrandean cambiando el nombre/logo/colores en la fuente y **regenerando**.

### D.1 Presentación (PPT + su PDF)
- Fuente: `_deploy/deck.json` (contenido de las diapositivas: portada, títulos, textos con "Trazo") + `_deploy/build_ppt.js` (logo, colores, plantilla, pie de página).
- Regenerar → `docs/Trazo-Presentacion.pptx` → **re-exportar** `docs/Trazo-Presentacion.pdf`.
- Backup a renombrar/regenerar: `_deploy/Trazo-Presentacion-BACKUP.pptx`.

### D.2 Guía / guion de la presentación (HTML + PDF)
- Fuente: `_deploy/build_guia.js`, `_deploy/build_slides_html.js`, `_deploy/slides.html`, notas en `_deploy/banco_notas.json` y `_deploy/notas_abiertas.json`.
- Regenerar → `docs/Trazo-Guion-Presentacion.html` → re-exportar `docs/Trazo-Guion-Presentacion.pdf`.

### D.3 Documento de proyecto (HTML + PDF)
- Fuente: `docs/trazo-documento-proyecto.html` → re-exportar `docs/Trazo-Documento-Proyecto.pdf`.

### D.4 Cosas transversales de estos documentos
- **Logo y colores** embebidos en portada/pies de las diapos y la guía → actualizarlos en los generadores (misma paleta verde agua; solo cambia el nombre/logo).
- **Renombrar los ficheros**: `Trazo-Presentacion.*` → `NUEVO-Presentacion.*`, `Trazo-Guion-Presentacion.*`, `Trazo-Documento-Proyecto.*`.
- Textos "Trazo" dentro del cuerpo de las diapos, la guía y el documento.

### D.5 Docs internos (opcional — no van a cliente)
- `docs/taxonomia-trazo.md`, `docs/GUIA-LOCAL.md`, `AGENTS.md`, `CLAUDE.md`, changelogs y la memoria del proyecto. Se pueden actualizar por coherencia, pero **no urge** (nadie externo los ve).

---

## Orden de ejecución (cuando haya nombre)
1. Rama `rebrand/<nuevo>`.
2. **Logo nuevo** + favicons + íconos Android (capa A.1).
3. Find/replace de **texto visible** + títulos + manifests + `android:label` + legal (A.2, A.3).
4. (Opcional) `TrazoColors` → `MarcaColors` (B).
5. **Cambiar app id Android** (C.1) — porque aún no hay Play.
6. Dominio propio + apuntar webs + `CORS_ORIGINS` (+ `API_URL` si aplica) (C.2).
7. Renombrar producto en Stripe.
8. **Regenerar documentos** (capa D): editar fuente (`deck.json`, generadores, HTML) → regenerar PPT + guía + PDF → **renombrar ficheros** `Trazo-*` → `NUEVO-*`.
9. Verificar en verde: `pytest` + `tsc` + `flutter analyze`.
10. **Desplegar todo junto** (backend + panel + landing + superadmin) + **rebuild APK**.
11. **QA visual** con el navegador del MCP (panel, landing, vitrina) + revisar logos y documentos.

## Esfuerzo estimado
- **A (visible + logo):** unas horas — lo hago yo casi todo; tú solo apruebas el logo.
- **C.1 (app id):** minutos. **C.2 (dominio):** depende de registrar el dominio; el apuntado es rápido.
- **D (PPT + guía + PDF):** se regeneran desde fuente en un rato (lo hago yo; tú revisas).
- **Total realista:** ~1 sesión, en un solo despliegue.

## E. Barrido final — que NO quede "trazo" en ningún lado
Al terminar, red de seguridad para no dejarse nada:
1. `grep -rli "trazo" .` (excluyendo `node_modules`, `.venv`, `build`, `dist`, `.git`) → revisar la lista fichero a fichero.
2. **Puntos escondidos que suele olvidarse la gente:**
   - Correos/credenciales de demo: `admin@trazo.local`, `integradora@trazo.local`, `*@pruebas.trazo` (seed, tests, script del centro de pruebas).
   - Token del banco de pruebas `trazo-lab-2026` (skills/scripts) — rotar/renombrar si se quiere.
   - Nombre de fichero `_deploy/cloudflare_token.txt` (no lleva "trazo", pero revisar `_deploy/` entero).
   - `.env` / variables (`ENTORNO`, nombres de BD `trazo` en `DATABASE_URL` local).
   - Textos en `README`, `CLAUDE.md`, `AGENTS.md`, changelogs, memoria del proyecto.
   - Metadatos: `<title>`, `og:` tags, `apple-mobile-web-app-title`, `theme-color`, structured data.
   - Íconos maskable y `theme_color`/`background_color` en los `manifest.json`.
3. Repetir el barrido tras regenerar los documentos (PPT/guía/PDF) y tras el deploy.
> Objetivo: que un `grep -ri trazo` solo devuelva, como mucho, ids internos que se
> haya decidido conscientemente dejar (p. ej. el proyecto GCP inmutable).

## Notas
- Nada de esto bloquea el trabajo actual (Stripe, suscripción, deploy): todo eso es **agnóstico al nombre** y se rebrandeará en esta pasada.
- Antes de fijar el nombre: verificar **dominio libre** + que **no choque en Google Play** (hay varias apps "Trazo", incl. una infantil de trazado — motivo del cambio).
