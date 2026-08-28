# Trazo — contexto para agentes

SaaS de **estimulación cognitiva para centros de día de mayores**. Monorepo. En
producción. Lee esto antes de tocar nada: evita re-derivar la arquitectura.

## Qué es y quién lo usa
- **Participante** (persona mayor, a veces con Alzheimer/baja visión/temblor): juega en la **tablet** en modo kiosco. Es el usuario más frágil; prioriza dignidad, claridad sin leer, y que nunca se quede atrapado.
- **Maestra/integradora** (no técnica): opera la sesión en la tablet y supervisa en el **panel web**.
- **admin_centro**: gestiona equipo y personas del centro (panel web).
- **plataforma** (super-admin, Saulo): crea/bloquea centros con `PLATFORM_TOKEN`.
- Cliente ancla: empresa de Laura (5 centros). Competencia: NeuronUP.

## Arquitectura
| Pieza | Carpeta | Stack |
|---|---|---|
| API | `backend/api` | FastAPI, SQLAlchemy 2.0 async (asyncpg/aiosqlite), Pydantic v2, PyJWT, bcrypt |
| Panel del centro | `apps/web` | React + Vite + TypeScript (integradora/admin) |
| Tablet | `apps/tablet` | Flutter (kiosco participante + pantalla maestra) |
| Super-admin | `apps/superadmin` | HTML estático (token de plataforma) |
| Landing + vitrina | `apps/landing` | HTML + build de la tablet en `/demo` |

- **Multi-tenant**: TODO va scoped por `centro_id`. Anti-IDOR en cada endpoint (`usuario_del_centro`, `acceso_centro` revalida centro activo). No romper el aislamiento.
- **Motor de ejercicios data-driven**: 8 plantillas, ~230 actividades en `backend/api/app/data/catalogo.json`. Generadores en `app/templates/tipos.py`. Autocorrección en `app/services/correccion.py`. Añadir contenido: skill `contenido` (pipeline seguro con validación y prueba de autocorrección).
- Las 8 plantillas: `trazo`, `seleccion_multiple`, `memoria_visual`, `busqueda_visual`, `secuencia_ordenar`, `arrastrar_posicion` (por TOQUE, no arrastre), `conteo_comparacion`, `manejo_cantidad` (dinero/reloj).

## Flujos clave (no re-derivar)
- **Tablet, inicio (`rol_screen.dart`)**: EMPAREJAR es lo primero y OBLIGATORIO (código del panel «Tablets», token de dispositivo). SOLO tras emparejar aparece MAESTRA / PARTICIPANTE, y el rol se elige EN CADA USO (la misma tablet sirve para ambas). El demo/vitrina usa `GaleriaScreen` (sin emparejar).
- **Varias salas por centro**: un centro puede tener VARIAS salas abiertas a la vez (2 maestras, 2 grupos). `GET /sesiones/activa` devuelve `salas[]`; el kiosco muestra las salas para elegir grupo y cada persona queda ligada a SU sala (`_sesionIdActivo`). Una persona no puede estar en dos salas abiertas (409). `GET /sesiones/mia-abierta` = la sala que abrió esa maestra.
- **Rejillas de imágenes** (memoria/busqueda): `columnas = min(base, n)` y sin celdas vacías al final, para que no se descentren con pocas figuras.

## Principios clínicos que NO revertir
- El intento **nace `sin_valorar`**: no puntúa hasta que la integradora lo revise. `sin_valorar` ≠ `no_logrado` (no tocar nada no es fallar).
- Se mide **desempeño**, no deterioro; nunca lenguaje diagnóstico.
- Señal principal = **resultado autocorregido** (`logrado`=1 / `parcial`=0.5 / `no_logrado`=0), definido para las 8 plantillas. La gráfica de evolución y el informe a familia usan ESE desempeño (no `precision`, que solo existe en 3 plantillas).
- Alertas = cambio vs la **propia base** del paciente (por sesión, segmentado por dificultad). No re-implementar heurísticas cliente que la contradigan.

## Comandos
```bash
# Backend (venv en backend/api/.venv)
cd backend/api && ./.venv/Scripts/python.exe -m pytest -q      # tests
# Panel web
cd apps/web && npx tsc --noEmit          # type-check
cd apps/web && npm run build             # -> dist/
# Tablet (flutter en ~/flutter/bin)
cd apps/tablet && flutter analyze lib
```
- Windows + Git Bash: `flutter build web --base-href /` se corrompe (msys convierte `/`). Para la tablet raíz **omite `--base-href`** (por defecto es `/`); para la vitrina usa `MSYS_NO_PATHCONV=1 flutter build web --base-href /demo/`.
- El catálogo se re-sincroniza en CADA arranque del backend (`sincronizar_catalogo`), dev y prod. Por eso **el contenido nuevo solo necesita redesplegar el backend** (no los zips).
- **Base de datos, sin scripts manuales**: al arrancar el backend (`main.py` lifespan) corre solo y de forma idempotente: `create_all` (tablas nuevas) + `migrar_columnas`/`migrar_indices` (`app/services/migraciones.py`, portable sqlite/postgres) + `sincronizar_catalogo`. Prod = Aiven Postgres (lock de arranque anti-carrera), tests/local = SQLite. Cambios SIEMPRE aditivos (no se pierde nada). Para un campo nuevo: modelo en `models.py` + línea idempotente en `migraciones.py`; se aplica solo al desplegar.
- **Pruebas E2E de escenario** (no son pytest; se ejecutan a mano, SQLite en memoria, NO tocan prod): `backend/api/ecosistema_e2e.py` (3 centros × 5 trabajadoras × 20 personas, 12 salas simultáneas, aislamiento; debe dar 43/0) y `backend/api/e2e_escenario.py` (2 grupos simultáneos, 26/0). Correr tras cambios de sesiones/medición/evolución/auth.

## Despliegue (producción, proyecto GCP `trazo-505414`)
Cloud Run + Aiven Postgres + Cloudflare Pages. Guía: `DESPLIEGUE-CLOUDRUN.md`. Pasos exactos en la skill `desplegar`. Resumen:
```bash
IMAGE=europe-southwest1-docker.pkg.dev/trazo-505414/trazo/api:latest
gcloud builds submit backend/api --config=deploy/cloudbuild.yaml --substitutions=_IMAGE=$IMAGE
gcloud run deploy trazo-api --image=$IMAGE --region=europe-southwest1   # NO tocar env vars
```
- API viva: `https://trazo-api-11684717030.europe-southwest1.run.app`.
- **Frontends → Cloudflare Pages por CLI (wrangler)**. Account ID `ab53eefbf67e5d2483f0bbfcd8ceaefe`. Proyectos EXISTENTES (nombre | subdominio): `trazo-panel`|trazo-panel, `trazo-tablet`|trazo-tablet, **`trazo-web`|trazo-web-af2** (¡el proyecto se llama `trazo-web`!), `trazo-admin`|trazo-admin. Rama de producción `main`. NO crear proyectos nuevos (cambiaría la URL y rompería CORS). Comando: `CLOUDFLARE_API_TOKEN=<tok> CLOUDFLARE_ACCOUNT_ID=ab53... npx wrangler pages deploy <dir> --project-name=<X> --branch=main --commit-dirty=true`. Saulo da un token puntual (Pages:Edit) y lo revoca al terminar. **Cada dir va a SU proyecto (¡no confundir!):** el **panel** `apps/web/dist` (tras `npm run build`) → proyecto **`trazo-panel`** (URL real del panel = `trazo-panel.pages.dev`, el ÚNICO origen que el CORS del backend permite para el panel); la **tablet** `apps/tablet/build/web` (tras `flutter build web --release --dart-define=API_URL=<api>`) → **`trazo-tablet`**; la **vitrina** `apps/landing` (tras montar el demo en `apps/landing/demo`) → **`trazo-web`** (subdominio `trazo-web-af2`). ⚠️ Desplegar el panel a `trazo-web` rompe el login (CORS) y NO actualiza el panel real. Zips de respaldo en `_deploy/` (git-ignorados).
- Vitrina: el botón "Probar las actividades" enlaza a `demo/index.html?vitrina=1` (funciona en prod y al abrir la landing en local; un enlace a `demo/` mostraría un listado en `file://`).
- CORS se define con `--env-vars-file` (no `--update-env-vars` con comas).

## Convenciones
- Español en toda la UI; vocabulario **digno** ("Personas", no "Pacientes"; "Tablets", no "Dispositivos"; sin "kiosco/login/token/línea/bloque" en texto visible → "código de emparejamiento", "áreas").
- Accesibilidad del mayor: objetivos táctiles grandes, contraste ≥4.5:1 (usar `sageDark`, no `sage`, para texto blanco), háptico en cada selección, nada que atrape, sin prisa.
- Antes de dar por bueno un cambio: `pytest` + `tsc` + `flutter analyze` en verde.

## Skills del repo (`.claude/skills/`)
- `desplegar`: build + deploy del backend (Cloud Run) y de los frontends (Cloudflare por wrangler).
- `contenido`: añadir actividades al catálogo de forma segura (validar ilustraciones/inequívoco + probar autocorrección + calibración) y desplegar.
- `verificar`: batería completa de comprobación antes de dar algo por bueno (pytest, calibración, tsc, flutter analyze, E2E de escenario).
- `ronda-qa`: lanzar una ronda multi-agente de revisión/juego por personas.

## Estado y backlog
- `CAMBIOS-2026-08-18.md`: changelog de lo último. `BACKLOG-ESPECIALISTAS.md`: mejoras de un panel de 9 especialistas (algunas hechas, otras pendientes). La memoria `trazo-despliegue-gcp` (fuera del repo) lleva el detalle de revisiones desplegadas.
- Antes de decir "listo para probar": pásalo tú por los flujos como cada persona (emparejar → maestra → participante → panel) y por `verificar`; no hagas que Saulo encuentre lo básico.
