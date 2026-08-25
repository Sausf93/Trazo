export const meta = {
  name: 'ronda10-secuencias-trazo',
  description: 'Lote 3: nuevas actividades secuencia_ordenar (rutinas y procesos de la vida diaria) con los pasos en orden correcto',
  phases: [{ title: 'Diseñar' }],
}

const CONTEXTO = `Trazo — estimulación cognitiva para mayores (centros de día), español de España. Plantilla "secuencia_ordenar": la persona pone en ORDEN unos pasos que se le presentan barajados. Esquema EXACTO de una actividad:
{"bloque":∈{atencion_memoria,lenguaje,razonamiento,calculo,gnosias,praxias,percepcion,funcion_ejecutiva,vida_cotidiana}, "plantilla_tipo":"secuencia_ordenar", "nombre":..., "descripcion":..., "parametros_json":{"dificultad":"facil|media|dificil","pasos_min":3,"pasos_max":5,"tareas":[ {"id":..., "titulo":"nombre corto de la tarea", "instruccion":"Ordena ...: lo primero arriba", "pasos":["paso1","paso2",...]} ]}}.
CLAVE: dentro de cada tarea, el array "pasos" DEBE estar ya en el ORDEN CORRECTO (de lo primero a lo último); la app los baraja y la persona los reordena. Cada paso es una frase CORTA y clara. Entre 3 y 5 pasos por tarea. El orden ha de ser INEQUÍVOCO (una sola secuencia correcta, sin pasos intercambiables).
Reglas: español de España, vida de un mayor (rutinas de casa, cocina sencilla, higiene, recados, procesos con sentido); nada infantil ni diagnóstico; consignas claras con la dirección ("lo primero arriba"). NO repitas las que ya existen: Preparar una tortilla, El calendario en orden, y otras de vestirse/higiene/día/rutinas domésticas ya presentes; aporta tareas NUEVAS y variadas.`

const SCHEMA = {
  type: 'object', additionalProperties: false, required: ['actividades'],
  properties: {
    actividades: {
      type: 'array', minItems: 6, maxItems: 10,
      items: {
        type: 'object', additionalProperties: false,
        required: ['bloque', 'plantilla_tipo', 'nombre', 'descripcion', 'parametros_json'],
        properties: {
          bloque: { type: 'string', enum: ['atencion_memoria','lenguaje','razonamiento','calculo','gnosias','praxias','percepcion','funcion_ejecutiva','vida_cotidiana'] },
          plantilla_tipo: { type: 'string', enum: ['secuencia_ordenar'] },
          nombre: { type: 'string' }, descripcion: { type: 'string' },
          parametros_json: {
            type: 'object', additionalProperties: false,
            required: ['dificultad', 'pasos_min', 'pasos_max', 'tareas'],
            properties: {
              dificultad: { type: 'string', enum: ['facil','media','dificil'] },
              pasos_min: { type: 'integer' }, pasos_max: { type: 'integer' },
              tareas: {
                type: 'array', minItems: 2, maxItems: 5,
                items: {
                  type: 'object', additionalProperties: false,
                  required: ['id', 'titulo', 'instruccion', 'pasos'],
                  properties: {
                    id: { type: 'string' }, titulo: { type: 'string' },
                    instruccion: { type: 'string' },
                    pasos: { type: 'array', minItems: 3, maxItems: 5, items: { type: 'string' } },
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
  `${CONTEXTO}\n\nDISEÑA entre 7 y 9 actividades NUEVAS de secuencia_ordenar, cada una con 2-4 tareas, variadas y con sentido para un mayor español. Ideas (amplía libremente): COCINA (hacer un café con leche, freír un huevo, hacer un bocadillo, poner agua a hervir para la pasta), HIGIENE Y CASA (lavarse los dientes, hacer la cama, poner la lavadora, tender la ropa, fregar los platos), RECADOS (ir a comprar el pan, coger el autobús, hacer una llamada de teléfono, escribir y enviar una carta), PROCESOS CON SENTIDO (plantar una semilla y que crezca, del huevo a la gallina, preparar la mesa para comer y recogerla), NÚMEROS/CANTIDADES (ordenar de menor a mayor, tallas de ropa). Asegúrate de que cada 'pasos' esté en el ORDEN CORRECTO e inequívoco. Devuelve SOLO el objeto del schema.`,
  { label: 'secuencias', phase: 'Diseñar', schema: SCHEMA, effort: 'high' })
return r
