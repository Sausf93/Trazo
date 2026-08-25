---
name: contenido
description: Añadir actividades al catálogo de Trazo de forma SEGURA — valida que sean inequívocas, que las ilustraciones existan y que la autocorrección puntúe bien, mantiene la calibración en verde y despliega. Úsala cuando Saulo pida "más contenido", "más actividades", "más ejercicios" o "más variedad".
---

# Añadir contenido al catálogo (seguro)

El catálogo es `backend/api/app/data/catalogo.json` (~230 actividades). Se
re-sincroniza en CADA arranque del backend, así que **el contenido nuevo solo
necesita redesplegar el backend** (no los zips de frontend).

Regla de oro: **INEQUÍVOCO**. Cada respuesta correcta debe ser la única defendible
por un mayor español; ante la mínima duda, DESCARTA el item (Saulo ya ha pillado
refranes ambiguos como "en casa del herrero, cuchillo/cuchara de palo").

## Cómo generar

- **Imagen/número (memoria_visual, busqueda_visual, conteo_comparacion)**: genéralo
  TÚ a mano de forma determinista. Es inequívoco por construcción. **Solo ids que
  tengan SVG** en `apps/tablet/assets/ilustraciones/` (hay ~130: frutas, verduras,
  animales, muebles, cocina, ropa, transportes, herramientas, naturaleza, figuras,
  caras, monedas, billetes). Un id sin SVG pinta un fallback feo.
- **Texto (seleccion_multiple)**: puede generarlo un agente `general-purpose` con un
  schema estricto, pero **revísalo item por item** y descarta lo dudoso o lo que
  duplique temas ya existentes.

## Formas por plantilla (parametros_json)

- `seleccion_multiple`: `{dificultad, opciones_min, opciones_max, items:[{id, instruccion, enunciado?, correcta, distractores:[...]}]}`. Verdadero/Falso o Sí/No: `opciones_min=2, opciones_max=2`, 1 distractor.
- `memoria_visual`: `{dificultad, recordar_min, recordar_max, segundos, banco:[{id,label}]}` — `len(banco) > recordar_max` (deja distractores).
- `busqueda_visual`: `{dificultad, instruccion, objetivo:{id,label}, distractores:[{id,label}]}` — el objetivo NO puede estar entre los distractores.
- `conteo_comparacion`: `{dificultad, modo, instruccion, cantidad_min, cantidad_max, objetos:[ids]}`. Modos: `contar` (1 objeto), `sumar` (2 objetos), `cual_tiene_mas`/`cual_tiene_menos` (2 objetos).

## Pipeline (script en scratchpad, mira lote6-12*.py como plantilla)

1. **Valida** antes de insertar: cada id ∈ SVG; objetivo ∉ distractores; memoria banco>recordar_max; correcta ∉ distractores y distractores únicos.
2. **Prueba la autocorrección** (esto es lo que evita meter respuestas mal): para cada actividad, con `sys.path.insert(0,'backend/api')`:
   ```python
   from app.templates.registry import get_plantilla
   from app.services.correccion import corregir
   inst = get_plantilla(tipo).generar(params, nivel='medio', rng=random.Random(s))
   o = inst.cantidad_objetivo
   # respuesta correcta -> DEBE dar 'logrado':
   #  memoria:   v={'aciertos': o['n_figuras'], 'fallos':0}
   #  busqueda:  v={'aciertos': o['objetivos'], 'fallos':0}
   #  conteo:    v={'respuesta': o['solucion']['cantidad'|'total'|'objeto_mayor'|'objeto_menor']}
   #  seleccion: v={'eleccion': inst.cantidad_objetivo['correcta']}   (y un distractor -> 'no_logrado')
   assert corregir(tipo, v, o) == 'logrado'
   ```
   Repite con varias semillas (0..4) y a los 3 niveles (bajo/medio/alto).
3. **Inserta** con dedup por nombre (indent=1, antes del `]` final).
4. **Calibración + tests**: `cd backend/api && ./.venv/Scripts/python.exe -m pytest tests/test_calibracion_catalogo.py -q` y luego `-m pytest -q`. Deben quedar en verde (la calibración genera CADA actividad a los 3 niveles y verifica invariantes).
5. **Despliega el backend** (skill `desplegar`, solo parte backend) y **verifica en prod**: cuenta actividades con login `admin@trazo.es` / `Trazo-2026-admin` → `GET /ejercicios`.
6. **Actualiza** `CAMBIOS-2026-08-18.md` y la memoria de despliegue con la rev y el recuento.

## Temas ya usados (no duplicar)
Mira los `nombre` existentes por plantilla antes de generar (hay muchos: refranes,
canciones, intruso, contrarios, oficios, crías, sinónimos, colores, dónde se
compra, con qué se hace, más grande/pequeño, qué va antes, sí/no, verdadero/falso,
naming animales/transportes/muebles/ropa, memoria de cocina/ropa/granja/despensa…).
