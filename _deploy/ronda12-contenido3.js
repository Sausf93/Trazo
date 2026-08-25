export const meta = {
  name: 'ronda12-contenido3-trazo',
  description: 'Lote 5: más seleccion_multiple — adivinanzas, cultura española, naming (animales/transportes/muebles/ropa) e ideas prácticas',
  phases: [{ title: 'Diseñar' }],
}

const ILUS = `manzana pera platano naranja limon sandia melon cereza fresa lechuga cebolla patata pan leche huevo queso pescado pollo gallina caballo vaca oveja cerdo perro gato pajaro pez raton conejo silla mesa cama sofa sillon lampara reloj llave tijeras peine jabon toalla espejo libro lapiz gafas paraguas sombrero zapato camisa pantalon abrigo bufanda guantes calcetin coche autobus bicicleta moto camion barco avion martillo destornillador sierra pincel flor arbol sol luna nube estrella corazon casa botella cuchara cuchillo plato olla sarten moneda maceta jamon galleta`

const CONTEXTO = `Trazo — estimulación cognitiva para mayores, español de España. Plantilla "seleccion_multiple" (elegir 1 correcta). Variantes de item:
 (A) NAMING con imagen: {"id":"caballo","instruccion":"¿Qué animal es?","imagen":"caballo","correcta":"un caballo","distractores":["una vaca","un burro","un perro"]}  -> 'imagen' DEBE ser un id de la lista dada; 'correcta' es el nombre.
 (B) TEXTO (adivinanza/pregunta/definición): {"id":..., "instruccion":"la pregunta", "enunciado":"(opcional, p.ej. la adivinanza)", "correcta":..., "distractores":[...]}.
Actividad: {"bloque":∈{atencion_memoria,lenguaje,razonamiento,calculo,gnosias,praxias,percepcion,funcion_ejecutiva,vida_cotidiana}, "plantilla_tipo":"seleccion_multiple","nombre":...,"descripcion":...,"parametros_json":{"dificultad":"facil|media|dificil","opciones_min":3,"opciones_max":4,"items":[3-6]}}.
Reglas ESTRICTAS: 'correcta' INEQUÍVOCA (una sola respuesta válida), distractores plausibles pero CLARAMENTE incorrectos; español de España, cultura de un mayor español; consignas cortas; nada infantil ni diagnóstico. NO repitas lo ya existente (Completar refranes, Dichos de siempre, Canciones, El intruso, contrarios, series, analogías, oficios, crías, cuerpo, meses, sinónimos, categorías, estaciones, fiestas, huerta, refranero del tiempo, calendario, dónde vive, sonidos, días, para qué sirve, ¿Qué objeto es?, ¿Qué fruta es?, herramientas, Adivina por la pista, geografía, colores, gestos, cocina española...). Aporta variedad NUEVA.`

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
                    enunciado: { type: 'string' }, imagen: { type: 'string' },
                    correcta: { type: 'string' }, distractores: { type: 'array', minItems: 2, maxItems: 4, items: { type: 'string' } },
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
  `${CONTEXTO}\n\nIlustraciones permitidas para 'imagen': ${ILUS}\n\nDISEÑA entre 14 y 16 actividades NUEVAS, variadas. Ideas (elige y amplía): ADIVINANZAS populares clásicas (con la solución inequívoca: "Oro parece, plata no es..." -> el plátano; "Agua pasa por mi casa..." -> el aguacate/berro; usa solo adivinanzas MUY conocidas y con solución clara), NAMING con imagen de ANIMALES ("¿qué animal es?"), de TRANSPORTES ("¿qué es esto?" coche/autobús/bici/moto/barco/avión), de MUEBLES (silla/mesa/cama/sofá/sillón/lámpara), de ROPA (camisa/pantalón/abrigo/zapato/sombrero); PARA QUÉ SIRVE / QUÉ NECESITO ("para ver la televisión necesito..."); CUÁNTOS/UNIDADES ("una docena son..."); PAREJAS/ASOCIACIÓN ("¿qué va con el pan?"->la mantequilla); PARTES DE LA CASA ("¿dónde se duerme?"->el dormitorio); NATURALEZA ("¿qué sale de noche?"->la luna). Que cada 'correcta' sea inequívoca; si usas adivinanzas, que sean auténticas y de solución única. Devuelve SOLO el objeto del schema.`,
  { label: 'contenido3', phase: 'Diseñar', schema: SCHEMA, effort: 'high' })
return r
