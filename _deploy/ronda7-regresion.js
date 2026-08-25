export const meta = {
  name: 'ronda7-regresion-trazo',
  description: 'Repaso de regresión tras 8 iteraciones autónomas: confirmar que todo sigue sólido (backend/E2E + panel/tablet), sin regresiones ni roturas de aislamiento',
  phases: [{ title: 'Repasar' }],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para mayores. Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo. Python backend: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo\\backend\\api\\.venv\\Scripts\\python.exe. EN LOCAL, sin credenciales de producción (backend en proceso vía httpx/ASGI, ver tests/conftest.py). Contexto en AGENTS.md.

Esta noche se hicieron 8 iteraciones autónomas de mejora. TU MISIÓN: repaso de REGRESIÓN — confirmar que nada se rompió y que el producto está sólido para una prueba definitiva con un centro real. NO añadas features; busca ROTURAS, incoherencias o principios clínicos/aislamiento vulnerados que las mejoras hayan podido introducir. Reporta solo regresiones/problemas reales.

Cambios de esta noche (para que sepas dónde mirar):
- Backend: puntuación por orden relativo en secuencia_ordenar; suma acotada a <=15; dinero escala por nivel (_rango_importe_c); catálogo "El intruso" en positivo y emociones sin 'miedo'; endpoint GET /centros/{id}/resumen-areas; endpoint GET /pendientes + PATCH /intentos/{id}/resultado acepta sin_valorar; objetivos por paciente (ObjetivoPaciente, /usuarios/{id}/objetivos, /objetivos/{id}); export CSV; RGPD (PATCH nombre_real, DELETE /usuarios/{id} anonimiza); pos espacial en zonas de "Poner la mesa"/"Arriba o abajo".
- Panel web: páginas Revisar (cola sin_valorar), Objetivos, informe familia por áreas, dashboard por áreas, "le ayudé" en monitor en vivo, botones CSV y supresión RGPD.
- Tablet: layout espacial en arrastrar_posicion; audio TTS (flutter_tts); más aire entre celdas; y todo lo previo (dinero céntimos, reloj sin default, etc.).`

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['veredicto', 'resumen', 'regresiones'],
  properties: {
    veredicto: { type: 'string', enum: ['solido', 'solido_con_reparos', 'roto'] },
    resumen: { type: 'string' },
    regresiones: {
      type: 'array',
      description: 'Solo problemas/regresiones reales (vacío si todo sólido)',
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

phase('Repasar')
const [backend, frontend] = await parallel([
  () => agent(`${CONTEXTO}\n\nLENTE BACKEND + E2E + MEDICIÓN. (1) Corre 'pytest -q' (debe pasar ~205) y 'pytest tests/test_calibracion_catalogo.py -q' (105). (2) Recorre E2E en local el flujo completo: super-admin crea centro -> admin crea maestra -> maestra crea paciente + objetivo + plan -> abre sala, inicia -> registra intentos de varias plantillas (bien/mal/sin_valorar) -> revisa sin_valorar (cola /pendientes + PATCH resultado, incl. devolver a sin_valorar) -> mira evolución, alertas, /centros/{id}/resumen-areas, export CSV, objetivos con situacion_actual, informe. (3) MULTI-TENANT: confirma que TODOS los endpoints nuevos (pendientes, objetivos, resumen-areas, export csv, DELETE usuarios) siguen aislados por centro (403 al ajeno) y que el intento nace sin_valorar y sin_valorar != no_logrado (principio clínico). (4) Verifica que las mejoras de scoring no rompen: la respuesta CORRECTA de cada plantilla sigue puntuando 'logrado' (fuzz del catálogo); memoria nunca se gana tocando todo; comparaciones con margen>=2; suma<=15; dinero escala. Reporta SOLO regresiones. Devuelve SOLO el objeto del schema.`,
    { label: 'backend-e2e', phase: 'Repasar', schema: SCHEMA }),
  () => agent(`${CONTEXTO}\n\nLENTE PANEL + TABLET (UX y compilación). (1) 'npx tsc --noEmit' en apps/web limpio; 'flutter analyze lib' en apps/tablet limpio. (2) Panel: revisa por lectura de código que las páginas/nuevos componentes no tienen fugas de estado ni llamadas rotas: Revisar.tsx (cola + resumenRespuesta + dejar sin puntuar + contador menú), ObjetivosPaciente.tsx (crear/editar/borrar, barra), InformeFamilia.tsx (secciones objetivos + por áreas, filtro n>=2), Dashboard.tsx (resumen-areas), SesionLive.tsx ('le ayudé' con override reconciliado, Terminó/Ronda/X de Y), Pacientes.tsx (supresión RGPD admin), UsuarioEvolucion.tsx (CSV). ¿Algún import roto, key duplicada, o estado que quede inconsistente tras recargar/pollear? (3) Tablet: TTS (tts.dart best-effort, no rompe si no hay voz; se para en dispose), layout espacial arrastrar_posicion (sin solape, botón ✕ accesible), más aire entre celdas (no descuadra la rejilla ni encoge de más los objetos). ¿Alguna actividad quedó rota por los cambios? Reporta SOLO regresiones. Devuelve SOLO el objeto del schema.`,
    { label: 'panel-tablet', phase: 'Repasar', schema: SCHEMA }),
])
return { backend, frontend }
