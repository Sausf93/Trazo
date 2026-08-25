export const meta = {
  name: 'ronda4b-faltantes-trazo',
  description: 'Ronda 4b: re-ejecuta las 2 lentes que fallaron (E2E y contenido del catálogo), sin credenciales en el prompt',
  phases: [{ title: 'Usar y revisar' }],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para centros de día de mayores. YA EN PRODUCCIÓN.
Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo
Python del backend: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo\\backend\\api\\.venv\\Scripts\\python.exe
Roles: plataforma(super-admin) -> admin_centro -> integradora/maestra -> paciente.
Apps: apps/web (panel React de la integradora/admin), apps/tablet (Flutter: maestra + participante en kiosco), backend/api (FastAPI + SQLAlchemy async).
Motor data-driven: 8 plantillas, ~104 actividades en backend/api/app/data/catalogo.json. Autocorrección en services/correccion.py; generadores en app/templates/tipos.py. El intento nace 'sin_valorar'; se mide desempeño, NO deterioro.
Usuaria real: Laura (integradora), NO técnica; participantes son personas mayores, algunas con baja visión/temblor/deterioro; WiFi de centros inestable.

IMPORTANTE — datos y credenciales: trabaja SIEMPRE en LOCAL, nunca contra producción, y NUNCA pidas ni uses tokens de producción. Para recorridos que escriben, levanta el backend en local con sqlite o pruébalo en proceso con httpx/ASGI (mira backend/api/tests/conftest.py para el patrón de fixtures/sesión). El seed de desarrollo crea un centro demo con la maestra integradora@trazo.local / trazo1234; para probar el alta desde cero puedes usar 'python -m app.bootstrap' (crea centro + admin) o el endpoint de plataforma con un PLATFORM_TOKEN que TÚ definas en el entorno local.

Rondas 1-4 ya arregladas (NO re-reportes): scoring dinero/conteo; widget '¿cuál tiene menos?'; catálogo en prod; mensajes de error crudos; paciente sin plan -> pantalla 'sin actividades'; errores de transporte tablet; vocabulario emparejar (código/Tablets); invariante 'una sola sala en vivo por centro'; gráfica/informe sobre desempeño (no precision); cola offline descarta 4xx permanentes; token de dispositivo oculto en el listado; secuencia_ordenar por toque (no arrastre); háptico; 'quitar última moneda'; contraste de botones/nombre a sageDark.`

const SCHEMA_REVISION = {
  type: 'object',
  additionalProperties: false,
  required: ['area', 'resumen', 'bugs', 'mejoras'],
  properties: {
    area: { type: 'string' },
    resumen: { type: 'string' },
    bugs: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severidad', 'titulo', 'detalle', 'archivo', 'correccion', 'confirmado'],
        properties: {
          severidad: { type: 'string', enum: ['alta', 'media', 'baja'] },
          titulo: { type: 'string' },
          detalle: { type: 'string' },
          archivo: { type: 'string' },
          correccion: { type: 'string' },
          confirmado: { type: 'boolean' },
        },
      },
    },
    mejoras: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['valor', 'esfuerzo', 'titulo', 'detalle'],
        properties: {
          valor: { type: 'string', enum: ['alto', 'medio', 'bajo'] },
          esfuerzo: { type: 'string', enum: ['bajo', 'medio', 'alto'] },
          titulo: { type: 'string' },
          detalle: { type: 'string' },
        },
      },
    },
  },
}

const LENTES = [
  {
    label: 'recorrido-e2e',
    prompt: `${CONTEXTO}

TU LENTE: RECORRIDO E2E COMPLETO (dogfooding), TODO EN LOCAL. Levanta el backend en local (o en proceso con httpx/ASGI) y recorre de punta a punta: super-admin crea centro y admin; admin crea 2-3 maestras (Equipo); una maestra crea pacientes y define plan (o 'plan estándar'); se abre una sala, se seleccionan pacientes, se inicia; un participante hace varias actividades de distintas plantillas respondiendo bien/mal/en blanco; se cierra; el panel muestra evolución, alertas, historial y resumen. Reproduce cada bug antes de reportarlo; anota también mejoras de flujo para el día de la prueba. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'contenido-catalogo',
    prompt: `${CONTEXTO}

TU LENTE: CONTENIDO DEL CATÁLOGO (~104 actividades). Lee backend/api/app/data/catalogo.json y los generadores (app/templates/tipos.py). Evalúa con criterio de estimulación cognitiva para mayores españoles: ¿cada actividad tiene sentido y su instrucción es clara?, ¿la dificultad escala bien (bajo/medio/alto)?, ¿hay variedad por dominio?, ¿algún contenido es confuso, culturalmente raro, ambiguo o irresoluble? Puedes generar instancias en proceso con los generadores a distintos niveles para verlas. Reporta actividades débiles como bug (si es irresoluble/incorrecta) o mejora (si mejorable), con el nombre EXACTO de la actividad y el cambio propuesto. IMPORTANTE: mantén CADA campo de texto por debajo de ~600 palabras y NO más de 12 items entre bugs y mejoras (prioriza los de más impacto) para que la salida estructurada no se corte. Devuelve SOLO el objeto del schema.`,
  },
]

phase('Usar y revisar')
const revisiones = (await parallel(
  LENTES.map((l) => () =>
    agent(l.prompt, { label: l.label, phase: 'Usar y revisar', schema: SCHEMA_REVISION }))
)).filter(Boolean)

return { revisiones }
