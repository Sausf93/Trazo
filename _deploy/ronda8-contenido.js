export const meta = {
  name: 'ronda8-contenido-trazo',
  description: 'Ampliar el catálogo: un agente diseña actividades nuevas (refranes/naming/categorías) y otro las revisa por corrección y adecuación cultural',
  phases: [{ title: 'Diseñar' }, { title: 'Revisar' }],
}

// Ilustraciones INEQUÍVOCAS disponibles (id -> objeto claro). Solo estas para imagen.
const ILUSTRACIONES = `manzana pera platano naranja limon tomate cebolla lechuga pan leche huevo queso pescado pollo gallina caballo vaca oveja cerdo perro gato pajaro pez raton conejo silla mesa cama sofa sillon lampara reloj llave tijeras peine jabon toalla espejo libro lapiz gafas paraguas sombrero zapato camisa pantalon abrigo bufanda guantes calcetin coche autobus bicicleta moto camion barco avion martillo destornillador sierra pincel flor arbol sol luna nube estrella corazon casa botella cuchara cuchillo plato olla sarten moneda maceta jamon galleta pastel sandia melon cereza fresa`

const ESQUEMA_TXT = `FORMATO EXACTO de una actividad (JSON del catálogo). SOLO plantilla_tipo "seleccion_multiple". bloque ∈ {atencion_memoria, lenguaje, razonamiento, calculo, gnosias, praxias, percepcion, funcion_ejecutiva, vida_cotidiana}.
Dos variantes de item:
 (A) NAMING (con imagen): {"id":"manzana","instruccion":"¿Qué es esto?","imagen":"manzana","correcta":"una manzana","distractores":["una pera","un tomate","una pelota"]}  -> 'imagen' DEBE ser uno de los ids de la lista dada; 'correcta' es el nombre en palabras.
 (B) TEXTO (refrán/copla/contrario/categoría/definición): {"id":"pajaro","instruccion":"¿Cómo termina el refrán?","enunciado":"Más vale pájaro en mano que...","correcta":"ciento volando","distractores":["dos en el nido","pico y pala","cien en el árbol"]}  -> sin 'imagen'.
Cada actividad: {"bloque":..., "plantilla_tipo":"seleccion_multiple", "nombre":..., "descripcion":..., "parametros_json":{"dificultad":"facil|media|dificil","opciones_min":3,"opciones_max":4,"items":[... 3-6 items ...]}}.
Reglas: la 'correcta' es INEQUÍVOCAMENTE correcta; los distractores son plausibles pero CLARAMENTE incorrectos (nada de dos respuestas válidas); español de España, población mayor (reminiscencia: refranes, coplas, oficios de antes, cocina tradicional, geografía básica de España); consignas cortas y claras; nada infantil ni diagnóstico. NO repitas actividades que ya existen (Completar refranes, El intruso, ¿Qué objeto es?, Adivina por la pista, contrarios, series...). Aporta variedad NUEVA.`

const CONTEXTO = `Trazo — estimulación cognitiva para mayores (centros de día), español de España. Se amplía el catálogo con actividades NUEVAS de la plantilla seleccion_multiple (elegir 1 opción correcta entre varias). ${ESQUEMA_TXT}\n\nIlustraciones permitidas para 'imagen' (ids): ${ILUSTRACIONES}`

const SCHEMA_ACTIVIDADES = {
  type: 'object', additionalProperties: false,
  required: ['actividades'],
  properties: {
    actividades: {
      type: 'array', minItems: 10, maxItems: 18,
      items: {
        type: 'object', additionalProperties: false,
        required: ['bloque', 'plantilla_tipo', 'nombre', 'descripcion', 'parametros_json'],
        properties: {
          bloque: { type: 'string', enum: ['atencion_memoria','lenguaje','razonamiento','calculo','gnosias','praxias','percepcion','funcion_ejecutiva','vida_cotidiana'] },
          plantilla_tipo: { type: 'string', enum: ['seleccion_multiple'] },
          nombre: { type: 'string' },
          descripcion: { type: 'string' },
          parametros_json: {
            type: 'object', additionalProperties: false,
            required: ['dificultad', 'opciones_min', 'opciones_max', 'items'],
            properties: {
              dificultad: { type: 'string', enum: ['facil','media','dificil'] },
              opciones_min: { type: 'integer' },
              opciones_max: { type: 'integer' },
              items: {
                type: 'array', minItems: 3, maxItems: 6,
                items: {
                  type: 'object', additionalProperties: false,
                  required: ['id', 'instruccion', 'correcta', 'distractores'],
                  properties: {
                    id: { type: 'string' },
                    instruccion: { type: 'string' },
                    enunciado: { type: 'string' },
                    imagen: { type: 'string' },
                    correcta: { type: 'string' },
                    distractores: { type: 'array', minItems: 2, maxItems: 4, items: { type: 'string' } },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
}

phase('Diseñar')
const propuesta = await agent(
  `${CONTEXTO}\n\nDISEÑA entre 12 y 16 actividades NUEVAS, variadas y de calidad, repartidas por bloques. Prioriza contenido dinámico y culturalmente rico: refranes/dichos menos obvios, coplas y canciones populares (completar), oficios y herramientas de antes, cocina tradicional española, geografía básica (capitales/regiones), naming con imagen (usa SOLO ids de la lista), categorías ("¿cuál es un/una X?"), definiciones sencillas ("¿qué es un/una...?"). Asegúrate de que la 'correcta' es inequívoca y los distractores claramente incorrectos. Devuelve SOLO el objeto del schema.`,
  { label: 'generador', phase: 'Diseñar', schema: SCHEMA_ACTIVIDADES, effort: 'high' })

phase('Revisar')
const SCHEMA_REVISION = {
  type: 'object', additionalProperties: false,
  required: ['veredicto_global', 'items'],
  properties: {
    veredicto_global: { type: 'string' },
    items: {
      type: 'array',
      description: 'Una entrada por CADA item (identificado por nombre_actividad + id) con su decisión',
      items: {
        type: 'object', additionalProperties: false,
        required: ['nombre_actividad', 'item_id', 'decision', 'motivo'],
        properties: {
          nombre_actividad: { type: 'string' },
          item_id: { type: 'string' },
          decision: { type: 'string', enum: ['aprobar', 'corregir', 'descartar'] },
          motivo: { type: 'string' },
          correccion_sugerida: { type: 'string', description: 'Si decision=corregir: qué cambiar (p. ej. la correcta o un distractor)' },
        },
      },
    },
  },
}

const revision = await agent(
  `${CONTEXTO}\n\nEres REVISOR clínico y cultural (español de España, mayores). Aquí están las actividades propuestas por otro agente:\n\n${JSON.stringify(propuesta?.actividades ?? [], null, 2)}\n\nRevisa ITEM POR ITEM con rigor. Para cada item decide: 'aprobar' (correcta inequívoca, distractores claramente incorrectos, imagen —si la hay— corresponde al id y al nombre, culturalmente correcto y claro), 'corregir' (bien salvo un detalle: di exactamente qué), o 'descartar' (respuesta ambigua/incorrecta, dos opciones válidas, refrán mal, imagen que no corresponde, culturalmente dudoso, o duplica algo existente). Sé ESTRICTO: ante cualquier duda de que la 'correcta' sea la única correcta, descarta o corrige. Verifica especialmente los refranes/coplas (que existan y terminen así) y que cada 'imagen' sea un id de la lista permitida y coincida con lo nombrado. Devuelve SOLO el objeto del schema, con una entrada por cada item de cada actividad.`,
  { label: 'revisor', phase: 'Revisar', schema: SCHEMA_REVISION, effort: 'high' })

return { propuesta, revision }
