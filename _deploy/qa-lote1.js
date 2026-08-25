export const meta = {
  name: 'qa-lote1-trazo',
  description: 'QA + usuario sobre el lote 1 del roadmap: cola de revisión sin_valorar, escalado de dificultad (trazo/selección) y margen en comparaciones de conteo',
  phases: [{ title: 'Probar' }],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para mayores. Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo. Python: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo\\backend\\api\\.venv\\Scripts\\python.exe. Trabaja EN LOCAL, sin credenciales de producción (levanta el backend en proceso con httpx/ASGI, ver backend/api/tests/conftest.py; genera instancias con app/templates/tipos.py). Contexto en AGENTS.md.

LOTE 1 recién implementado (esto es lo que debes probar, NO otra cosa):
1. **Cola de revisión de sin_valorar**: backend GET /pendientes (lista intentos sin_valorar del centro con contexto: alias, ejercicio, bloque, cuando, valores) y PATCH /intentos/{id}/resultado (fija logrado/parcial/no_logrado). Panel web: página "Por revisar" (apps/web/src/pages/Revisar.tsx), ruta /revisar, ítem de menú, endpoints listarPendientes/marcarResultado. Debe estar aislado por centro (multi-tenant).
2. **Escalado de dificultad por nivel** en trazo y seleccion_multiple (app/templates/tipos.py): selección bajo=3/medio=4/alto=5 opciones (limitado por distractores); trazo tolerancia 40/28/20 y figura por complejidad (bajo=simples, alto=complejas).
3. **Margen en comparaciones de conteo** (cual_tiene_mas/menos): el ganador difiere del resto en >=2 y las cantidades quedan en 1..9 (antes 12 vs 11, indistinguible).`

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['veredicto', 'resumen', 'problemas'],
  properties: {
    veredicto: { type: 'string', enum: ['funciona', 'funciona_con_reparos', 'roto'] },
    resumen: { type: 'string' },
    problemas: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['severidad', 'titulo', 'detalle', 'archivo'],
        properties: {
          severidad: { type: 'string', enum: ['alta', 'media', 'baja'] },
          titulo: { type: 'string' },
          detalle: { type: 'string', description: 'Cómo se reproduce y qué falla' },
          archivo: { type: 'string' },
        },
      },
    },
  },
}

phase('Probar')
const [qa, usuario] = await parallel([
  () => agent(`${CONTEXTO}\n\nEres QA. VERIFICA que el lote 1 funciona correctamente probándolo de verdad en local: (a) escribe/levanta el backend y ejerce GET /pendientes y PATCH /intentos/{id}/resultado (un sin_valorar aparece, al marcarlo desaparece y pasa a contar en la evolución; un centro no ve pendientes de otro -> aislamiento; filtrar por persona ajena da 403). (b) Genera muchas instancias de selección/trazo/conteo a los 3 niveles y comprueba el escalado (opciones 3/4/5, tolerancia 40/28/20, figura por complejidad) y el margen >=2 en comparaciones con cantidades 1..9. (c) corre 'pytest -q' y 'tsc --noEmit' en apps/web y reporta si algo falla. Devuelve SOLO el objeto del schema.`,
    { label: 'qa', phase: 'Probar', schema: SCHEMA }),
  () => agent(`${CONTEXTO}\n\nEres una INTEGRADORA no técnica usando el panel. Recorre por lectura de código el flujo de la nueva página "Por revisar" (Revisar.tsx, Layout, App.tsx, endpoints): ¿se entiende para qué sirve?, ¿el texto explica que hasta revisar no cuenta?, ¿los botones (Lo logró/A medias/No lo logró) son claros?, ¿la bandeja se vacía al trabajar?, ¿el estado vacío es tranquilizador?, ¿algo confunde o falta (contador en el menú, contexto de qué respondió la persona)? Y como MAYOR jugando: ¿el escalado hace las actividades más justas por nivel? Señala fricciones y mejoras de experiencia. Devuelve SOLO el objeto del schema.`,
    { label: 'usuario', phase: 'Probar', schema: SCHEMA }),
])
return { qa, usuario }
