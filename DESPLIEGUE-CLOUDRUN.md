# Desplegar Trazo gratis — Cloud Run + Aiven + Cloudflare Pages

Entorno de pruebas completo en la nube, sin coste. Cada pieza va en su sitio:

| Pieza | Dónde | Qué es |
|---|---|---|
| **API** (FastAPI) | **Google Cloud Run** | Contenedor Docker, escala a cero. |
| **Base de datos** | **Aiven for PostgreSQL** (free) | Postgres estándar. *(Intercambiable: vale cualquier Postgres — Supabase, etc. — cambiando `DATABASE_URL`.)* |
| **Panel del centro** | **Cloudflare Pages** | React estático (`apps/web`). |
| **Tablet + Web comercial** | **Cloudflare Pages** (o GitHub Pages) | Flutter web + landing (`apps/landing`, con `/demo`). |
| **Super-admin** | Cloudflare Pages **privado** (Access) | `apps/superadmin/index.html`. |

> El backend ya funciona con SQLite o Postgres. En Cloud Run el disco es efímero
> (se borra en cada arranque), por eso la BD va fuera (Aiven).

---

## 0) Requisitos (una vez)
- Cuenta de Google Cloud (con facturación activada; el free tier de Cloud Run no cobra dentro de sus límites).
- Cuenta de Aiven (plan free) y de Cloudflare (Pages).
- `gcloud` CLI instalado y `gcloud auth login`.
- Elige un proyecto y una región, p. ej.:
  ```bash
  export PROJECT=trazo-pruebas
  export REGION=europe-southwest1     # Madrid
  gcloud config set project $PROJECT
  gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
  gcloud artifacts repositories create trazo --repository-format=docker --location=$REGION
  ```

## 1) Base de datos (Aiven)
1. En Aiven: **Create service → PostgreSQL → plan Free**. Región cercana.
2. Cuando esté "Running", copia el **Service URI** (algo como `postgres://avnadmin:XXX@host:port/defaultdb?sslmode=require`).
3. Conviértelo al formato del backend (driver asyncpg y **sin** `?sslmode=`, que asyncpg no entiende — el SSL lo activamos con `DB_SSL=true`):
   ```
   postgresql+asyncpg://avnadmin:XXX@host:port/defaultdb
   ```
   Guárdalo como `DATABASE_URL`.

## 2) Desplegar la API en Cloud Run
Genera secretos fuertes primero:
```bash
export JWT_SECRET=$(openssl rand -hex 32)
export PLATFORM_TOKEN=$(openssl rand -hex 24)   # tu llave de super-admin
export IMAGE=$REGION-docker.pkg.dev/$PROJECT/trazo/api:latest
```
Construye la imagen (usa `Dockerfile.prod` vía Cloud Build) y despliega:
```bash
gcloud builds submit backend/api \
  --config=deploy/cloudbuild.yaml \
  --substitutions=_IMAGE=$IMAGE

gcloud run deploy trazo-api \
  --image=$IMAGE --region=$REGION \
  --allow-unauthenticated \
  --set-env-vars=ENTORNO=prod,SEED_ON_STARTUP=false,WEB_CONCURRENCY=1,DB_SSL=true \
  --set-env-vars="DATABASE_URL=$DATABASE_URL" \
  --set-env-vars="JWT_SECRET=$JWT_SECRET" \
  --set-env-vars="PLATFORM_TOKEN=$PLATFORM_TOKEN" \
  --set-env-vars="CORS_ORIGINS=https://TU-PANEL.pages.dev,https://TU-WEB.pages.dev,https://TU-SUPERADMIN.pages.dev"
```
Cloud Run te da una URL, p. ej. `https://trazo-api-xxxx.a.run.app`. Guárdala como `API`.
Comprueba:
```bash
curl -s $API/health          # {"status":"ok","database":"up"}
```
> Nota: las tablas se crean solas al arrancar (migraciones idempotentes). No hace falta migrar a mano.

> Si aún no sabes las URLs del panel/web (paso 4/5), despliega primero con un CORS
> provisional y luego actualízalo:
> `gcloud run services update trazo-api --region=$REGION --update-env-vars="CORS_ORIGINS=..."`

## 3) Crear el primer centro (super-admin, nivel 0)
Con el token de plataforma, crea un centro y su admin (idempotente):
```bash
curl -X POST $API/plataforma/centros \
  -H "X-Platform-Token: $PLATFORM_TOKEN" -H "Content-Type: application/json" \
  -d '{"centro":"Centro de prueba","email":"admin@centro.es","password":"una-clave-fuerte","nombre":"Tu Nombre"}'
```
(O usa el **panel de super-admin** del paso 6, más cómodo.)

## 4) Panel del centro (Cloudflare Pages)
Build apuntando a la API:
```bash
cd apps/web
echo "VITE_API_URL=$API" > .env.production
npm ci && npm run build      # genera dist/
```
En Cloudflare Pages: **Create project → Direct Upload** (o conecta el repo con build command `npm run build`, output `dist`, y variable `VITE_API_URL`). Sube `apps/web/dist`.
Anota la URL (`https://TU-PANEL.pages.dev`) y añádela a `CORS_ORIGINS` (paso 2).

## 5) Tablet + Web comercial (Cloudflare Pages)
```bash
cd apps/tablet
flutter build web --release --dart-define=API_URL=$API --base-href /demo/
# Monta el sitio: landing en la raíz, tablet en /demo
rm -rf ../landing/demo && mkdir -p ../landing/demo
cp -r build/web/* ../landing/demo/
```
Sube `apps/landing` a otro proyecto de Cloudflare Pages (`https://TU-WEB.pages.dev`).
La tablet queda en `https://TU-WEB.pages.dev/demo/` y la vitrina se abre sola.
Añade `https://TU-WEB.pages.dev` a `CORS_ORIGINS`.
> Para tablets físicas (APK) se compila igual con `--dart-define=API_URL=$API`.

## 6) Panel de super-admin (privado)
Sube `apps/superadmin/index.html` a un proyecto de Cloudflare Pages **protegido con Cloudflare Access** (solo tu email). Al abrirlo:
- **Dirección de la API**: pega tu `$API`.
- **Token de plataforma**: tu `$PLATFORM_TOKEN`.
Desde ahí creas centros, ves cuentas y bloqueas/reactivas. Añade su URL a `CORS_ORIGINS`.
> Alternativa sin hosting: abre el `index.html` en tu equipo y apúntalo a `$API`
> (tendrás que permitir su origen en CORS, p. ej. `http://localhost:PUERTO`).

## 7) Bloquear un centro que no paga
Desde el panel de super-admin (botón **Bloquear**) o por API:
```bash
curl -X PATCH $API/plataforma/centros/<ID> \
  -H "X-Platform-Token: $PLATFORM_TOKEN" -H "Content-Type: application/json" \
  -d '{"activo":false}'
```
Efecto inmediato: nadie de ese centro entra (ni tokens ya emitidos), datos intactos. `{"activo":true}` reactiva.

---

## Variables de entorno de la API (resumen)
| Variable | Valor | Para qué |
|---|---|---|
| `ENTORNO` | `prod` | Exige JWT propio, no siembra demo. |
| `DATABASE_URL` | `postgresql+asyncpg://…` | Postgres (Aiven). |
| `DB_SSL` | `true` | SSL para Postgres gestionado. |
| `JWT_SECRET` | aleatorio largo | Firma de tokens. |
| `PLATFORM_TOKEN` | aleatorio | Llave del super-admin (nivel 0). |
| `CORS_ORIGINS` | URLs del panel/web/super-admin | Permitir el navegador. |
| `SEED_ON_STARTUP` | `false` | No crear datos demo. |
| `WEB_CONCURRENCY` | `1` | 1 worker (rate-limit en memoria). |

## Límites y siguiente escalón
- **Rate-limit de login** es en memoria por proceso: con 1 worker + escala a cero de Cloud Run es correcto para pruebas. En producción seria, respaldarlo en Redis.
- **Backups**: Aiven free no trae backups; para producción, subir de plan o volcar la BD periódicamente. (En despliegue por VM/compose ya hay backups cifrados, ver `DESPLIEGUE.md`.)
- **Cold start** ~2-4 s tras inactividad; irrelevante en pruebas.
