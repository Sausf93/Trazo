# Backlog del repaso multi-agente (2026-08-18)

## [CRITICO] El botón MAESTRA se salta el login en tablet emparejada: la maestra no puede abrir sala (No autorizado)
- donde: apps/tablet/lib/screens/rol_screen.dart:41 (_irMaestra); apps/tablet/lib/api/client.dart:74 (getter autenticado) y :475
- _irMaestra decide mostrar login con `ApiClient.instance.autenticado`, pero ese getter es `_token != null || _deviceToken != null`. Con emparejamiento-primero obligatorio, _deviceToken SIEMPRE está puesto en la pantalla de roles, así que MAESTRA nunca abre LoginScreen y entra sin sesión de staff; luego 'Abrir sala' (POST /sesiones exige Bearer de staff) devuelve 401 -> 'No autorizado' sin camino al login. Añadir un getter solo-staff `bool get staffAutenticado => _token != null;` y usarlo en _irMaestra en vez de `autenticado`; dejar `autenticado` (device O staff) solo para lógica de kiosco/cabeceras.

## [MEDIO] Persona nueva nace sin plan: la tablet del mayor queda vacía ('Todavía no hay actividades') sin aviso
- donde: backend/api/app/routers/usuarios.py:59; backend/api/app/services/cola.py:194-228; apps/web/src/pages/PlanEditor.tsx:181-185; apps/tablet/lib/screens/maestra_screen.dart:576-689; apps/tablet/lib/screens/participante_screen.dart:1131-1159
- Al dar de alta a una persona no se crea ninguna línea de plan, y en el arranque el 'Plan estándar para todos' es opcional; si la maestra abre sala sin aplicarlo, esa persona va con config_json=null y cola vacía -> el mayor (usuario más frágil) llega a un callejón sin salida. Sembrar un plan por defecto razonable al crear la persona (2-3 áreas nivel bajo) o, mínimo: (a) avisar en ficha/lista 'Sin plan: en la tablet no le tocará ninguna actividad' con enlace a planificar; (b) al abrir sala, detectar participantes seleccionados sin config ni plan permanente y avisar (no bloqueante) o aplicarles el plan estándar; (c) ofrecer 'Empezar con un plan sugerido' en el estado vacío del PlanEditor.

## [MEDIO] La vista previa 'antes de guardar' muestra el plan viejo, no el que estás montando
- donde: apps/web/src/pages/PlanEditor.tsx:372-383 y :240; apps/web/src/api/endpoints.ts:250-259; backend/api/app/services/cola.py:183-192
- El bloque ColaPreview promete 'Comprueba, antes de guardar, las actividades que la tablet le irá pidiendo', pero obtenerCola() llama a GET /usuarios/{id}/cola, que resuelve desde las PlanPacienteLinea YA GUARDADAS, no desde el estado 'lineas' en memoria: si añades áreas y pulsas 'Ver qué le tocará' sin guardar, ves la cola anterior (o 'Sin actividades' en persona nueva). Además no se refresca sola tras guardar (useAsync depende de [usuarioId, ver]). Recalcular la previa en cliente desde 'lineas' (mismo algoritmo que cola.py) o cambiar el texto a 'Guarda para ver qué le tocará' forzando cola.reload() al guardar. Mínimo: avisar cuando hay cambios sin guardar y refrescar automáticamente tras guardar.

## [MEDIO] Los cambios del plan se pierden al salir sin guardar, sin ningún aviso
- donde: apps/web/src/pages/PlanEditor.tsx:144-149 y :104-138
- Todo el estado del plan vive en 'lineas' (useState) y solo se persiste al pulsar 'Guardar plan'. Si la psicóloga edita áreas/niveles y pulsa 'Volver a la ficha' o navega sin guardar, pierde el trabajo en silencio. Marcar estado 'sucio' cuando 'lineas' difiere del plan cargado y pedir confirmación antes de navegar/cerrar (guard de router + beforeunload); resaltar 'Guardar plan' cuando haya cambios pendientes.

## [MEDIO] No se puede copiar un plan a otras personas ni usar plantillas de plan (cuello de botella a escala)
- donde: apps/web/src/pages/PlanEditor.tsx (editor completo); apps/web/src/api/endpoints.ts:230-247
- El único camino es construir el plan línea a línea para cada persona; en centros de día muchas comparten un plan casi idéntico y con el cliente ancla (5 centros) repetirlo es cuello de botella real. Añadir 'Copiar este plan a otras personas' (selección múltiple) y/o guardar plantillas de plan con nombre para aplicarlas de golpe. Backend: endpoint que replique las líneas a una lista de usuario_final_id del MISMO centro (respetar aislamiento multi-tenant).

## [MEDIO] El Rol elegido al emparejar en el panel ya no hace nada, y su texto contradice a la tablet
- donde: apps/web/src/pages/Dispositivos.tsx:178-208 (form Emparejar); apps/tablet/lib/screens/rol_screen.dart:192-232
- El panel obliga a elegir 'Maestra' o 'Participante' al emparejar y lo describe como consecuente, pero con el modelo nuevo la misma tablet elige rol en cada uso (rol_screen muestra siempre las dos tarjetas; DispositivoYo.rol se guarda pero no gatea nada). El ajuste está muerto y su descripción es falsa (la responsable puede creer que una tablet queda 'bloqueada' a participante). Quitar el selector de Rol del formulario (o dejarlo informativo) y reescribir el texto: 'Cada tablet se empareja una vez; luego, en la tablet, se elige en cada uso si es maestra o participante'. Si se quiere conservar como restricción, la tablet debería respetar DispositivoYo.rol y ocultar la tarjeta que no corresponda.

## [MENOR] Objetivos de intervención desconectados del editor de plan
- donde: apps/web/src/components/ObjetivosPaciente.tsx (montado en UsuarioEvolucion.tsx:360); apps/web/src/pages/PlanEditor.tsx
- Al planificar lo natural es fijar la meta de un área al elegir trabajarla, pero los objetivos solo aparecen al fondo de Evolución, sin enlace con el PlanEditor: fácil descoordinar (área con plan sin objetivo, u objetivo de un área que no está en el plan). Mostrar/enlazar los objetivos por área dentro del PlanEditor (o enlace visible 'Fijar metas de estas áreas') y prellenar el objetivo para áreas recién añadidas.

## [MENOR] La previa muestra 'De dónde sale' con términos crudos (dominio/ejercicio) incoherentes con el vocabulario digno
- donde: apps/web/src/pages/PlanEditor.tsx:415 y :424
- La columna 'De dónde sale' pinta el valor crudo del backend ('dominio', 'ejercicio') en vez de la etiqueta digna que ya existe (TIPO_LINEA_LABEL en vocab.ts:83-86, donde 'dominio' se muestra como 'Trabajar un área'). Mapear it.origen a etiqueta legible ('Trabajar un área' / 'Actividad concreta' / 'Sesión de grupo') reutilizando TIPO_LINEA_LABEL.

## [MENOR] Paso 3 del onboarding nunca se marca y el contador cuenta líneas desactivadas
- donde: apps/web/src/pages/Dashboard.tsx:36 y :63-65; apps/web/src/pages/PlanEditor.tsx:176-178 vs :359-366
- (a) El paso 3 'Planifica sus actividades' tiene hecho={false} fijo y el onboarding desaparece en cuanto hay personas y tablets, así que nunca se marca aunque planifiques: calcular hecho comprobando si existe algún plan, o retirar el paso. (b) El contador '{lineas.length} en el plan' incluye líneas con 'Incluir en el plan' desactivado (activo=false) que NO entran en la cola: contar solo las activas o etiquetar 'N líneas (M activas)'.

## [MENOR] Quitar emparejamiento en la tablet desvincula al instante, sin confirmación
- donde: apps/tablet/lib/screens/rol_screen.dart:244-246 (_quitarEmparejamiento) vs apps/web/src/pages/Dispositivos.tsx:89-95
- El botón 'Quitar' desempareja de inmediato sin diálogo; un toque accidental deja la tablet sin emparejar y obliga a volver al panel a generar un código nuevo. La acción equivalente en el panel ('Desvincular') sí pide confirmación. Añadir un AlertDialog de confirmación en _quitarEmparejamiento.

## [MENOR] Comentario obsoleto en Layout: dice que Dispositivos está fuera del menú, pero 'Tablets' sí está
- donde: apps/web/src/components/Layout.tsx:9-11 (comentario) vs :15 (NAV con /dispositivos como 'Tablets')
- El comentario afirma que 'Dispositivos se dejan fuera para no recargar', pero NAV incluye {to:'/dispositivos', label:'Tablets'} (añadido en el último commit). No afecta al usuario pero despista al leer. Actualizar el comentario para reflejar que 'Tablets' ya está en el menú y solo 'Ejercicios' queda fuera del día a día.

