export const meta = {
  name: 'qa-lote2-trazo',
  description: 'QA + usuario sobre el lote 2: reloj/vuelta/lista-compra, export CSV, RGPD (rectificar/suprimir) y mejoras de la bandeja de revisión',
  phases: [{ title: 'Probar' }],
}

const CONTEXTO = `Trazo — SaaS de estimulación cognitiva para mayores. Repo: C:\\Users\\Saulo.Santacruz\\Desktop\\Trazo. Python: ...\\backend\\api\\.venv\\Scripts\\python.exe. Trabaja EN LOCAL, sin credenciales de producción (backend en proceso vía httpx/ASGI, ver tests/conftest.py; genera instancias con app/templates/tipos.py). Contexto en AGENTS.md.

LOTE 2 recién implementado (prueba SOLO esto):
1. Reloj: correccion.py da tolerancia +-1 hora cuando el minuto objetivo es >=45 (lectura "menos cuarto"); el minuto sí debe coincidir.
2. Vuelta (manejo_cantidad): el generador expone importe_c/importe_texto = la vuelta a devolver (objetivo visible); corrección sigue cuadrando total==vuelta.
3. "La lista de la compra" (arrastrar_posicion): 2 zonas (carro / fuera) con muestreo ESTRATIFICADO que garantiza al menos una pieza de cada zona (siempre hay decisión). Instrucción por defecto ya no dice "Arrastra".
4. Export CSV: GET /export/intentos.csv?centro_id=&usuario_final_id= (staff), columnas fecha;persona;area;actividad;resultado;con_ayuda, con BOM, scoped por centro y auditado. Panel: función descargarIntentosCsv + botón "Exportar datos (CSV)" en UsuarioEvolucion.
5. RGPD: PATCH /usuarios/{id} acepta nombre_real (fijar/actualizar/vaciar art.16, tabla DatosIdentificativos); DELETE /usuarios/{id} (solo admin_centro) anonimiza (borra DatosIdentificativos + Consentimientos, saca de salas, alias->"Persona suprimida", activo=False, audita) art.17.
6. Bandeja de revisión (Revisar.tsx): muestra qué respondió la persona (resumenRespuesta por plantilla), permite cambiar la decisión ya marcada (red de seguridad), colores distintos por opción, y contador en el menú (Layout).`

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
  () => agent(`${CONTEXTO}\n\nEres QA. Verifica el lote 2 probándolo en local: (a) reloj: genera casos con minuto>=45 y comprueba que leer la hora+1 con el minuto correcto da 'logrado', y que con minuto<45 sigue exigiendo hora exacta; minuto mal = no_logrado. (b) vuelta: la instancia trae importe_c=vuelta y la corrección da logrado cuando total==vuelta. (c) "La lista de la compra": 300 instancias por nivel -> SIEMPRE hay piezas de las 2 zonas; la corrección puntúa por colocar cada una en su zona. (d) CSV: ejerce GET /export/intentos.csv (200, content-type text/csv, cabecera, filas; 403 desde otro centro). (e) RGPD: PATCH nombre_real fija/borra en DatosIdentificativos; DELETE por integradora=403, por admin=204 y anonimiza. Corre 'pytest -q' y 'tsc --noEmit'. Reporta cualquier fallo con archivo. Devuelve SOLO el objeto del schema.`,
    { label: 'qa', phase: 'Probar', schema: SCHEMA }),
  () => agent(`${CONTEXTO}\n\nEres INTEGRADORA/ADMIN no técnica usando el panel, y también un MAYOR jugando. Por lectura de código evalúa la EXPERIENCIA: (a) el botón "Exportar datos (CSV)" en UsuarioEvolucion: ¿se entiende, el archivo se abre bien en Excel español (separador ; y BOM), las columnas son útiles para una memoria/historia clínica? (b) supresión RGPD: ¿es seguro que solo el admin borre?, ¿queda claro que anonimiza y conserva estadística?, ¿falta confirmación en el panel (hoy solo hay endpoint)? (c) reloj/vuelta/lista de la compra como mayor: ¿son ahora más justas y claras? ¿la vuelta con objetivo visible se entiende? ¿la lista de la compra con 2 zonas tiene sentido cultural? (d) bandeja: ¿el resumen de "qué respondió" ayuda a decidir?, ¿el contador del menú se ve?, ¿poder cambiar la decisión da tranquilidad? Señala fricciones/mejoras. Devuelve SOLO el objeto del schema.`,
    { label: 'usuario', phase: 'Probar', schema: SCHEMA }),
])
return { qa, usuario }
