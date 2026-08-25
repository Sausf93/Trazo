export const meta = {
  name: 'ronda6-verificacion-trazo',
  description: 'Verificación fresca: confirmar que los 5 bloqueantes de round 5 están resueltos en el código ACTUAL, y buscar cualquier resto',
  phases: [{ title: 'Verificar' }],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para mayores. Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo. Python: ...\\backend\\api\\.venv\\Scripts\\python.exe. EN LOCAL, sin credenciales de producción (backend en proceso vía httpx/ASGI; genera instancias con app/templates/tipos.py y registry.py). Contexto en AGENTS.md.

Una ronda anterior (round 5) reportó 5 BLOQUEANTES. Se han ido aplicando arreglos (por el asistente y por un linter). TU MISIÓN es VERIFICAR sobre el CÓDIGO ACTUAL si cada uno está resuelto, jugando/reproduciendo de verdad, y reportar SOLO lo que AÚN falle o cualquier problema nuevo. No des por bueno nada sin comprobarlo en el código/ejecución actual.`

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['veredicto', 'resumen', 'pendientes'],
  properties: {
    veredicto: { type: 'string', enum: ['todo_resuelto', 'quedan_cosas', 'roto'] },
    resumen: { type: 'string' },
    pendientes: {
      type: 'array',
      description: 'Solo lo que AÚN falla o problemas nuevos (vacío si todo resuelto)',
      items: {
        type: 'object', additionalProperties: false,
        required: ['severidad', 'titulo', 'detalle', 'archivo'],
        properties: {
          severidad: { type: 'string', enum: ['alta', 'media', 'baja'] },
          titulo: { type: 'string' }, detalle: { type: 'string' }, archivo: { type: 'string' },
        },
      },
    },
  },
}

const LENTES = [
  {
    label: 'verifica-medicion',
    prompt: `${CONTEXTO}\n\nVERIFICA estos bloqueantes de MEDICIÓN generando instancias reales a los 3 niveles y pasándolas por correccion.py: (1) memoria_visual: ¿la rejilla SIEMPRE tiene >=1 distractor (n_rejilla>n_figuras) y n a recordar <=5 en las 11 actividades? ¿Tocar TODA la rejilla ya NO da 'logrado'? (2) reloj: ¿el widget ya NO emite hora por defecto sin tocar (manejo_cantidad_widget.dart) — es decir, si no se toca selector, no van hora_elegida/minuto_elegido y el backend lo deja sin_valorar? (3) 'La lista de la compra': ¿tiene 2 zonas y el muestreo garantiza ambas? Corre pytest -q (incluye test_calibracion_catalogo). Reporta SOLO lo que aún falle. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'verifica-dinero-series',
    prompt: `${CONTEXTO}\n\nVERIFICA (jugando/leyendo el código actual): (1) DINERO: en manejo_cantidad_widget.dart el acumulado se lleva en CÉNTIMOS enteros (_acumuladoC) y se formatea con COMA y 2 decimales fijos, sin ruido de coma flotante ni punto; ¿el rótulo 'Llevas' es coherente con 'Tienes que reunir'? ¿El nivel del paciente ya cambia el importe (bajo<medio<alto)? (2) 'Seguir la serie' y demás seleccion_multiple: ¿el widget pinta la CONSIGNA (instruccion) cuando difiere del enunciado, de modo que las series ya muestran la pregunta? (3) 'vuelta': ¿muestra el objetivo visible? Reporta SOLO lo que aún falle o chirríe. Devuelve SOLO el objeto del schema.`,
  },
  {
    label: 'verifica-panel-y-accesibilidad',
    prompt: `${CONTEXTO}\n\nVERIFICA: (1) PANEL en vivo (apps/web SesionLive.tsx + types.ts): ¿FichaViva ya trae terminado/ronda/pos_actual/total_actual y el panel muestra 'Terminó', ronda y 'X de Y'? ¿El backend excluye a 'terminado' del cálculo de atascado (sesiones.py)? ¿El texto de vacío ya no dice solo 'en grupo'? (2) ACCESIBILIDAD tablet: ¿la guía de 'trazo' ya tiene contraste suficiente (trazo_widget.dart, ya no 0xFFDCD3BE)? ¿hay HapticFeedback en los teclados de conteo, en los selectores del reloj y en arrastrar_posicion? ¿busqueda_visual muestra progreso/'encontradas'? Corre 'tsc --noEmit' en apps/web. Reporta SOLO lo que aún falle. Devuelve SOLO el objeto del schema.`,
  },
]

phase('Verificar')
const resultados = (await parallel(
  LENTES.map((l) => () => agent(l.prompt, { label: l.label, phase: 'Verificar', schema: SCHEMA }))
)).filter(Boolean)
return { resultados }
