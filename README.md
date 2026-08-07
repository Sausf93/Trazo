# Trazo

### 🌐 Web comercial → **https://sausf93.github.io/Trazo/**

<sub>Se publica sola en cada cambio de `apps/landing/`. Si da 404, activa Pages una vez:
**Settings → Pages → Build and deployment → Source: "GitHub Actions"**.</sub>

---

Herramienta de estimulación cognitiva para personas mayores (mayoría con Alzheimer)
en centros de día. Tres piezas:

1. **App de tablet** (Flutter) — ejercicios de 8 dominios cognitivos, modo participante
   y modo facilitadora.
2. **Backend** (FastAPI + PostgreSQL) — motor de ejercicios *data-driven*, sesiones,
   intentos y detección temprana de cambios.
3. **Panel web** (React + TypeScript) — evolución individual y de grupo, alertas y
   gestión del catálogo de ejercicios sin tocar código.

Además, una **web comercial** (`apps/landing/`) para presentar el producto y captar centros.

> El objetivo no es que mejoren siempre — es que **no empeoren sin que nadie se dé
> cuenta a tiempo**. Toda comparación se hace contra el histórico de la propia
> persona, nunca entre usuarios distintos.

Documentos de concepto: [`trazo-presentacion.html`](trazo-presentacion.html) ·
[`trazo-especificacion-tecnica.md`](trazo-especificacion-tecnica.md).

---

## Estructura del repo

```
trazo/
|-- apps/
|   |-- tablet/     (Flutter)   -- OK, modelo maestra/kiosco
|   |-- web/        (React)      -- OK, funcionando
|   `-- landing/    (HTML)       -- OK, web comercial
|-- backend/
|   `-- api/        (FastAPI)    -- OK, Fase 1 + modelo operativo
|-- docs/           (API.md, GUIA-LOCAL.md, MODELO-OPERATIVO.md, MEJORAS-EXPERTO.md)
|-- scripts/        (arrancar-local.ps1)
|-- docker-compose.yml
|-- .env.example
`-- README.md
```

## Estado

| Pieza | Estado |
|---|---|
| Backend: modelo de datos + auth JWT + motor de plantillas + alertas + planes/dispositivos/cola + auto-sugerencia de nivel + ciclo de sala | OK, funcionando |
| Catálogo de actividades (data-driven en `catalogo.json`) | OK, 71 actividades (>=8 por tipo) |
| Tests (unitarios + E2E de sesión) | OK, 28 en verde |
| Panel web (React): login, panel, evolución, alertas, ejercicios, sesión en vivo, editor de planes, dispositivos | OK, verificado contra la API |
| Web comercial (landing): con slider de actividades ilustradas | OK |
| App tablet (Flutter): modelo maestra/kiosco, reparto por toque, cola con las 8 actividades y mediciones | OK, compila y arranca |

> Guía paso a paso para levantarlo en local: [`docs/GUIA-LOCAL.md`](docs/GUIA-LOCAL.md).

---

## Arranque rápido (sin Docker, funciona ya)

**Backend** (una terminal):

```powershell
cd backend/api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:DATABASE_URL = "sqlite+aiosqlite:///./trazo.db"
$env:JWT_SECRET   = "dev"
uvicorn app.main:app --reload
```

**Panel web** (otra terminal):

```powershell
cd apps/web
npm install
npm run dev
```

Abre <http://localhost:5173> y entra con **admin@trazo.local** / **trazo1234**.

Para el camino con Docker (PostgreSQL) y la app de tablet, ver
[`docs/GUIA-LOCAL.md`](docs/GUIA-LOCAL.md).

---

## Credenciales de demo

| Email | Contraseña | Rol |
|---|---|---|
| `admin@trazo.local` | `trazo1234` | admin_centro |
| `integradora@trazo.local` | `trazo1234` | integradora |

Datos sembrados: 1 centro, 3 participantes, 8 ejercicios (uno por bloque) y una
evolución que dispara una alerta en "PAQ-01" (praxias).

## Seguridad y RGPD

- Datos de salud = categoría especial (RGPD). Usuarios finales **pseudonimizados**:
  el nombre real vive en una tabla separada (`datos_identificativos`).
- Patrón `.env` + `.gitignore` + `.env.example`; **cero credenciales en el código**.
- Registro de auditoría de accesos a datos de usuarios finales.
- El centro es responsable del tratamiento; nosotros, encargados (proveedor del software).
