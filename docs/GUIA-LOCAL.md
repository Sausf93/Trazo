# Trazo — Guía para verlo todo funcionando en local

Esta guía asume Windows (tu equipo). Hay **dos caminos**:

- **Camino A (rápido, funciona ya):** Python + Node, base de datos SQLite. No
  necesitas instalar nada pesado. Ideal para desarrollo y para ver el panel.
- **Camino B (como en producción):** Docker Desktop con PostgreSQL. Un solo
  comando levanta todo, pero requiere instalar Docker Desktop.

La **app de tablet (Flutter)** es opcional y va aparte (sección 4), porque
necesita el SDK de Flutter.

---

## 0. Qué tienes ya instalado

| Herramienta | ¿Instalada? | Necesaria para |
|---|---|---|
| Python 3.12 | ✅ sí | Backend |
| Node 24 + npm | ✅ sí | Panel web |
| Docker (cliente) | ⚠️ solo el cliente, sin motor | Camino B |
| Docker Desktop | ❌ no | Camino B (hay que instalarlo) |
| Flutter SDK | ✅ sí (en `C:\Users\Saulo.Santacruz\flutter`) | App tablet |

---

## 1. Camino A — Rápido (Python + Node + SQLite) ✅ recomendado para empezar

### 1.1 Backend (API)

Abre una terminal (PowerShell) en la raíz del proyecto:

```powershell
cd C:\Users\Saulo.Santacruz\Desktop\Trazo\backend\api

# Crear entorno virtual e instalar dependencias (solo la primera vez)
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Usar SQLite (no hace falta Postgres) y arrancar
$env:DATABASE_URL = "sqlite+aiosqlite:///./trazo.db"
$env:JWT_SECRET   = "dev"
uvicorn app.main:app --reload
```

- API en <http://localhost:8000>
- **Documentación interactiva** (para probar a mano): <http://localhost:8000/docs>
- Al arrancar crea las tablas y siembra datos de demo automáticamente.

> Deja esta terminal abierta (el backend corriendo).

### 1.2 Panel web

En **otra** terminal:

```powershell
cd C:\Users\Saulo.Santacruz\Desktop\Trazo\apps\web
npm install            # solo la primera vez
npm run dev
```

- Panel en <http://localhost:5173>
- Entra con **admin@trazo.local** / **trazo1234**

Con las dos terminales abiertas (backend + web) ya tienes el sistema funcionando:
verás la lista de usuarios, la evolución de cada uno y la alerta de "Paquito".

---

## 2. Camino B — Docker (PostgreSQL, como en producción)

### 2.1 Instalar Docker Desktop

1. Descarga Docker Desktop para Windows: <https://www.docker.com/products/docker-desktop/>
2. Instálalo y **ábrelo** (tiene que quedar corriendo; verás la ballena en la
   bandeja del sistema).
3. Comprueba que funciona:
   ```powershell
   docker compose version
   docker ps
   ```

### 2.2 Levantar todo

```powershell
cd C:\Users\Saulo.Santacruz\Desktop\Trazo
copy .env.example .env      # solo la primera vez
docker compose up --build
```

Levanta los **4 servicios** (la primera vez tarda: compila también la app de tablet):
- API: <http://localhost:8000> (docs en `/docs`)
- Panel web: <http://localhost:5173>
- App tablet: <http://localhost:3000>
- PostgreSQL: `localhost:5432`

> Nota: el `docker compose` está preparado y el YAML validado, pero **no se ha
> podido ejecutar aquí** (esta máquina solo tiene el cliente de Docker, sin motor).
> En cuanto instales Docker Desktop, `docker compose up --build` debería levantar
> todo. La app de tablet se compila dentro de Docker con la imagen oficial de Flutter.

Para pararlo: `Ctrl+C`, y para limpiar: `docker compose down`.

---

## 3. Credenciales de demo

| Email | Contraseña | Rol |
|---|---|---|
| `admin@trazo.local` | `trazo1234` | admin_centro (puede crear ejercicios) |
| `integradora@trazo.local` | `trazo1234` | integradora |

Datos sembrados: 1 centro, 3 participantes (Paquito, Marisa, Juan), 8 ejercicios
(uno por bloque) y una evolución que dispara una alerta en "Paquito" (praxias).

---

## 4. App de tablet (Flutter)

Flutter **ya está instalado** en `C:\Users\Saulo.Santacruz\flutter` y la app
**compila y arranca**. Para usar el comando `flutter` cómodamente, añade al PATH
`C:\Users\Saulo.Santacruz\flutter\bin` (o usa la ruta completa al ejecutable).

Con el **backend corriendo** (sección 1.1), abre la app en el navegador:

```powershell
cd C:\Users\Saulo.Santacruz\Desktop\Trazo\apps\tablet
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
```

Entra con `integradora@trazo.local` / `trazo1234`, elige un participante y el
ejercicio "Sigue la línea", y prueba a dibujar el trazo con el ratón/dedo.

> Estado: compila sin errores y bootea. Los renderers de `trazo` y
> `seleccion_multiple` están completos; el resto de plantillas usan una vista
> genérica (pendiente de completar).

---

## 5. Ejecutar los tests del backend

```powershell
cd C:\Users\Saulo.Santacruz\Desktop\Trazo\backend\api
.\.venv\Scripts\python -m pytest -q
```

---

## 6. Problemas frecuentes

- **"uvicorn no se reconoce"**: activa el venv antes (`.\.venv\Scripts\Activate.ps1`).
- **El panel dice que no conecta con la API**: asegúrate de que el backend está
  corriendo en el puerto 8000 y que abriste el panel en `localhost:5173`.
- **`Activate.ps1` bloqueado por política de ejecución**: ejecuta una vez
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` y acepta.
- **Puerto 8000 ocupado**: cierra el proceso anterior o arranca uvicorn con
  `--port 8001` (y ajusta `VITE_API_URL` del panel).
