export const meta = {
  name: 'ronda5-jugar-personas-trazo',
  description: 'Ronda 5: agentes que JUEGAN cada juego metiéndose en cada persona (Alzheimer, baja visión/temblor, maestra, comprador) buscando lo que impide un producto perfecto',
  phases: [
    { title: 'Jugar y criticar' },
    { title: 'Sintetizar' },
  ],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para centros de día de mayores. En producción.
Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo
Python del backend: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo\\backend\\api\\.venv\\Scripts\\python.exe
Apps: apps/web (panel React integradora/admin), apps/tablet (Flutter: maestra + participante en kiosco), backend/api (FastAPI). El participante mayor juega en la TABLET (kiosco). La maestra opera en tablet; la integradora/admin en el panel web.
Motor data-driven: 8 plantillas, ~104 actividades en backend/api/app/data/catalogo.json. Generadores en app/templates/tipos.py; autocorrección en services/correccion.py. Cada widget de juego está en apps/tablet/lib/widgets/*.dart y la pantalla del participante en apps/tablet/lib/screens/participante_screen.dart.
Las 8 plantillas: trazo (seguir una línea con el dedo), seleccion_multiple (elegir imagen o palabra), memoria_visual (memorizar y reconocer), busqueda_visual (encontrar todos los X), secuencia_ordenar (ordenar pasos, AHORA por toque con flechas), conteo_comparacion (contar / cuál tiene más o menos), arrastrar_posicion (llevar cada cosa a su zona por toque), manejo_cantidad (dinero: reunir/monedas justas/vuelta; y reloj).

CÓMO "JUGAR" DE VERDAD (no te limites a leer): trabaja EN LOCAL, nunca contra producción, sin credenciales de prod. Genera instancias REALES de las actividades importando los generadores o levantando el backend en proceso (mira backend/api/tests/conftest.py y app/templates/tipos.py). Para CADA actividad relevante: genera la instancia a niveles bajo/medio/alto, MIRA lo que se renderiza (opciones, imágenes, textos, cantidades), lee el widget Flutter que la pinta para saber qué ve y toca el mayor, y comprueba con correccion.py qué respuesta cuenta como logrado/parcial/no_logrado. Luego NARRA el playthrough desde la persona que te toca y anota todo lo que rompa la sensación de producto perfecto.

Persona por defecto salvo que tu lente diga otra: MAYOR CON ALZHEIMER LEVE-MODERADO jugando. Piensa como esa persona: memoria de trabajo corta (olvida la consigna a media tarea), se pierde con pasos múltiples, se frustra y abandona si no entiende, no siempre lee bien, puede tocar sin querer, necesita saber en todo momento "qué hago" y "voy bien". ¿La actividad tiene sentido para su vida? ¿La instrucción se entiende sin que nadie la lea? ¿Se puede terminar sin ayuda? ¿Se siente digna, no infantil ni humillante?

Rondas 1-4b YA arregladas (NO re-reportes): scoring dinero/conteo; '¿cuál tiene menos?'; catálogo en prod; mensajes de error crudos; paciente sin plan -> pantalla 'sin actividades'; errores de transporte tablet; vocabulario emparejar (código/Tablets); invariante 'una sola sala en vivo'; gráfica/informe sobre desempeño (no precision); cola offline descarta 4xx; token oculto en listado; secuencia_ordenar por TOQUE (flechas arriba/abajo); háptico en selecciones; 'quitar última moneda' en dinero; contraste botones/nombre a sageDark; icono error visible; guantes->frío; 'Adivina por la pista' instrucción corregida; monedas_justas dice 'monedas y billetes' si hay billetes; 'atascado' medido desde inicio de la actividad en curso, umbral 90s. Céntrate en lo que QUEDA para que sea perfecto.`

const SCHEMA_JUEGO = {
  type: 'object',
  additionalProperties: false,
  required: ['area', 'resumen', 'bugs', 'pulido', 'mejoras'],
  properties: {
    area: { type: 'string' },
    resumen: { type: 'string', description: 'Qué jugaste/probaste (actividades y niveles), desde qué persona, y el veredicto' },
    bugs: {
      type: 'array',
      description: 'Defectos CONFIRMADOS reproducidos (irresoluble, corrección mal, crash, dato incorrecto). Vacío si no hay.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severidad', 'titulo', 'detalle', 'archivo', 'correccion'],
        properties: {
          severidad: { type: 'string', enum: ['alta', 'media', 'baja'] },
          titulo: { type: 'string' },
          detalle: { type: 'string', description: 'Cómo se reproduce y qué ve/sufre la persona' },
          archivo: { type: 'string' },
          correccion: { type: 'string' },
        },
      },
    },
    pulido: {
      type: 'array',
      description: 'Detalles que ROMPEN la sensación de producto perfecto (confuso para un mayor, feo, incoherente, infantil, texto raro, feedback pobre) aunque no sea un bug funcional.',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['impacto', 'titulo', 'detalle', 'archivo', 'correccion'],
        properties: {
          impacto: { type: 'string', enum: ['alto', 'medio', 'bajo'] },
          titulo: { type: 'string' },
          detalle: { type: 'string' },
          archivo: { type: 'string' },
          correccion: { type: 'string' },
        },
      },
    },
    mejoras: {
      type: 'array',
      description: 'Ideas para elevar la experiencia o el valor (más allá de arreglar).',
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
    label: 'juega-trazo-y-seleccion',
    prompt: `${CONTEXTO}\n\nTU LENTE: JUEGA a fondo, como mayor con Alzheimer, TODAS las actividades de las plantillas 'trazo' (seguir la línea con el dedo) y 'seleccion_multiple' (elegir imagen/palabra). Genera instancias reales a los 3 niveles, mira el guide_path/opciones/imágenes y el widget (trazo_widget.dart, seleccion_multiple_widget.dart), y verifica: ¿se entiende sin que nadie lea?, ¿es resoluble y la corrección cuadra?, ¿las imágenes/palabras son claras y sin ambigüedad?, ¿el trazo es alcanzable con el dedo (no demasiado fino/estrecho)?, ¿la dificultad escala?, ¿se siente digno? Reporta bugs, pulido y mejoras. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'juega-memoria-y-busqueda',
    prompt: `${CONTEXTO}\n\nTU LENTE: JUEGA como mayor con Alzheimer TODAS las actividades de 'memoria_visual' (memorizar y luego reconocer) y 'busqueda_visual' (encontrar todos los X). Son las más exigentes para esta población. Genera instancias a los 3 niveles, mira tiempos de memorización, nº de items, distractores y el widget (memoria_visual_widget.dart, busqueda_visual_widget.dart). Evalúa: ¿el tiempo de memorización es humano?, ¿la carga (nº de figuras) es asumible o abrumadora?, ¿se entiende la transición memorizar→responder sin perderse?, ¿los distractores son justos?, ¿sabe cuándo ha terminado de buscar? Reporta bugs, pulido y mejoras. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'juega-conteo-y-dinero',
    prompt: `${CONTEXTO}\n\nTU LENTE: JUEGA como mayor con Alzheimer TODAS las actividades de 'conteo_comparacion' (contar / cuál tiene más o menos) y 'manejo_cantidad' (dinero: reunir/monedas justas/vuelta; y reloj). Son las de más carga numérica. Genera instancias a los 3 niveles y mira los widgets (conteo_comparacion_widget.dart, manejo_cantidad_widget.dart) y correccion.py. Evalúa: ¿la consigna por modo es clara y coherente con lo que se muestra?, ¿componer un importe con monedas/billetes es factible con temblor?, ¿el reloj es legible y la respuesta esperada intuitiva?, ¿contar/comparar es inequívoco (grupos claros, sin ambigüedad del extremo)?, ¿la corrección acepta lo razonable? Reporta bugs, pulido y mejoras. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'juega-ordenar-y-arrastrar',
    prompt: `${CONTEXTO}\n\nTU LENTE: JUEGA como mayor con Alzheimer y como mayor con TEMBLOR TODAS las actividades de 'secuencia_ordenar' (ordenar pasos, ahora por toque con flechas arriba/abajo) y 'arrastrar_posicion' (llevar cada cosa a su zona, por toque). Genera instancias a los 3 niveles y mira los widgets (secuencia_ordenar_widget.dart —recién reescrito—, arrastrar_posicion_widget.dart) y correccion.py. Evalúa especialmente la NUEVA interacción por flechas: ¿es clara?, ¿cuántos toques cuesta ordenar (fatiga)?, ¿se ve qué se movió?, ¿el número de posición confunde?; y en arrastrar: ¿las zonas y piezas son inequívocas?, ¿la clasificación es culturalmente correcta?, ¿evalúa lo que dice? Reporta bugs, pulido y mejoras. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'persona-alzheimer-sesion-entera',
    prompt: `${CONTEXTO}\n\nTU LENTE: vive una SESIÓN ENTERA como un mayor con Alzheimer moderado, de principio a fin (no una actividad suelta): pantalla de elegir rol/identidad, confirmar "¿eres tú?", esperar a que empiece, encadenar varias actividades distintas, equivocarte, dudar, terminar la tanda, esperar, recibir otra tanda ("enviar más"), y salir. Lee participante_screen.dart y el flujo. Busca todo lo que confunda o angustie a esa persona: ¿sabe siempre qué tiene que hacer?, ¿entiende cuándo pasa a la siguiente y cuándo ha acabado?, ¿la espera le genera desamparo?, ¿el paso entre actividades es brusco?, ¿hay refuerzo positivo suficiente y digno (ni infantil ni frío)?, ¿puede recuperarse de un error sin ayuda?, ¿algo puede hacerle sentir tonta o perdida? Reporta bugs, pulido y mejoras centrados en la vivencia. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'persona-baja-vision-temblor',
    prompt: `${CONTEXTO}\n\nTU LENTE: recorre una muestra representativa de TODAS las plantillas como mayor con BAJA VISIÓN y TEMBLOR notable. Mira tamaños de objetivo táctil, tamaños/contraste de texto e imágenes, separación entre elementos (para no tocar el de al lado), tiempos, y feedback perceptible (visual+háptico). Lee theme.dart, participante_screen.dart y los widgets. Ya se subió el contraste de botones/nombre y se añadió háptico: verifica que basta y encuentra lo que aún queda pequeño, poco contrastado, demasiado junto o sin confirmación perceptible. Reporta bugs, pulido y mejoras. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'persona-maestra-operativa',
    prompt: `${CONTEXTO}\n\nTU LENTE: eres LA MAESTRA/integradora (no técnica) operando una sesión real con varios mayores a la vez, entre la tablet (abrir sala, seleccionar, iniciar, monitor en vivo, 'enviar más', cerrar) y el panel web (seguir en directo, cerrar sala, ver evolución/alertas/informe). Levanta el backend en local y recórrelo. Busca fricción operativa y todo lo que la haga dudar o perder el control del grupo: ¿sabe en todo momento quién va bien/mal/atascado?, ¿es fácil mandar más o cambiar el nivel a alguien?, ¿puede rescatar una sala si se equivoca?, ¿los textos y estados son claros para alguien no técnico?, ¿el panel y la tablet cuentan lo mismo? Reporta bugs, pulido y mejoras. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'comprador-exigente-vs-neuronup',
    prompt: `${CONTEXTO}\n\nTU LENTE: eres el DIRECTOR de la empresa de Laura (5 centros) evaluando si esto es un producto PERFECTO por el que pagar, comparado con NeuronUP. Recorre panel y experiencia con ojo de comprador exigente y de calidad de producto: coherencia visual y de vocabulario, sensación de acabado, informes presentables a familias/inspección, que nada 'huela a demo', que los números cuadren entre pantallas, que no haya callejones sin salida ni textos técnicos. Señala TODO lo que rompa la percepción de producto terminado y de pago (aunque sea pequeño: un texto, un estado vacío pobre, una incoherencia). Reporta bugs, pulido y mejoras priorizando lo que más daña la venta/confianza. Devuelve SOLO el objeto del schema.`,
  },
]

phase('Jugar y criticar')
const revisiones = (await parallel(
  LENTES.map((l) => () =>
    agent(l.prompt, { label: l.label, phase: 'Jugar y criticar', schema: SCHEMA_JUEGO }))
)).filter(Boolean)

phase('Sintetizar')
const SCHEMA_SINTESIS = {
  type: 'object',
  additionalProperties: false,
  required: ['veredicto_perfecto', 'por_que', 'roadmap'],
  properties: {
    veredicto_perfecto: {
      type: 'string',
      enum: ['si', 'casi', 'no'],
      description: '¿Está ya "perfecto" para subir? si / casi (quedan pocos retoques) / no (hay bloqueantes)',
    },
    por_que: { type: 'string', description: '3-6 frases honestas sobre el estado y qué falta para "perfecto"' },
    roadmap: {
      type: 'array',
      description: 'Todo (bugs+pulido+mejoras) deduplicado y priorizado',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['prioridad', 'tipo', 'titulo', 'por_que', 'donde'],
        properties: {
          prioridad: {
            type: 'string',
            enum: ['bloquea_perfecto', 'pulido_recomendado', 'mejora_futura'],
          },
          tipo: { type: 'string', enum: ['bug', 'pulido', 'mejora'] },
          titulo: { type: 'string' },
          por_que: { type: 'string' },
          donde: { type: 'string' },
        },
      },
    },
  },
}

const sintesis = await agent(
  `${CONTEXTO}\n\nEres el SINTETIZADOR de la ronda 5 (¿está el producto PERFECTO para subir?). Resultados JSON de 8 agentes que jugaron y criticaron desde distintas personas:\n\n${JSON.stringify(revisiones, null, 2)}\n\nDeduplica y PRIORIZA TODO en tres niveles: 'bloquea_perfecto' (hay que arreglarlo antes de decir que está perfecto), 'pulido_recomendado' (mejora claramente la sensación de acabado, hacer ya si es barato) y 'mejora_futura'. Sé exigente pero honesto: si algo no rompe la percepción de producto perfecto, no lo marques como bloqueante. Da un veredicto claro (si/casi/no) y explica qué falta. Devuelve SOLO el objeto del schema.`,
  { label: 'sintesis', phase: 'Sintetizar', schema: SCHEMA_SINTESIS })

return { revisiones, sintesis }
