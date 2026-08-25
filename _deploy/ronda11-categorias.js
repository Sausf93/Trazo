export const meta = {
  name: 'ronda11-categorias-trazo',
  description: 'Lote 4: actividades arrastrar_posicion de categorización (2 zonas, por toque) reutilizando ilustraciones existentes',
  phases: [{ title: 'Diseñar' }],
}

const ILUS = `manzana pera platano naranja limon sandia melon cereza fresa lechuga cebolla patata pan leche huevo queso pescado pollo gallina caballo vaca oveja cerdo perro gato pajaro pez raton conejo silla mesa cama sofa sillon lampara reloj llave tijeras peine jabon toalla espejo libro lapiz gafas paraguas sombrero zapato camisa pantalon abrigo bufanda guantes calcetin coche autobus bicicleta moto camion barco avion martillo destornillador sierra pincel flor arbol sol luna nube estrella corazon casa botella cuchara cuchillo plato olla sarten moneda maceta jamon galleta`

const CONTEXTO = `Trazo — estimulación cognitiva para mayores, español de España. Plantilla "arrastrar_posicion" (por TOQUE): la persona toca una pieza y luego la ZONA a la que pertenece. Esquema EXACTO:
{"bloque":∈{...9 bloques...}, "plantilla_tipo":"arrastrar_posicion", "nombre":..., "descripcion":..., "parametros_json":{"dificultad":"facil|media|dificil","instruccion":"consigna clara","cantidad_min":4,"cantidad_max":5,"muestrear":true,"piezas":[ {"id":"manzana","label":"manzana","zona_correcta":"fruta"} , ...], "zonas":[ {"id":"fruta","label":"Frutas"}, {"id":"verdura","label":"Verduras"} ]}}.
Reglas: EXACTAMENTE 2 zonas por actividad; cada pieza tiene 'zona_correcta' = id de una de las 2 zonas; el 'id' de la pieza DEBE ser uno de los ids de ilustración de la lista (para que se vea el dibujo); pon 3-5 piezas por zona (para que muestrear siempre pueda coger de ambas). La clasificación ha de ser INEQUÍVOCA culturalmente en España: EVITA casos discutibles (el tomate y el pimiento se consideran verdura en España -> NO los pongas como 'fruta'; evita cualquier pieza cuya categoría se pueda discutir). Consignas claras. NO repitas las que ya existen: La lista de la compra, Guardar la compra, Vístete según el tiempo, Cada cosa a su cuarto, Fruta o verdura, Arriba o abajo, Clasifica por color/tamaño, Poner la mesa.`

const SCHEMA = {
  type: 'object', additionalProperties: false, required: ['actividades'],
  properties: {
    actividades: {
      type: 'array', minItems: 5, maxItems: 8,
      items: {
        type: 'object', additionalProperties: false,
        required: ['bloque', 'plantilla_tipo', 'nombre', 'descripcion', 'parametros_json'],
        properties: {
          bloque: { type: 'string', enum: ['atencion_memoria','lenguaje','razonamiento','calculo','gnosias','praxias','percepcion','funcion_ejecutiva','vida_cotidiana'] },
          plantilla_tipo: { type: 'string', enum: ['arrastrar_posicion'] },
          nombre: { type: 'string' }, descripcion: { type: 'string' },
          parametros_json: {
            type: 'object', additionalProperties: false,
            required: ['dificultad', 'instruccion', 'cantidad_min', 'cantidad_max', 'muestrear', 'piezas', 'zonas'],
            properties: {
              dificultad: { type: 'string', enum: ['facil','media','dificil'] },
              instruccion: { type: 'string' },
              cantidad_min: { type: 'integer' }, cantidad_max: { type: 'integer' },
              muestrear: { type: 'boolean' },
              piezas: {
                type: 'array', minItems: 6, maxItems: 10,
                items: {
                  type: 'object', additionalProperties: false,
                  required: ['id', 'label', 'zona_correcta'],
                  properties: { id: { type: 'string' }, label: { type: 'string' }, zona_correcta: { type: 'string' } },
                },
              },
              zonas: {
                type: 'array', minItems: 2, maxItems: 2,
                items: {
                  type: 'object', additionalProperties: false,
                  required: ['id', 'label'],
                  properties: { id: { type: 'string' }, label: { type: 'string' } },
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
  `${CONTEXTO}\n\nIlustraciones permitidas (usa estos ids como 'id' de pieza): ${ILUS}\n\nDISEÑA entre 6 y 8 actividades NUEVAS de arrastrar_posicion (2 zonas, categorización INEQUÍVOCA). Ideas: animales vs objetos; animales de granja vs animales de casa (mascotas); medios de transporte por tierra vs por agua; cosas que van en la nevera (leche/queso/huevo/pescado/pollo) vs en la despensa/fuera; prendas de arriba (camisa/abrigo/bufanda) vs de abajo/pies (pantalón/calcetín/zapato); cosas de la cocina (olla/sartén/cuchara/plato) vs herramientas (martillo/destornillador/sierra/llave); comida vs cosas que no se comen. Elige clasificaciones que en España nadie discutiría (evita tomate/pimiento como fruta, y cualquier caso dudoso). Pon 3-5 piezas por zona, cada 'id' de la lista. Devuelve SOLO el objeto del schema.`,
  { label: 'categorias', phase: 'Diseñar', schema: SCHEMA, effort: 'high' })
return r
