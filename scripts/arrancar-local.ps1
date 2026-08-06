# ============================================================
#  Trazo — arrancar todo en local (backend + panel + tablet)
#
#  Uso:  boton derecho > "Ejecutar con PowerShell"   (o)
#        pwsh -File scripts\arrancar-local.ps1
#
#  Requisito: haber hecho el setup una vez (ver docs/GUIA-LOCAL.md):
#    - backend/api/.venv creado con las dependencias instaladas
#    - apps/web con `npm install` hecho
#    - apps/tablet/build/web generado (flutter build web) [opcional]
#
#  URLs (siempre las mismas):
#    API      -> http://localhost:8000   (docs en /docs)
#    Panel    -> http://localhost:5173
#    Tablet   -> http://localhost:3000
# ============================================================

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# --- Backend (FastAPI + SQLite) ---
$api = Join-Path $root "backend\api"
$py  = Join-Path $api ".venv\Scripts\python.exe"
$env:DATABASE_URL = "sqlite+aiosqlite:///./trazo.db"
$env:JWT_SECRET   = "dev"
Write-Host "Arrancando API en http://localhost:8000 ..."
Start-Process -FilePath $py -WorkingDirectory $api `
  -ArgumentList "-m","uvicorn","app.main:app","--host","127.0.0.1","--port","8000"

# --- Panel web (React + Vite) ---
$web = Join-Path $root "apps\web"
if (Test-Path (Join-Path $web "node_modules")) {
  Write-Host "Arrancando panel en http://localhost:5173 ..."
  Start-Process -FilePath "cmd.exe" -WorkingDirectory $web `
    -ArgumentList "/c","npm run dev -- --host 127.0.0.1 --port 5173"
} else {
  Write-Host "AVISO: apps/web sin node_modules. Ejecuta 'npm install' alli primero." -ForegroundColor Yellow
}

# --- Tablet (Flutter web build servido como estatico) ---
$tab = Join-Path $root "apps\tablet\build\web"
if (Test-Path $tab) {
  Write-Host "Arrancando tablet en http://localhost:3000 ..."
  Start-Process -FilePath $py -WorkingDirectory $tab `
    -ArgumentList "-m","http.server","3000"
} else {
  Write-Host "AVISO: no hay build de la tablet. Ejecuta 'flutter build web' en apps/tablet." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Listo. Abre:  http://localhost:5173  (panel)  ·  http://localhost:3000  (tablet)  ·  http://localhost:8000/docs  (API)" -ForegroundColor Green
Write-Host "Login demo: admin@trazo.local / trazo1234"
