export const meta = {
  name: 'qa-lote3-trazo',
  description: 'QA + usuario sobre Objetivos por paciente y las mejoras: supresión RGPD en panel, CSV con nombre, dejar sin puntuar, resumen conteo',
  phases: [{ title: 'Probar' }],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para mayores. Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo. Python: ...\\backend\\api\\.venv\\Scripts\\python.exe. EN LOCAL, sin credenciales de prod (backend en proceso vía httpx/ASGI, ver tests/conftest.py). Contexto en AGENTS.md. Roles: la integradora entra con integradora@trazo.local/trazo1234; el admin con admin@trazo.local/trazo1234.

LOTE 3 recién implementado (prueba SOLO esto):
1. OBJETIVOS por paciente (plan de intervención): modelo ObjetivoPaciente (tabla nueva), router app/routers/objetivos.py: GET/POST /usuarios/{id}/objetivos, PATCH/DELETE /objetivos/{id}. Cada objetivo = {bloque(área), descripcion, objetivo_desempeno 0..1}; la respuesta calcula situacion_actual (media de desempeño del área, excluyendo sin_valorar), cumple y n_valorados. Aislado por centro (usuario_del_centro). Panel: componente ObjetivosPaciente.tsx en la vista de evolución (UsuarioEvolucion), con barra objetivo-vs-actual y alta/baja.
2. Supresión RGPD en el PANEL: función suprimirUsuario + botón "Suprimir (RGPD)" SOLO para admin_centro en Pacientes.tsx, con confirmación escribiendo el alias exacto.
3. CSV individual con nombre real: /export/intentos.csv?...&incluir_nombre=true añade columna 'nombre' (solo export por persona); el botón de UsuarioEvolucion lo pide.
4. Bandeja de revisión: botón "Dejar sin puntuar" (PATCH resultado=sin_valorar devuelve el intento a la cola); resumenRespuesta de conteo lee la clave real 'respuesta'; el contador del menú se refresca por evento 'trazo:pendientes-cambiaron'.`

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['veredicto', 'resumen', 'problemas'],
  properties: {
    veredicto: { type: 'string', enum: ['funciona', 'funciona_con_reparos', 'roto'] },
    resumen: { type: 'string' },
    problemas: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      required: ['severidad', 'titulo', 'detalle', 'archivo'],
      properties: {
        severidad: { type: 'string', enum: ['alta', 'media', 'baja'] },
        titulo: { type: 'string' }, detalle: { type: 'string' }, archivo: { type: 'string' },
      } } },
  },
}

phase('Probar')
const [qa, usuario] = await parallel([
  () => agent(`${CONTEXTO}\n\nEres QA. Verifica en local: (1) Objetivos: crear/listar/editar/borrar; area inválida y objetivo fuera de [0,1] dan 422; situacion_actual sube tras marcar intentos logrados en esa área y 'cumple' se calcula bien; un centro ajeno recibe 403 al listar/borrar objetivos de otra persona. (2) Supresión RGPD por endpoint: integradora 403, admin 204 + anonimiza. (3) CSV con incluir_nombre=true añade columna 'nombre' con el nombre real cuando existe, y sin incluir_nombre no la añade; scoped por centro. (4) marcar_resultado acepta sin_valorar (devuelve a pendiente: reaparece en /pendientes). Corre 'pytest -q' y 'tsc --noEmit'. Reporta cualquier fallo con archivo:linea. Devuelve SOLO el objeto del schema.`,
    { label: 'qa', phase: 'Probar', schema: SCHEMA }),
  () => agent(`${CONTEXTO}\n\nEres INTEGRADORA/ADMIN no técnica y también el DIRECTOR evaluando el producto. Por lectura de código evalúa la EXPERIENCIA de Objetivos (ObjetivosPaciente.tsx en UsuarioEvolucion): ¿se entiende fijar una meta por área?, ¿la barra objetivo-vs-actual se lee de un vistazo (marca del objetivo, color según cumple)?, ¿el copy es claro y digno?, ¿aporta valor de 'plan de intervención' frente a un catálogo (NeuronUP)?, ¿falta algo para presentarlo a familia/inspección? Evalúa también la supresión RGPD en Pacientes.tsx (¿el doble paso escribiendo el alias es seguro y claro?, ¿el copy explica qué se borra y qué se conserva?, ¿bien que solo lo vea el admin?), el CSV con nombre, y el 'Dejar sin puntuar'. Señala fricciones y mejoras de producto. Devuelve SOLO el objeto del schema.`,
    { label: 'usuario', phase: 'Probar', schema: SCHEMA }),
])
return { qa, usuario }
