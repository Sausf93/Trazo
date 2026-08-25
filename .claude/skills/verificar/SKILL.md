---
name: verificar
description: Batería completa de verificación de Trazo antes de dar cualquier cosa por buena o de decirle a Saulo que pruebe. Corre tests, type-check, análisis y las pruebas E2E de escenario. Úsala tras cualquier cambio de peso y SIEMPRE antes de "listo para probar".
---

# Verificar Trazo (antes de dar algo por bueno)

No digas "listo" sin pasar esto en verde. Corre solo lo que aplique al cambio,
pero ante la duda, córrelo todo.

## Backend (siempre que toques `backend/`)
```bash
cd backend/api && ./.venv/Scripts/python.exe -m pytest -q
```
- Incluye `test_calibracion_catalogo.py`, que genera CADA actividad del catálogo a
  los 3 niveles y verifica invariantes clínicos (memoria con distractor, conteo con
  margen, seleccion con correcta en opciones, dinero que escala…). Si añadiste
  contenido y esto pasa, la estructura está sana.

## Panel web (si tocas `apps/web/`)
```bash
cd apps/web && npx tsc --noEmit      # type-check, DEBE estar limpio
cd apps/web && npm run build         # que compile
```

## Tablet (si tocas `apps/tablet/`)
```bash
cd apps/tablet && ~/flutter/bin/flutter analyze lib   # sin issues
```

## E2E de ESCENARIO (a mano; SQLite en memoria; NO tocan producción)
Tras cambios de sesiones, medición, evolución o auth:
```bash
cd backend/api
./.venv/Scripts/python.exe ecosistema_e2e.py   # 3 centros x5 trabajadoras x20 personas, 12 salas simultáneas, aislamiento -> 43/0
./.venv/Scripts/python.exe e2e_escenario.py    # 2 grupos simultáneos por centro -> 26/0
```
Si el recuento OK baja o aparece un FAIL, algo se rompió: NO desplegar.

## Recorrido como cada persona (lo que un test no ve)
Antes de "listo para probar", ponte tú en la piel de cada rol y recórrelo mental o
en el navegador (in-app browser o las URLs de prod):
- **Puesta en marcha**: admin crea equipo + personas → genera código en «Tablets».
- **Tablet**: emparejar (obligatorio, primero) → MAESTRA → login → abrir sala → PARTICIPANTE hace la actividad → maestra sigue en vivo y cierra.
- **Panel**: la responsable revisa lo `sin_valorar`, la evolución por áreas y planifica.
- Busca lo "sin sentido": pasos en mal orden, callejones, textos técnicos al mayor, cosas que no cuadran. Es TU trabajo pillarlas, no el de Saulo.

## URLs de producción para probar
- Web comercial + demo: https://trazo-web-af2.pages.dev (botón "Probar las actividades")
- Panel: https://trazo-panel.pages.dev (`admin@trazo.es` / `Trazo-2026-admin`)
- Tablet: https://trazo-tablet.pages.dev
- API health: https://trazo-api-11684717030.europe-southwest1.run.app/health
