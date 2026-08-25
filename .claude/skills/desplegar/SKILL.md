---
name: desplegar
description: Redesplegar Trazo a producción — reconstruye e implementa el backend en Cloud Run (gcloud) y despliega los frontends (panel/tablet/vitrina) a Cloudflare Pages por wrangler CLI. Úsala cuando haya que "subir", "desplegar" o "redesplegar" tras cambios. Proyecto GCP trazo-505414; Cloudflare account ab53eefbf67e5d2483f0bbfcd8ceaefe.
---

# Desplegar Trazo a producción

Redespliegue **solo de código** (sin tocar variables de entorno de Cloud Run).
Guía completa: `DESPLIEGUE-CLOUDRUN.md`. Contexto: `AGENTS.md`.

Requisitos ya cumplidos en la máquina de Saulo: `gcloud` autenticado (proyecto
`trazo-505414`), `flutter` en `~/flutter/bin`, node/npm, `apps/web/node_modules`.

Constantes:
- `API = https://trazo-api-11684717030.europe-southwest1.run.app`
- `IMAGE = europe-southwest1-docker.pkg.dev/trazo-505414/trazo/api:latest`

## 1. Verificar en verde ANTES de desplegar
```bash
cd backend/api && ./.venv/Scripts/python.exe -m pytest -q
cd apps/web && npx tsc --noEmit
cd apps/tablet && flutter analyze lib
```

## 2. Backend (solo si cambió `backend/`)
```bash
gcloud builds submit backend/api --config=deploy/cloudbuild.yaml \
  --substitutions=_IMAGE=europe-southwest1-docker.pkg.dev/trazo-505414/trazo/api:latest
gcloud run deploy trazo-api \
  --image=europe-southwest1-docker.pkg.dev/trazo-505414/trazo/api:latest \
  --region=europe-southwest1      # NO pasar --set-env-vars: borraría la config
curl -s https://trazo-api-11684717030.europe-southwest1.run.app/health   # {"status":"ok","database":"up"}
```
El build tarda ~1-2 min; puedes lanzarlo en background. Las migraciones de
esquema se aplican solas al arrancar (idempotentes, `app/services/migraciones.py`).

## 3. Construir los frontends (si cambió el frontend correspondiente)
Nota Git Bash: `--base-href /` se corrompe; para la tablet raíz OMÍTELO.
```bash
# Panel web -> apps/web/dist
cd apps/web && npm run build

# Tablet (base-href / por defecto) -> apps/tablet/build/web
cd apps/tablet && flutter build web --release \
  --dart-define=API_URL=https://trazo-api-11684717030.europe-southwest1.run.app

# Vitrina: build /demo/ y montar en landing -> apps/landing
cd apps/tablet && MSYS_NO_PATHCONV=1 flutter build web --release \
  --dart-define=API_URL=https://trazo-api-11684717030.europe-southwest1.run.app \
  --base-href /demo/
cd /c/Users/Saulo.Santacruz/Desktop/Trazo && rm -rf apps/landing/demo && mkdir -p apps/landing/demo && cp -r apps/tablet/build/web/* apps/landing/demo/
```
Regenera también los zips de respaldo si quieres (Compress-Archive → `_deploy/`),
pero el despliegue real va por wrangler (abajo), no por zips.

## 4. Desplegar los frontends a Cloudflare Pages (wrangler CLI)
Saulo da un token puntual (Custom Token → **Account · Cloudflare Pages · Edit**) y
lo revoca al terminar. Account ID: `ab53eefbf67e5d2483f0bbfcd8ceaefe`.
```bash
export CLOUDFLARE_API_TOKEN='<token de Saulo>'
export CLOUDFLARE_ACCOUNT_ID='ab53eefbf67e5d2483f0bbfcd8ceaefe'
cd apps/web   # cualquier dir con node_modules para npx
# wrangler despliega una CARPETA (no zip). --branch=main = producción.
npx wrangler pages deploy dist                    --project-name=trazo-panel  --branch=main --commit-dirty=true
npx wrangler pages deploy ../tablet/build/web      --project-name=trazo-tablet --branch=main --commit-dirty=true
npx wrangler pages deploy ../landing               --project-name=trazo-web    --branch=main --commit-dirty=true
```
**OJO con los nombres**: el proyecto de la vitrina se llama **`trazo-web`** (su
subdominio es `trazo-web-af2.pages.dev`). NO crear proyectos nuevos (cambiaría la
URL y rompería CORS). `trazo-admin` no se toca salvo cambios en `apps/superadmin`.

Verifica en producción (deben dar 200): `trazo-panel.pages.dev`,
`trazo-tablet.pages.dev`, `trazo-web-af2.pages.dev` (y `/demo/`).

Alternativa sin token: empaquetar los zips en `_deploy/` y que Saulo los suba por el
panel de Cloudflare (Create deployment en el proyecto EXISTENTE).
