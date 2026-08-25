export const meta = {
  name: 'ronda9-contenido2-trazo',
  description: 'Segundo lote de contenido: más actividades seleccion_multiple de texto (oficios, animales, cuerpo, tiempo, sinónimos, categorías), culturalmente ricas',
  phases: [{ title: 'Diseñar' }],
}

const CONTEXTO = `Trazo — estimulación cognitiva para mayores (centros de día), español de España. Ampliamos el catálogo con actividades NUEVAS de la plantilla "seleccion_multiple" (elegir 1 opción correcta). SOLO variante de TEXTO (sin imagen): cada item {"id":..., "instruccion":"la pregunta o consigna corta", "enunciado":"(opcional) frase con hueco, p.ej. un refrán", "correcta":"la respuesta", "distractores":["...","...","..."]}. Cada actividad: {"bloque":∈{atencion_memoria,lenguaje,razonamiento,calculo,gnosias,praxias,percepcion,funcion_ejecutiva,vida_cotidiana}, "plantilla_tipo":"seleccion_multiple", "nombre":..., "descripcion":..., "parametros_json":{"dificultad":"facil|media|dificil","opciones_min":3,"opciones_max":4,"items":[3-6 items]}}.
Reglas ESTRICTAS: la 'correcta' es INEQUÍVOCAMENTE la única correcta; los distractores son plausibles pero CLARAMENTE incorrectos (jamás dos respuestas válidas); español de España, cultura y vida de una persona mayor española (reminiscencia); consignas cortas y claras; nada infantil ni diagnóstico. NO repitas actividades ya existentes: Completar refranes, Dichos de siempre, Canciones de la infancia, El intruso, contrarios, series, Como esto es a aquello, ¿Qué hace falta?, Cuentas de la compra, El cambio justo, En el día a día, La cocina española, Piensa antes de actuar, ¿De qué color es?, Geografía de España, Los gestos de siempre, y las de naming con imagen.`

const SCHEMA = {
  type: 'object', additionalProperties: false, required: ['actividades'],
  properties: {
    actividades: {
      type: 'array', minItems: 12, maxItems: 18,
      items: {
        type: 'object', additionalProperties: false,
        required: ['bloque', 'plantilla_tipo', 'nombre', 'descripcion', 'parametros_json'],
        properties: {
          bloque: { type: 'string', enum: ['atencion_memoria','lenguaje','razonamiento','calculo','gnosias','praxias','percepcion','funcion_ejecutiva','vida_cotidiana'] },
          plantilla_tipo: { type: 'string', enum: ['seleccion_multiple'] },
          nombre: { type: 'string' }, descripcion: { type: 'string' },
          parametros_json: {
            type: 'object', additionalProperties: false,
            required: ['dificultad', 'opciones_min', 'opciones_max', 'items'],
            properties: {
              dificultad: { type: 'string', enum: ['facil','media','dificil'] },
              opciones_min: { type: 'integer' }, opciones_max: { type: 'integer' },
              items: {
                type: 'array', minItems: 3, maxItems: 6,
                items: {
                  type: 'object', additionalProperties: false,
                  required: ['id', 'instruccion', 'correcta', 'distractores'],
                  properties: {
                    id: { type: 'string' }, instruccion: { type: 'string' },
                    enunciado: { type: 'string' }, correcta: { type: 'string' },
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
const r = await agent(
  `${CONTEXTO}\n\nDISEÑA entre 14 y 16 actividades NUEVAS de TEXTO, variadas y de calidad, repartidas por bloques. Ideas (elige y amplía, no te limites): OFICIOS ("¿quién arregla los zapatos?" -> el zapatero; panadero, carpintero, sastre, herrero, pescadero...), ANIMALES (crías: la cría de la vaca es el ternero; sonidos; dónde viven), CUERPO HUMANO ("¿con qué parte del cuerpo oyes?" -> los oídos), TIEMPO (meses del año, estaciones, días de la semana: "¿qué mes va después de marzo?"), SINÓNIMOS ("otra forma de decir 'contento'"), CATEGORÍAS ("¿cuál es un medio de transporte?"), NATURALEZA Y ESTACIONES ("¿en qué estación caen las hojas?"), FIESTAS Y TRADICIONES españolas, PLANTAS Y HUERTA, PROVERBIOS DEL CAMPO/TIEMPO ("cielo empedrado..."), UNIDADES ("¿cuántos días tiene una semana?"). Que cada 'correcta' sea inequívoca. Devuelve SOLO el objeto del schema.`,
  { label: 'generador2', phase: 'Diseñar', schema: SCHEMA, effort: 'high' })
return r
