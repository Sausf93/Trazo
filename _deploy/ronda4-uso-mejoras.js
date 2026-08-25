export const meta = {
  name: 'ronda4-uso-mejoras-trazo',
  description: 'Ronda 4: 6 agentes distintos USAN la app (recorridos E2E) y proponen mejoras; síntesis en roadmap priorizado',
  phases: [
    { title: 'Usar y revisar' },
    { title: 'Sintetizar' },
  ],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para centros de día de mayores. YA EN PRODUCCIÓN.
Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo
Python del backend: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo\\backend\\api\\.venv\\Scripts\\python.exe
API en prod: https://trazo-api-11684717030.europe-southwest1.run.app  (token de plataforma/super-admin: ed31452494dd9721532a7f78ae0adedb339b4496eed8ec0a)
Roles: plataforma(super-admin) -> admin_centro -> integradora/maestra -> paciente.
Apps: apps/web (panel React de la integradora/admin), apps/tablet (Flutter: maestra + participante en kiosco), apps/superadmin (panel plataforma), backend/api (FastAPI + SQLAlchemy async).
Motor de ejercicios data-driven: 8 plantillas, ~104 actividades en backend/api/app/data/catalogo.json. La autocorrección (services/correccion.py) es la señal clínica principal; anomalias.py detecta cambio vs la propia base del paciente. El intento nace 'sin_valorar'; se mide desempeño, NO deterioro.
Contexto de negocio: cliente ancla es la empresa de Laura (5 centros); competencia NeuronUP; la usuaria real (Laura, integradora) NO es técnica; los participantes son personas mayores, algunas con baja visión/temblor/deterioro cognitivo; el WiFi de los centros es inestable.

MUY IMPORTANTE sobre datos: NO crees datos persistentes en la API de PRODUCCIÓN (pronto habrá una prueba definitiva con un centro limpio). Para recorridos que ESCRIBEN, levanta el backend en LOCAL o pruébalo en proceso:
 - En local usa sqlite por defecto; puedes arrancar 'uvicorn app.main:app' o, mejor, importar la app y usar httpx/TestClient en un script con el .venv. Mira backend/api/tests/conftest.py para el patrón de sesión/fixtures.
 - La API de prod úsala SOLO para lectura/inspección ligera. Si por algo imprescindible escribieras en prod, nombra todo 'QA-BORRAR-*' y bórralo al final.

Rondas 1-3 (NO re-reportes lo ya arreglado): scoring dinero euros/céntimos y conteo dict; widget '¿cuál tiene menos?'; catálogo cargado en prod (sincronizar_catalogo siempre); advisory lock de migración; tablet doble-pulsación/crashes/401 kiosko; login sin demo en prod; nav 'Tablets'; gráfica de evolución coherente; mensajes de error crudos (JSON/status) en tablet y panel; paciente sin plan -> pantalla 'sin actividades' (no felicitación); errores de transporte de la tablet normalizados; 'Abrir sala' sin pacientes guiado; vocabulario token->'código de emparejamiento', revocar->desvincular, sin 'kiosco/login/línea/Dispositivos'; bootstrap CLI normaliza email.`

const SCHEMA_REVISION = {
  type: 'object',
  additionalProperties: false,
  required: ['area', 'resumen', 'bugs', 'mejoras'],
  properties: {
    area: { type: 'string' },
    resumen: { type: 'string', description: 'Qué probaste/leíste y el veredicto general' },
    bugs: {
      type: 'array',
      description: 'Defectos CONFIRMADOS (reproducidos por ti). Vacío si no hay.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severidad', 'titulo', 'detalle', 'archivo', 'correccion', 'confirmado'],
        properties: {
          severidad: { type: 'string', enum: ['alta', 'media', 'baja'] },
          titulo: { type: 'string' },
          detalle: { type: 'string', description: 'Cómo se reproduce y por qué importa para la prueba real' },
          archivo: { type: 'string', description: 'archivo:linea' },
          correccion: { type: 'string', description: 'Arreglo concreto propuesto' },
          confirmado: { type: 'boolean' },
        },
      },
    },
    mejoras: {
      type: 'array',
      description: 'Ideas de mejora de producto/UX/valor (no bugs). Concretas y accionables.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['valor', 'esfuerzo', 'titulo', 'detalle'],
        properties: {
          valor: { type: 'string', enum: ['alto', 'medio', 'bajo'] },
          esfuerzo: { type: 'string', enum: ['bajo', 'medio', 'alto'] },
          titulo: { type: 'string' },
          detalle: { type: 'string', description: 'Qué cambiar, dónde, y por qué mejora la experiencia o el valor clínico/comercial' },
        },
      },
    },
  },
}

const LENTES = [
  {
    label: 'recorrido-e2e',
    prompt: `${CONTEXTO}

TU LENTE: RECORRIDO E2E COMPLETO (dogfooding). Recorre de punta a punta el flujo real como si fueras el equipo el día de la prueba, USÁNDOLO (levanta el backend en local/en proceso y dríbalo por HTTP):
1) super-admin crea un centro y su admin; 2) admin entra al panel y crea 2-3 maestras (Equipo); 3) una maestra crea pacientes y les define un plan (o usa 'plan estándar'); 4) empareja una tablet participante y una maestra (código); 5) la maestra abre una sala, selecciona pacientes, inicia; 6) el participante hace varias actividades de distintas plantillas y responde bien/mal/deja en blanco; 7) la maestra cierra; 8) el panel muestra evolución, alertas, historial y resumen.
Busca fricciones y bugs REALES que aparezcan al hacerlo: pasos que no se pueden completar, estados incoherentes, datos que no cuadran entre tablet y panel, cosas confusas para alguien no técnico. Reproduce cada bug antes de reportarlo. Además, anota mejoras de flujo que harían el día de la prueba más fácil. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'valor-clinico-producto',
    prompt: `${CONTEXTO}

TU LENTE: VALOR CLÍNICO Y DE PRODUCTO. Lee cómo se mide y se muestra (services/correccion.py, anomalias.py, la evolución y alertas del panel apps/web, el resumen de sesión) y evalúa: ¿lo que Trazo mide y presenta es ÚTIL y accionable para Laura y su equipo? ¿La señal de 'cambio vs su propia base' se entiende y guía la intervención? ¿Qué falta para que un centro pague por esto frente a NeuronUP (informes, objetivos por paciente, seguimiento por áreas, exportar, comunicación con familias)? Céntrate en MEJORAS de alto valor (con esfuerzo estimado); reporta bug solo si encuentras una incoherencia de medición real y reproducible. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'accesibilidad-mayor',
    prompt: `${CONTEXTO}

TU LENTE: ACCESIBILIDAD PARA LA PERSONA MAYOR (participante). Revisa a fondo la experiencia del kiosco (apps/tablet: participante_screen.dart y los widgets de actividad) con la mirada de alguien de 80+ con baja visión, temblor, o carga cognitiva alta: tamaño de objetivos táctiles, contraste y tamaño de texto, tiempos y timeouts, feedback de acierto/error, audio/instrucciones, recuperación de errores, y que nunca se quede 'atrapado'. Señala barreras concretas (bug si algo impide usarlo; mejora si solo lo hace más difícil de lo necesario) con archivo:linea y el cambio propuesto. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'contenido-catalogo',
    prompt: `${CONTEXTO}

TU LENTE: CONTENIDO DEL CATÁLOGO (~104 actividades). Lee backend/api/app/data/catalogo.json y los generadores (app/templates/tipos.py). Evalúa, con criterio de estimulación cognitiva para mayores españoles: ¿cada actividad tiene sentido y su instrucción es clara?, ¿la dificultad escala bien (bajo/medio/alto)?, ¿hay variedad suficiente por dominio?, ¿algún contenido es confuso, culturalmente raro, ambiguo o irresoluble? Puedes generar instancias en proceso (usa los generadores con distintos niveles) para verlas. Reporta actividades débiles como bug (si es irresoluble/incorrecta) o mejora (si solo mejorable), con el nombre exacto de la actividad y el cambio propuesto. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'seguridad-rgpd-multitenant',
    prompt: `${CONTEXTO}

TU LENTE: SEGURIDAD, MULTI-TENANT y RGPD (adversarial). Intenta ROMPER el aislamiento entre centros y los permisos: IDOR (acceder a pacientes/sesiones/planes de otro centro cambiando ids), escalada de rol, abuso del token de dispositivo, saltarse la suspensión de un centro moroso, filtración de datos personales en respuestas/errores/URLs. Verifica RGPD: minimización de datos, borrado real de un paciente, alias interno vs datos identificativos. Puedes probar en local levantando dos centros. Reporta solo lo REPRODUCIDO (bug) y endurecimientos concretos (mejora). Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'robustez-uso-real',
    prompt: `${CONTEXTO}

TU LENTE: ROBUSTEZ EN USO REAL (WiFi inestable, tablets, concurrencia). Revisa cómo se comporta la tablet y el backend ante: pérdida/reconexión de red a mitad de actividad, tablet que se duerme y vuelve, doble sala abierta, varias sesiones/participantes concurrentes contra el mismo backend, cierre de app y recuperación de sesión (kiosco y maestra), reintentos y estados 'colgados'. Lee apps/tablet/lib/api/client.dart, participante_screen.dart, maestra_screen.dart, y el backend de sesiones. Reproduce lo que puedas (simula fallos de red/latencia en local). Reporta bugs y mejoras de robustez con archivo:linea. Devuelve SOLO el objeto del schema.`,
  },
]

phase('Usar y revisar')
const revisiones = (await parallel(
  LENTES.map((l) => () =>
    agent(l.prompt, { label: l.label, phase: 'Usar y revisar', schema: SCHEMA_REVISION }))
)).filter(Boolean)

phase('Sintetizar')
const SCHEMA_SINTESIS = {
  type: 'object',
  additionalProperties: false,
  required: ['resumen_ejecutivo', 'roadmap'],
  properties: {
    resumen_ejecutivo: { type: 'string', description: '3-6 frases: estado general y lo más importante a hacer antes de la prueba definitiva' },
    roadmap: {
      type: 'array',
      description: 'Todo (bugs + mejoras) deduplicado y priorizado',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['prioridad', 'tipo', 'titulo', 'por_que', 'donde'],
        properties: {
          prioridad: { type: 'string', enum: ['critico_prueba', 'alto_valor', 'nice_to_have'] },
          tipo: { type: 'string', enum: ['bug', 'mejora'] },
          titulo: { type: 'string' },
          por_que: { type: 'string' },
          donde: { type: 'string', description: 'archivo(s) o zona' },
        },
      },
    },
  },
}

const sintesis = await agent(
  `${CONTEXTO}

Eres el SINTETIZADOR de la ronda 4. Aquí están los resultados JSON de 6 agentes que usaron y revisaron la app desde lentes distintas:

${JSON.stringify(revisiones, null, 2)}

Deduplica, resuelve solapes y PRIORIZA TODO (bugs y mejoras juntos) en un roadmap con tres niveles: 'critico_prueba' (hay que arreglarlo antes de la prueba definitiva con centro real), 'alto_valor' (mejora mucho el producto/venta, hacer pronto) y 'nice_to_have'. Sé honesto: si algo no aporta, no lo subas de nivel. Escribe también un resumen ejecutivo. Devuelve SOLO el objeto del schema.`,
  { label: 'sintesis', phase: 'Sintetizar', schema: SCHEMA_SINTESIS })

return { revisiones, sintesis }
