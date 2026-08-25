# Backlog del panel de especialistas (2026-08-18)

## Temas transversales
- Audio que acompaña TODOS los pasos, no solo la consigna: confirmación de identidad, guía de acción de cada fase, opciones y refuerzo/cierre — el punto más repetido (baja visión, Alzheimer, terapeuta y comercial).
- 'Nunca atrapado' / salida digna sin PIN: soltar identidad equivocada, pedir ayuda en vivo, no dejar spinners sin fin (baja visión, Alzheimer, comercial).
- Capa de dirección y valor de negocio que hoy no existe: uso/adherencia, informe de centro y cuadro de mando multi-centro — es lo que decide la renovación y la venta de cadena frente a NeuronUP (dirección, comercial).
- El backend ya lo soporta pero la UI no lo usa: rango de fechas en evolución/informe y flujo de consentimiento RGPD — quick wins de alto valor (dirección, comercial).
- Coherencia entre el motor clínico y lo que ve la familia: tendencia, etiquetas y la ayuda que no debe prometerse en la línea; el documento entregado no puede contradecir (ni ser más alarmista que) el veredicto del panel (neuropsicólogo, familiar).
- El centro como emisor visible del informe, no Trazo: nombre y marca del centro-cliente ante familias e inspección (dirección, comercial, familiar).
- Diferenciadores frente a NeuronUP accionables sobre el código actual: audio digno para el mayor, orientación a la realidad, informes con marca del centro y la filosofía de medición sin_valorar/autocorrección — todo sin tocar los principios clínicos ni el aislamiento multi-tenant.

## Backlog priorizado (30)

### #1 · Confirmación de identidad hablada y reconocible sin leer [QUICK-WIN]
- area: tablet | impacto: alto | esfuerzo: bajo | roles: Usuario baja visión, Usuario Alzheimer
- El diálogo '¿Eres tú, X?' (participante_screen.dart:259-292) es mudo y sus dos botones se leen casi igual de lejos; es justo el paso donde un error manda las mediciones a otra ficha. Al abrir el diálogo, llamar a Tts.hablar('¿Eres tú, <alias>?'), añadir icono de altavoz que lo repita, y reforzar los botones con icono grande (persona/equis) para distinguirlos por forma, no por texto.
- archivos: apps/tablet/lib/screens/participante_screen.dart

### #2 · Ordenar el monitor: quien necesita ayuda, primero [QUICK-WIN]
- area: tablet | impacto: alto | esfuerzo: bajo | roles: Integradora
- Las fichas se pintan en el orden del backend, así que la coral 'Atascado' puede caer en cualquier celda y la integradora tiene que barrer todo el grid con la vista. Ordenar la lista de fichas en cliente (tablet y web) por prioridad derivada de los flags que ya llegan: primero 'atascado', luego trabajando/sin_valorar, al final 'terminado'. Sin cambios de backend.
- archivos: apps/tablet/lib/screens/maestra_screen.dart, apps/web/src/pages/SesionLive.tsx

### #3 · Aviso de desconexión en el monitor de la tablet [QUICK-WIN]
- area: tablet | impacto: alto | esfuerzo: bajo | roles: Integradora
- El monitor de la tablet hace polling cada 3s y en modo silencioso se traga los errores (maestra_screen.dart:1000-1014): si cae el wifi, la maestra ve datos congelados y cree que todo va bien. Guardar la hora del último poll con éxito y los fallos consecutivos; mostrar 'Actualizado hh:mm:ss' y, tras 2-3 fallos, franja 'Sin conexión: reintentando…', reutilizando el patrón que ya tiene la versión web.
- archivos: apps/tablet/lib/screens/maestra_screen.dart

### #4 · Al finalizar, avisar si hay personas aún trabajando [QUICK-WIN]
- area: tablet | impacto: alto | esfuerzo: bajo | roles: Integradora
- 'Finalizar sesión' solo pregunta '¿Terminamos la sesión de todos?' sin mirar el estado (maestra_screen.dart:1028-1044) y cerrar corta el trabajo en seco. Contar las fichas con terminado==false y, si hay alguna, cambiar el texto a 'Todavía hay N personas trabajando. ¿Seguro que finalizas para todos?'. No bloquea, solo protege del cierre accidental.
- archivos: apps/tablet/lib/screens/maestra_screen.dart

### #5 · Refuerzo, felicitación y cierre hablados; fin de tanda sereno [QUICK-WIN]
- area: tablet | impacto: alto | esfuerzo: bajo | roles: Usuario baja visión, Usuario Alzheimer, Comercial
- Los overlays '¡Muy bien!', '¡Seguimos!' y la pantalla _Terminado son mudos (solo háptico, participante_screen.dart:95, 247, 465, 1016-1055): el mayor termina su esfuerzo y no oye que lo hizo bien. Hablar el mensaje en _mostrarPaso y el saludo con nombre en _Terminado. Además, sustituir el spinner indefinido 'Espera un momento…' por un reposo cerrado y digno ('Muy bien, X. Ya has terminado. Puedes descansar.'), manteniendo el polling por si llega otra tanda.
- archivos: apps/tablet/lib/screens/participante_screen.dart

### #6 · En memoria, poder 'volver a mirar' las figuras [QUICK-WIN]
- area: tablet | impacto: alto | esfuerzo: bajo | roles: Usuario Alzheimer
- _terminarMemorizacion (memoria_visual_widget.dart:105-113) es irreversible: al pulsar 'Ya lo recuerdo' no hay vuelta atrás y una persona con Alzheimer puede quedar bloqueada sin poder repasar. Añadir en la vista de selección un botón sereno 'Volver a mirar' que reponga la memorización. Como no se penaliza la lentitud (principio de Laura), no hace falta limitarlo; el intento sigue naciendo sin_valorar.
- archivos: apps/tablet/lib/widgets/memoria_visual_widget.dart

### #7 · Informe a la familia: humano, correcto y que no asuste [QUICK-WIN]
- area: contenido | impacto: alto | esfuerzo: bajo | roles: Familiar, Neuropsicólogo
- Un solo paso sobre InformeFamilia.tsx que corrige varias fricciones citadas por la familia: (1) abrir con una frase cálida en lenguaje llano derivada del mismo Veredicto del panel, antes de la gráfica; (2) corregir 'Sesiones: N' (que en realidad son intentos/actividades) a 'Actividades' y la leyenda 'cada punto es una actividad'; (3) cuando la tendencia baje, repetir el matiz de causas ajenas a lo cognitivo (vista, oído, un día malo) en un recuadro visible junto al bloque, no solo al pie en letra pequeña; (4) añadir un destacado positivo por área ('donde mejor se desenvuelve es en…'); (5) objetivos no cumplidos en tono de proceso y color ámbar, no rojo con 'por debajo'; (6) una sola cifra de desempeño explicada en llano en vez de dos porcentajes rivales, y leyenda de la gráfica que no atribuya a la línea lo que no mide.
- archivos: apps/web/src/components/InformeFamilia.tsx, apps/web/src/pages/UsuarioEvolucion.tsx

### #8 · Selector de periodo en Evolución e Informe (el backend ya lo soporta) [QUICK-WIN]
- area: panel | impacto: alto | esfuerzo: bajo | roles: Dirección, Comercial
- evolucion.py:159-166 ya acepta 'desde'/'hasta', pero UsuarioEvolucion.tsx:33-36 nunca los pasa, así que el informe a familia siempre usa todo el histórico y no se puede acotar 'este trimestre' o 'desde el ingreso'. Añadir un selector (último mes/trimestre/año/personalizado) que se propague a evolucionUsuario, al CSV y al InformeFamilia. Coste bajísimo, sube mucho la credibilidad del entregable en reuniones.
- archivos: apps/web/src/pages/UsuarioEvolucion.tsx, apps/web/src/api/endpoints.ts, apps/web/src/components/InformeFamilia.tsx

### #9 · Dinero y reloj con resultado 'parcial'
- area: clínico | impacto: medio | esfuerzo: bajo | roles: Neuropsicólogo
- manejo_cantidad corrige todo o nada (correccion.py:188, 203-208): componer 2,40€ en vez de 2,45€ puntúa igual que poner 10€, y acertar la hora fallando el minuto es indistinguible de no tener idea, mientras el resto de plantillas gradúan con _grada(). Introducir 'parcial' por cercanía al importe / nº de monedas y por acertar hora pero no minuto (o viceversa). Mejora la sensibilidad de la señal en cálculo y manejo temporal sin castigar.
- archivos: backend/api/app/services/correccion.py

### #10 · Restablecer contraseña del equipo desde el panel
- area: backend | impacto: medio | esfuerzo: bajo | roles: Dirección
- El PATCH de staff solo cambia nombre y activo (staff.py:76-79); si una maestra olvida su clave, el admin no puede resolverlo y hoy dependería de acceso directo a BD. Añadir reseteo de contraseña por el admin del centro (acotado a su centro_id, reutilizando hash_password) y un botón 'Restablecer contraseña' en Equipo. Elimina una fricción operativa que genera tickets y desconfianza.
- archivos: backend/api/app/routers/staff.py, apps/web/src/pages/Equipo.tsx

### #11 · TTS por fase y botón 'Escuchar' que repite la consigna vigente
- area: tablet | impacto: alto | esfuerzo: medio | roles: Usuario baja visión, Usuario Alzheimer, Comercial
- La consigna solo se lee al cargar la instancia (participante_screen.dart:370) y las transiciones internas son mudas ('Toca las que estaban antes' en memoria, 'Ahora toca el sitio donde va' en arrastrar, la guía de secuencia); peor aún, el botón 'Escuchar' relee la instrucción original, no la fase actual. Que cada widget con pasos exponga su texto de fase (callback onGuiaHablada) para hablarlo al cambiar de fase y que el botón repita ESE. Hacer ese botón un objetivo grande y etiquetado ('Escúchalo otra vez'), no un icono camuflado junto al contador. Incluir además detección de voz disponible en tts.dart para no fallar mudo.
- archivos: apps/tablet/lib/screens/participante_screen.dart, apps/tablet/lib/widgets/memoria_visual_widget.dart, apps/tablet/lib/widgets/arrastrar_posicion_widget.dart, apps/tablet/lib/widgets/secuencia_ordenar_widget.dart, apps/tablet/lib/tts.dart

### #12 · Opciones con imagen en seleccion_multiple (la plantilla dominante, 43%)
- area: tablet | impacto: alto | esfuerzo: medio | roles: Terapeuta ocupacional
- seleccion_multiple es la plantilla más usada y el widget pinta las opciones SOLO como texto (seleccion_multiple_widget.dart:100-159), aunque muchas son identificadores con dibujo (gato/perro/conejo…) resolubles por IlustracionResolver: la persona ve la foto pero debe LEER las opciones. Cuando todas las opciones resuelvan a ilustración (o el ítem lo marque), renderizar la imagen grande en cada tarjeta con el texto debajo, como ya hacen búsqueda y memoria; añadir en tipos.py un campo {label, imagen_id} por opción para no depender de que el label coincida con el id. Mantener modo texto para refranes/lenguaje. Abre la plantilla más frecuente a no-lectores y baja visión.
- archivos: apps/tablet/lib/widgets/seleccion_multiple_widget.dart, backend/api/app/templates/tipos.py, backend/api/app/data/catalogo.json

### #13 · Leer en voz alta las opciones y 'tocar para oír' cada respuesta
- area: tablet | impacto: alto | esfuerzo: medio | roles: Terapeuta ocupacional
- El TTS solo lee consigna y enunciado (participante_screen.dart:391-399): las opciones nunca se pronuncian ni hay forma de oír una concreta, así que un no-lector oye la pregunta pero se enfrenta a 4 palabras escritas. Tras leer la consigna de seleccion_multiple, encadenar la lectura de las opciones ('Uno: gato. Dos: perro…') y añadir toque-largo o icono de altavoz por opción que la lea aislada. No penaliza tiempo (no hay cuenta atrás), es seguro clínicamente. Complementa la mejora de imagen en la misma plantilla.
- archivos: apps/tablet/lib/screens/participante_screen.dart, apps/tablet/lib/widgets/seleccion_multiple_widget.dart, apps/tablet/lib/tts.dart

### #14 · La ayuda acompaña la señal clínica y las etiquetas dejan de prometer lo que no miden
- area: clínico | impacto: alto | esfuerzo: medio | roles: Neuropsicólogo, Familiar
- con_ayuda se registra por intento pero está aislado de la señal primaria: no descuenta desempeño, el motor de alertas no la usa y objetivos la ignora, de modo que quien mantiene 'logrado' con cada vez más pistas dibuja una línea verde plana y se pierde justo la erosión de autonomía que la herramienta debe captar. Tratar la tendencia creciente de tasa_ayuda como cuarta señal de alertas (como el missingness), distinguir visualmente 'logrado solo' de 'logrado con ayuda' en evolución e informe, y opcionalmente una métrica complementaria 'con techo por ayuda' SIN tocar el resultado autocorregido. Corregir la etiqueta del informe y la leyenda de la gráfica para no afirmar que la línea combina la ayuda.
- archivos: backend/api/app/services/anomalias.py, backend/api/app/services/alertas.py, backend/api/app/routers/evolucion.py, apps/web/src/components/InformeFamilia.tsx, apps/web/src/components/EvolucionChart.tsx

### #15 · Tercer estado del veredicto: 'base en construcción', no verde falso
- area: clínico | impacto: alto | esfuerzo: medio | roles: Neuropsicólogo
- detectar_desviacion devuelve None cuando faltan datos (<6 puntos en el tramo de dificultad vigente, anomalias.py:107) y esa distinción entre 'no sé' y 'todo bien' se pierde: el Veredicto pinta verde tranquilizador con solo que no haya pendientes. Como el baseline se reinicia al cambiar de nivel y las sesiones son 1-2/semana, puede haber semanas de verde sin capacidad real de detectar declive. Exponer un tercer estado ('aún no puedo avisar de un declive / base en construcción') propagando que detectar_desviacion devolvió None por datos insuficientes, y reservar el verde para cuando SÍ hay base suficiente. Refuerza directamente la confianza clínica.
- archivos: apps/web/src/pages/UsuarioEvolucion.tsx, backend/api/app/routers/evolucion.py, backend/api/app/services/anomalias.py

### #16 · Objetivos: el 'va por' con ventana reciente y por nivel, no media de por vida
- area: clínico | impacto: alto | esfuerzo: medio | roles: Neuropsicólogo
- objetivos._situacion (objetivos.py:28-41) promedia TODOS los intentos valorados del área desde el inicio, sin fecha ni nivel: las sesiones flojas del arranque lastran para siempre, subir de nivel HUNDE el 'va por' aunque la persona mejore en el nivel nuevo, y no refleja 'situación actual'. Es incoherente con el propio motor de alertas, que sí segmenta por dificultad y mira la ventana reciente. Calcular la situación sobre las últimas N sesiones y/o dentro del nivel vigente, y mostrar junto a la barra el periodo/nº de sesiones promediadas.
- archivos: backend/api/app/routers/objetivos.py

### #17 · La tendencia del informe, coherente con el motor (segmentar por dificultad)
- area: clínico | impacto: alto | esfuerzo: medio | roles: Neuropsicólogo, Familiar
- calcularTendencia (InformeFamilia.tsx:25-36) compara primera vs última mitad de TODOS los puntos y construirSerie grafica cada intento como 0/0.5/1 sin tener en cuenta el nivel, mientras el motor agrega por sesión y segmenta por dificultad. Resultado: si se sube el nivel en el periodo, el informe puede imprimir 'Tendencia a revisar' mientras el motor clínico no ve nada — dos veredictos contradictorios, y el más alarmista es el que se entrega a la familia. Reutilizar el veredicto/segmentación del backend o, como mínimo, segmentar por nivel vigente y anotar en la gráfica los cambios de dificultad.
- archivos: apps/web/src/components/InformeFamilia.tsx, apps/web/src/components/EvolucionChart.tsx

### #18 · Botón 'Necesito ayuda' en tiempo real desde el kiosco
- area: tablet | impacto: alto | esfuerzo: medio | roles: Usuario Alzheimer, Integradora
- En el kiosco, si la persona se agobia solo puede avanzar (que registra el intento) o el gesto oculto con PIN de personal; la 'ayuda' actual es un flag que la maestra marca DESPUÉS al revisar, no una petición en vivo, y con dos salas abiertas no siempre ve al que está atascado. Añadir un botón digno 'Necesito ayuda' que, vía un endpoint análogo a reportarActual, encienda una señal en el monitor de la maestra (mismo canal donde ya se ve 'atascado'). No cambia la medición ni el sin_valorar; cumple el principio 'nunca atrapada'.
- archivos: apps/tablet/lib/screens/participante_screen.dart, apps/tablet/lib/screens/maestra_screen.dart, apps/tablet/lib/api/client.dart, backend/api/app/routers/sesiones.py

### #19 · Cerrar el bucle de medición: revisar los sin_valorar desde la tablet
- area: tablet | impacto: alto | esfuerzo: medio | roles: Integradora
- La cola de revisión de sin_valorar solo existe en el panel web; un centro que opera solo con tablet cierra la sesión con mediciones que nunca puntúan porque nadie se sienta luego al ordenador. El resumen al cerrar ya calcula cuántos sin_valorar quedan por persona (_FilaResumen) pero no ofrece resolverlos. En el diálogo de resumen, si sinValorar>0, añadir un botón por persona o global 'Revisar ahora (N sin valorar)' que abra el flujo de revisión en lote ya existente apuntando a esos intentos.
- archivos: apps/tablet/lib/screens/maestra_screen.dart, backend/api/app/routers/sesiones.py

### #20 · Panel de adherencia y uso del centro (el argumento anti-fuga)
- area: panel | impacto: alto | esfuerzo: medio | roles: Dirección, Comercial
- El centro paga por plaza pero no hay ninguna vista de USO: ni sesiones por semana, ni personas que llevan días sin jugar, ni utilización de tablets; el Dashboard solo muestra desempeño medio por dominio. Un director que renueva necesita ver que el programa se usa. Añadir una tira 'Actividad del centro' (sesiones 7/30 días, nº de personas que participaron, lista de 'personas sin actividad en +N días') apoyada en un endpoint de resumen de participación sobre Intento/Sesion, scoped por centro_id como resumen_areas. Incluir aquí el contador de 'personas activas' que también pide el modelo por plaza.
- archivos: apps/web/src/pages/Dashboard.tsx, apps/web/src/pages/Pacientes.tsx, backend/api/app/routers/evolucion.py

### #21 · Gestión de consentimientos en el panel (el backend ya existe, la UI no)
- area: panel | impacto: alto | esfuerzo: medio | roles: Dirección
- El backend tiene el flujo RGPD completo de consentimiento (usuarios.py:188-233, con rol_otorgante y documento_ref) pero no hay NINGUNA pantalla para registrarlo o verlo, así que ante inspección el director no puede demostrar en la app quién está en regla — justo lo que se revisa en un centro con personas de capacidad modificada. En la ficha de la persona, un bloque 'Consentimiento' (estado, quién lo otorgó y su rol, referencia al documento) con botón para registrar contra el endpoint existente, y un aviso visible en la lista de Personas cuando falte.
- archivos: apps/web/src/pages/Pacientes.tsx, apps/web/src/pages/UsuarioEvolucion.tsx, backend/api/app/routers/usuarios.py

### #22 · El centro como emisor: nombre/marca en informe y export
- area: comercial | impacto: medio | esfuerzo: bajo | roles: Dirección, Comercial, Familiar
- El informe a familia rotula 'Trazo · Estimulación cognitiva' y el CSV no lleva el centro; un documento que va a la familia o a inspección es del CENTRO (y de la cadena de Laura), no del proveedor. Mostrar el nombre del centro (ya en el modelo Centro) en la cabecera del informe y como fila de contexto en el CSV, dejando 'Generado con Trazo' como pie discreto; preparar el terreno para logo/color por centro (micro-migración) como white-label básico. Refuerza propiedad y profesionalidad del entregable.
- archivos: apps/web/src/components/InformeFamilia.tsx, backend/api/app/routers/evolucion.py, backend/api/app/models.py, backend/api/app/services/migraciones.py

### #23 · Memoria de actividad del centro (informe agregado en PDF)
- area: panel | impacto: alto | esfuerzo: medio | roles: Dirección
- Solo existe informe INDIVIDUAL para la familia y export CSV crudo; no hay ningún documento agregado del centro (cobertura, nº de personas trabajadas, desempeño por área, adherencia) que piden inspección, memorias anuales y la venta a la cadena. Reutilizar el patrón de InformeFamilia (portal + @media print, sin librerías) para una 'Memoria de actividad del centro' con periodo, personas activas, sesiones, desempeño por área (ya lo da resumen_areas) y nº por debajo de umbral, con botón 'Informe del centro (PDF)' en el Dashboard.
- archivos: apps/web/src/components/InformeFamilia.tsx, apps/web/src/pages/Dashboard.tsx, backend/api/app/routers/evolucion.py

### #24 · Cuadro de mando multi-centro para la dirección de la cadena
- area: panel | impacto: alto | esfuerzo: alto | roles: Comercial, Dirección
- Laura tiene 5 centros pero el producto no da NINGUNA vista agregada: plataforma.py devuelve conteos crudos y resumen-areas está scoped a un solo centro_id, así que la dirección no puede responder qué centros usan Trazo, dónde bajó el desempeño ni el ROI — exactamente lo que decide la compra de cadena frente a NeuronUP. Añadir un rol/vista 'dirección de cadena' con un endpoint que agregue por centro (sesiones/semana, personas activas vs alta, % sin revisar, desempeño por área y tendencia) y un panel con una fila por centro, semáforo de adopción y drill-down; iterar _calcular_evolucion/resumen-areas sobre los centros del grupo respetando el aislamiento. Es el bloqueante nº1 del cliente ancla.
- archivos: backend/api/app/routers/plataforma.py, backend/api/app/routers/evolucion.py, apps/superadmin, apps/web/src/pages/Dashboard.tsx

### #25 · Salida 'No soy yo' sin PIN y PIN de kiosco sin default en el repo
- area: tablet | impacto: medio | esfuerzo: medio | roles: Usuario baja visión, Usuario Alzheimer, Comercial
- Tras confirmar 'Sí, soy yo' la única salida es el gesto oculto + PIN del personal: si el mayor se da cuenta de que ese no es su nombre, se queda jugando como otra persona y contamina su medición hasta que alguien lo note. Añadir en _AhoraEmpezamos (y en _Terminado a la espera) un botón grande y discreto 'No soy yo' que suelte la identidad y vuelva a '¿quién eres?' sin PIN (reversible, sin exponer datos). En el mismo frente de seguridad de kiosco, quitar el KIOSK_PIN por defecto '1379' hardcodeado (participante_screen.dart:476) y exigir configurarlo por despliegue, documentándolo en la skill desplegar.
- archivos: apps/tablet/lib/screens/participante_screen.dart, .claude/skills

### #26 · Pulido de accesibilidad visual y motora en la tablet
- area: tablet | impacto: medio | esfuerzo: medio | roles: Usuario baja visión, Usuario Alzheimer, Terapeuta ocupacional
- Varios roces concretos del mayor más frágil, agrupables en una pasada: (1) el pastillero 'Míralas con calma' y el botón 'Ya lo recuerdo' usan blanco sobre TrazoColors.sage (~3.15:1, por debajo de AA) cuando AGENTS.md y theme.dart exigen sageDark; (2) en arrastrar, la equis de quitar (44px superpuesta a la pieza) y el spacing 12 hacen que el temblor borre o coja la pieza equivocada — separar la equis (~56px con halo) y subir el spacing a ~18-20 como en memoria; (3) sustituir el '1 de 5' pequeño de la esquina por una barra de progreso serena y ancha; (4) en conteo, subir el suelo de tamaño del objeto de 26px a ~40px y leer en voz alta el número al pulsar cada tecla.
- archivos: apps/tablet/lib/widgets/memoria_visual_widget.dart, apps/tablet/lib/widgets/arrastrar_posicion_widget.dart, apps/tablet/lib/screens/participante_screen.dart, apps/tablet/lib/widgets/conteo_comparacion_widget.dart

### #27 · Confirmar el reparto: quién ha cogido de verdad su tablet
- area: backend | impacto: alto | esfuerzo: alto | roles: Integradora
- En el monitor aparecen fichas de todos los participantes desde el minuto cero, así que una ficha en 'Aún no ha empezado' es ambigua (¿no ha cogido tablet o la cogió y no arrancó?) y la integradora no puede verificar de un vistazo que sus 8 mayores están cada uno en su tablet antes de iniciar. Añadir columna last_seen en SesionParticipante (micro-migración idempotente), actualizarla en estado_participante en cada poll del kiosco, y exponer un 'conectado' (visto en ~15s) en FichaViva para mostrar 'Esperando a que cojan la tablet' vs 'Preparado' con un punto de color.
- archivos: backend/api/app/routers/sesiones.py, backend/api/app/models.py, backend/api/app/services/migraciones.py, backend/api/app/schemas.py, apps/tablet/lib/screens/maestra_screen.dart

### #28 · Equilibrar la mezcla de plantillas por sesión (menos reconocimiento pasivo)
- area: contenido | impacto: medio | esfuerzo: medio | roles: Terapeuta ocupacional
- El catálogo está muy escorado a la plantilla más pasiva: 85 de 198 actividades (43%) son seleccion_multiple frente a plantillas activas/manipulativas (arrastrar 18, secuencia 20, dinero 13, trazo 10), así que una sesión al azar tiende a ser un rosario de '¿qué es esto? elige' que trabaja poca acción, planificación o motricidad. Al construir la cola de la sesión, equilibrar la mezcla (tope de seleccion_multiple por sesión y garantizar al menos una plantilla manipulativa/ejecutiva) y, en paralelo, ir ampliando el catálogo en las plantillas activas para poder rebalancear sin repetir.
- archivos: backend/api/app/routers/sesiones.py, backend/api/app/data/catalogo.json

### #29 · Orientación a la realidad temporal (día/estación de hoy) — diferenciador NeuronUP
- area: contenido | impacto: medio | esfuerzo: medio | roles: Terapeuta ocupacional
- La orientación temporal es estándar en centros de día y la cubre NeuronUP, pero el catálogo no tiene ninguna actividad anclada al 'hoy' real: las existentes ('días de la semana', 'estaciones', 'calendario en orden') son secuenciación abstracta, no '¿qué día es hoy?' o '¿en qué estación estamos?'. Añadir un pequeño bloque de orientación (seleccion_multiple con imágenes de estaciones/tiempo) cuya respuesta fije el centro para el día, dejando la corrección en manos de la maestra (nace sin_valorar) para no atar la fecha del servidor. Encaja de forma natural en el modelo de medición.
- archivos: backend/api/app/data/catalogo.json, backend/api/app/templates/tipos.py

### #30 · Integridad de la medición: re-corrección idempotente y desglose de 'sin valorar'
- area: backend | impacto: medio | esfuerzo: medio | roles: Neuropsicólogo
- Dos huecos de validez del backend: (1) corregir() se ejecuta una sola vez al registrar y nunca se recalcula, de modo que un APK viejo o un fallo de datos puede dejar un bloque entero como sin_valorar permanente, hueco de evolución/objetivos/alertas sin que nadie lo note — añadir una re-corrección idempotente (micro-migración o endpoint) que reprocese corregir() sobre intentos en sin_valorar cuyos valores permitan ahora un veredicto, registrando cuántos se recuperan. (2) sin_valorar mezcla 'no tocó nada' (desconexión) y 'pendiente de revisar' (tarea de la integradora) aunque hubo_interaccion ya los separa para el missingness — desglosarlos en la respuesta de evolución/resumen y en el ResumenTile y la cola, para que la señal de participación y la de trabajo pendiente no se diluyan.
- archivos: backend/api/app/routers/intentos.py, backend/api/app/services/correccion.py, backend/api/app/services/migraciones.py, backend/api/app/routers/evolucion.py, apps/web/src/pages/UsuarioEvolucion.tsx

