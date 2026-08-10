# Despliegue en producción

Guía para poner Trazo en marcha en un servidor real (un centro o una cadena).
El **panel web**, la **web comercial** y el **demo** ya se publican solos en
GitHub Pages; esta guía cubre el **backend** (API + base de datos), que es lo que
hay que alojar.

## Qué se despliega

- `db` — PostgreSQL 16 (no expuesto al exterior; datos en un volumen).
- `api` — backend FastAPI (imagen de producción: no-root, sin recarga, sin datos
  de demo, healthcheck).
- `caddy` — proxy inverso con **HTTPS automático** (Let's Encrypt).
- `backup` — copia de seguridad diaria de la BD (retención 14 días).

## Requisitos

- Un servidor Linux con Docker y Docker Compose.
- Un dominio apuntando al servidor (p. ej. `api.trazo.tucentro.es`).
- Puertos 80 y 443 abiertos.

## Pasos

1. **Clona el repo** en el servidor y entra en la carpeta.
2. **Crea `.env.prod`** (NO lo subas a git) con:
   ```env
   DOMINIO=api.trazo.tucentro.es
   ACME_EMAIL=tu-correo@dominio.es
   JWT_SECRET=<genera uno: openssl rand -hex 32>
   POSTGRES_PASSWORD=<una contraseña fuerte>
   POSTGRES_USER=trazo
   POSTGRES_DB=trazo
   CORS_ORIGINS=https://sausf93.github.io
   ```
3. **Levanta**:
   ```bash
   docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
   ```
4. Caddy sacará el certificado solo. Comprueba: `https://TU_DOMINIO/health`
   debe responder `{"status":"ok","database":"up"}`.
5. **Apunta el panel y la tablet** a esa URL:
   - Panel web (Pages): configura `VITE_API_URL=https://TU_DOMINIO`.
   - Tablet (APK): compila con `--dart-define=API_URL=https://TU_DOMINIO`
     (ver `apps/tablet/DISTRIBUCION_TABLET.md`).

## Datos iniciales

En producción NO se siembran datos de demo (`ENTORNO=prod`). Para crear el primer
centro y la primera cuenta de integradora, usa un script de alta o inserta en la
BD el centro + un `UsuarioStaff` con contraseña ya hasheada (bcrypt). *(Pendiente:
un comando de bootstrap `crear-centro`.)*

## Copias de seguridad y restauración

- Las copias van a `./backups/trazo-AAAAMMDD-HHMMSS.sql.gz` (diarias, 14 días).
- **Prueba la restauración** (imprescindible: una copia sin restore probado no es
  una copia):
  ```bash
  gunzip -c backups/trazo-AAAAMMDD-HHMMSS.sql.gz | \
    docker compose -f docker-compose.prod.yml exec -T db psql -U trazo -d trazo
  ```
- Copia también los `./backups` fuera del servidor (otro disco / almacenamiento).

## Notas y pendientes conocidos

- **Rate-limit de login**: es en memoria por proceso. Con `--workers 2` el límite
  es por worker; para varias instancias, respaldarlo en Redis (interfaz ya
  preparada en `services/rate_limit.py`).
- **Migraciones**: hoy micro-migraciones idempotentes al arrancar (añaden columnas
  e índices sin borrar datos). Para evolución de esquema no trivial, migrar a
  Alembic antes de escalar a varias cadenas.
- **Observabilidad**: conviene añadir logs estructurados + captura de errores
  (Sentry/APM) antes de operar varios centros a ciegas.
