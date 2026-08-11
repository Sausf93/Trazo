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
   BACKUP_PASSPHRASE=<frase larga para cifrar las copias; guárdala aparte y a salvo>
   ```
3. **Levanta**:
   ```bash
   docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
   ```
4. Caddy sacará el certificado solo. Comprueba: `https://TU_DOMINIO/health`
   debe responder `{"status":"ok","database":"up"}`.
5. **Crea el primer centro y la cuenta de acceso** (ver "Datos iniciales").
6. **Apunta el panel y la tablet** a esa URL:
   - **Panel web** (apps/web): es un build estático que **compilas tú apuntando a
     tu backend** (`VITE_API_URL=https://TU_DOMINIO npm run build`) y sirves en
     cualquier hosting estático. NO se publica solo en GitHub Pages (ahí solo van
     la web comercial y el demo). Puedes servirlo detrás del mismo Caddy.
   - **Tablet** (APK): compila con `--dart-define=API_URL=https://TU_DOMINIO`
     (ver `apps/tablet/DISTRIBUCION_TABLET.md`).

## Datos iniciales

En producción NO se siembran datos de demo (`ENTORNO=prod`), así que la BD arranca
vacía. Crea el primer centro y su cuenta de administración con el comando de
bootstrap (dentro del contenedor `api`):

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod exec api \
  python -m app.bootstrap --centro "Centro de Día X" \
  --email admin@centrox.es --nombre "Nombre Apellidos" --password "una-contraseña-fuerte"
```

Es idempotente (si la cuenta ya existe, no hace nada). A partir de ahí, desde el
panel se dan de alta las integradoras y los pacientes.

## Copias de seguridad y restauración

- Las copias van a `./backups/trazo-AAAAMMDD-HHMMSS.sql.gz.gpg` (diarias, 14 días),
  **cifradas** con `BACKUP_PASSPHRASE` (cifrado en reposo).
- **Prueba la restauración** (imprescindible: una copia sin restore probado no es
  una copia):
  ```bash
  gpg --batch --passphrase "$BACKUP_PASSPHRASE" -d backups/trazo-AAAAMMDD-HHMMSS.sql.gz.gpg \
    | gunzip \
    | docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T db psql -U trazo -d trazo
  ```
- Copia los `./backups` **fuera del servidor** (otro disco / almacenamiento).
- **Cifrado de la BD en disco**: además del cifrado de las copias, cifra el
  volumen del host donde vive PostgreSQL (LUKS / disco cifrado del proveedor).
  Para datos de categoría especial es lo recomendable.

## Notas y pendientes conocidos

- **Rate-limit de login**: es en memoria por proceso. Con `--workers 2` el límite
  es por worker; para varias instancias, respaldarlo en Redis (interfaz ya
  preparada en `services/rate_limit.py`).
- **Migraciones**: hoy micro-migraciones idempotentes al arrancar (añaden columnas
  e índices sin borrar datos). Para evolución de esquema no trivial, migrar a
  Alembic antes de escalar a varias cadenas.
- **Observabilidad**: conviene añadir logs estructurados + captura de errores
  (Sentry/APM) antes de operar varios centros a ciegas.
