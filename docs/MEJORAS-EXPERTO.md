# Trazo — Informe de mejoras (consultoría experta)

> Revisión desde estimulación cognitiva, terapia ocupacional y neuropsicología
> aplicada a centros de día (mayoría de usuarios con deterioro cognitivo /
> Alzheimer). Documento **accionable**: cada sección termina en decisiones
> concretas, no en principios generales.

Orden de prioridad (por impacto real): **1) usabilidad de la trabajadora**,
**2) estética adulta / engagement**, **4) botón de ayuda discreto**,
**6) protección de datos**, luego 3, 5 y 7.

---

## 1. Usabilidad y dinamismo para la trabajadora (tablet maestra)

La integradora no está sentada delante de la tablet: está de pie, atendiendo a
3-6 personas a la vez, y toca la maestra en ráfagas de 2-3 segundos entre medias.
La regla de diseño es **"todo lo importante en un toque desde el monitor, sin
menús intermedios"**.

### Flujos objetivo (presupuesto de toques)
- **Abrir la sesión del día: ≤ 3 toques.** Login persistente (la maestra no
  cierra sesión entre días) → "Nueva sesión" → los participantes **ya vienen
  premarcados** con los de la última sesión (botón "los de siempre"), se
  deseleccionan los que hoy no vienen. Nunca escribir nada.
- **Repartir una tablet: 1 toque en la tablet del usuario** (pulsar su nombre).
  Cero acciones en la maestra.
- **Marcar "ayuda" a alguien: 1 toque** en su tarjeta del monitor (ver §4).
- **Saltar / dar por no completado un ejercicio: 1 toque largo** en la tarjeta
  (con confirmación mínima para evitar el accidental).
- **Dar más ejercicios a quien terminó: 1 toque** en "＋" de su tarjeta.

### El monitor manda
La pantalla por defecto tras abrir sesión debe ser **el monitor en vivo**, no un
menú. Tarjetas grandes de 3 en 3 con scroll (ya está en el modelo operativo).
Cada tarjeta es autónoma: nombre, ejercicio actual, estado y las 2-3 acciones
frecuentes visibles sin abrir nada. La trabajadora no debería necesitar entrar
en la ficha de nadie durante la sesión.

### Estados que se leen a un metro de distancia
Codificar el estado por **color + forma + posición**, no solo texto:
- **Trabajando** — neutro, calmado.
- **Atascado** (~1 min sin tocar, configurable) — la tarjeta se resalta y sube
  arriba del todo (que lo urgente flote), + aviso sonoro suave. Que ella no
  tenga que barrer las tarjetas con la vista.
- **Ayudado** — marca discreta, sin alarma.
- **Terminó su plan** — verde tranquilo + acción "＋ más" o "dejar".

### Qué EVITAR (fricción que mata el uso real)
- Nada de **modales que bloqueen** el resto del monitor: si aparece un diálogo,
  ella pierde de vista a los otros cinco.
- **Cero texto libre** en caliente. Todo es tocar, nunca teclear.
- No exigir **guardar/confirmar** cada acción; autosalvado silencioso.
- No **re-login** ni timeouts cortos de sesión en la maestra durante la jornada
  (sí bloqueo de pantalla rápido, ver §6 — son cosas distintas).
- No esconder acciones frecuentes tras iconos ambiguos: etiqueta corta + icono.
- No paginar el monitor con "siguiente página": **scroll vertical** continuo.

### Recomendación
Diseñar la maestra como **"un tablero, no una app de menús"**: una sola pantalla
operativa (monitor) desde la que se hace el 95% de las acciones de la sesión, y
todo lo de "pensar" (planes, niveles) queda relegado a la web, en frío.

---

## 2. Estética ADULTA, no infantil (queja real del sector)

Este es un diferenciador comercial, no un detalle. Las apps del sector suelen
fracasar en enganche porque **infantilizan**, y la persona mayor lo percibe como
una falta de respeto ("me tratan como a un niño") — sobre todo quienes conservan
conciencia de su deterioro. El objetivo es **dignidad + claridad**, no "diversión".

### Dirección visual concreta
- **Fotografía real por encima del dibujo.** Para denominación, gnosias, "qué es
  esto", la compra, poner la mesa: usar **fotos reales de objetos cotidianos**
  (una taza real, unas tijeras reales), no iconos caricaturizados. Reconocer un
  objeto real es además clínicamente más válido que reconocer un pictograma.
  - Fotos **limpias, fondo neutro, un solo objeto, bien iluminadas y grandes**.
  - De objetos **de su generación y contexto** (un puchero, una radio antigua,
    monedas de euro reales) — refuerza la familiaridad y evoca (reminiscencia).
- **Ilustración solo donde la foto no llega** (trazos, formas geométricas,
  reloj analógico): línea sobria, trazo grueso, estilo "manual de instrucciones
  bonito", nunca "cuento infantil".
- **Paleta**: la de la propia presentación ya acierta — marfil/salvia/coral
  apagados, tierra, tonos naturales y cálidos, alto contraste texto/fondo. **Huir
  de primarios saturados** (rojo/amarillo/azul chillón = código "juguete").
- **Tipografía grande pero seria.** Cuerpo mínimo ~22-24 px en la tablet del
  usuario; serif con carácter para títulos (Fraunces ya está) + sans humanista
  legible para cuerpo (Inter). Grande por **accesibilidad**, no por infantil:
  la diferencia está en la elegancia de la fuente, no en el tamaño.
- **Iconografía adulta**: line-icons sobrios, no emojis rebosantes ni mascotas.
- **Animaciones**: mínimas y con propósito (una transición suave al acertar).
  Nada de confeti, personajes que saltan, sonidos de premio de videojuego.

### Tono y refuerzo (motivar sin infantilizar)
- **Feedback respetuoso y adulto**: "Correcto", "Muy bien", un check discreto —
  no "¡¡GENIAL CAMPEÓN!!" con fuegos artificiales.
- **Nunca castigar el error en pantalla**: sin cruces rojas grandes, sin sonido
  de fallo. Coherente con el principio del producto ("no empeorar, no examinar").
- **Contexto con sentido para el adulto**: enmarcar como tareas de la vida ("la
  compra", "la vuelta del cambio", "poner la mesa", refranes) engancha más que
  puntos y niveles abstractos. El catálogo ya va por ahí — reforzarlo.
- **Reminiscencia como gancho**: imágenes y refranes de su época conectan
  emocionalmente y están cognitivamente muy conservados (funciona incluso en
  deterioro avanzado) → sensación de competencia, que es lo que engancha.

### Recomendación
Fijar una **guía de estilo de una página** (foto real > dibujo; paleta natural;
tipografía grande y seria; feedback sobrio; cero elementos "de niño") y aplicarla
como criterio de aceptación de cada actividad nueva. Es barato y es el mayor
diferenciador frente a la competencia.

---

## 3. Mejora / progresión por paciente (sin que se viva como examen)

El producto ya tiene la pieza clave bien pensada: **nivel personal, comparación
solo consigo mismo, cantidades cambiantes**. Refuerzos:

- **La progresión la ve el profesional y la familia, no el usuario.** En la
  tablet del usuario NO hay puntuaciones, niveles, ni "has subido a nivel 3". Él
  solo ve la actividad de hoy. El avance vive en el panel (web y seguimiento de
  la maestra).
- **Cambio de nivel = sugerencia que aprueba el profesional** (ya está en el
  modelo operativo). Que nunca cambie solo: evita el efecto "de repente esto
  está más difícil" que se vive como fracaso.
- **La dificultad se mueve por la cantidad cambiante, no por "modo difícil".**
  Hoy suma 6 €, otro día 11 €: se sube/baja exigencia sin etiqueta de examen. Ya
  implementado en las plantillas (rango por nivel); mantenerlo como norma.
- **Narrativa de progreso para la familia**: en el panel, contar la evolución en
  lenguaje humano ("Carmen se mantiene estable en atención estas 8 semanas"),
  no solo una curva. Es lo que da valor percibido y justifica la suscripción.
- **Métrica de ayuda como señal fina**: el aumento de "con ayuda" suele preceder
  a la caída de precisión → mostrarlo como indicador temprano en el panel (ya
  apuntado en la presentación; convertirlo en vista de primera clase).

### Recomendación
Mantener la personalización **invisible para el usuario y explícita para el
profesional**. La sensación buscada en el usuario es "hoy también he podido", no
"he aprobado".

---

## 4. El botón de "ayuda" DISCRETO (que el usuario no lo pulse)

Problema real: si "realizado con ayuda" está accesible en la tablet del usuario,
lo pulsarán ellos (por confusión o por costumbre) y **falsean la métrica** —
justo la métrica más valiosa para la detección temprana. El control tiene que
ser **accesible para la trabajadora e invisible/inalcanzable para el usuario**.

### Patrones evaluados

| Patrón | Cómo | Pros | Contras |
|---|---|---|---|
| **A. Solo en la tablet maestra** | Marcar ayuda desde la tarjeta del monitor | Físicamente imposible que el usuario lo toque; 1 toque; ya encaja con el monitor | La maestra debe tener su tablet a mano en ese momento |
| **B. Gesto oculto en la tablet del usuario** | P. ej. pulsación larga en una esquina "muerta" (2-3 s) | No necesita la maestra; sin UI visible | Descubrible por azar; difícil de explicar; poco fiable |
| **C. Esquina + PIN del equipo** | Zona/esquina con pulsación larga que pide PIN corto | Muy protegido; sirve también para recuperar la tablet | 2-3 pasos → fricción alta para marcar "ayuda" en caliente |
| **D. Segunda pantalla / mando** | La maestra lleva su móvil o un mando físico | Discretísimo; a mano siempre | Otro dispositivo que emparejar y mantener |
| **E. Automático por observación** | Inferir "ayuda" si otra sesión toca su tarjeta, o por patrón anómalo de toques | Cero acción manual | Poco fiable; la ayuda física real no la ve el sensor |

### Recomendación (combinada)
- **Primario: patrón A** — marcar "ayuda" **solo desde la tablet maestra**, con
  1 toque en la tarjeta del monitor. Es el que mejor cumple el requisito: el
  control **no existe** en la tablet del usuario, así que es imposible que lo
  falsee. Esto ya está contemplado en el modelo operativo; hay que hacerlo el
  camino **por defecto** y quitar cualquier botón de ayuda de la vista kiosco.
- **Secundario: patrón C solo para "recuperar/reasignar tablet"** — la esquina +
  pulsación larga + PIN se reserva para sacar al usuario de la actividad
  (cambiar de persona, salir del kiosco), **no** para marcar ayuda en el día a
  día. Así el gesto complejo se usa poco y el frecuente (ayuda) es de 1 toque.
- **Regla dura**: la vista participante **nunca** muestra controles de estado
  (ayuda / saltar / salir). Todo estado se marca desde la maestra. Esto además
  simplifica la app kiosco y protege el rol (ya decidido en el modelo operativo).

Nota de dato: cuando la ayuda se marca desde la maestra, registrar también
`staff_id` y timestamp — trazabilidad limpia de quién ayudó y cuándo.

---

## 5. Facilidad para añadir actividades (data-driven) — reafirmado y mejorado

El diseño ya es correcto: **un ejercicio = una fila de catálogo** sobre una de
las 8 plantillas; la plantilla genera las tiradas con cantidades cambiantes. Con
la refactorización de este encargo, el catálogo pasa a vivir en **datos puros**:

- Todas las actividades están ahora en `backend/api/app/data/catalogo.json`.
- `seed.py` las **carga de ahí** (idempotente); ya no hay lista de ejercicios
  incrustada en el código.
- **Añadir una actividad = añadir un objeto al JSON** con `bloque`,
  `plantilla_tipo`, `nombre`, `descripcion` y el `parametros_json` que consuma su
  plantilla (la fuente de la verdad de qué campos necesita cada plantilla es
  `templates/tipos.py`). Cero código, cero migración.

### Mejoras recomendadas (siguientes pasos, no urgentes)
- **Editor de catálogo en la web** para el profesional: alta/edición de
  actividades sin tocar JSON (POST `/ejercicios` ya existe; falta la UI). Con
  vista previa que llame a `/ejercicios/{id}/instancia` para ver una tirada real
  antes de activarla.
- **Validación por plantilla**: un pequeño validador (JSON Schema por
  `plantilla_tipo`) que avise al guardar si a un `seleccion_multiple` le faltan
  `items`, a un `memoria_visual` le faltan elementos de `banco` (<4), etc. Hoy
  el fallo solo salta al pedir la instancia; adelantarlo al alta.
- **Gestión de imágenes/audio como datos**: los `imagen`/`audio` del catálogo
  son referencias (ids). Definir un bucket/CDN y que el alta permita subir la
  foto real (ver §2) asociada al id.
- **Semilla vs. contenido de centro**: mantener `catalogo.json` como catálogo
  base "de fábrica"; las actividades que cree cada centro van a BD y no se pisan
  en el re-seed (la siembra ya es idempotente: solo siembra si el centro no
  existe).
- **Activar/desactivar** en vez de borrar (ya hay `activo`): así el profesional
  retira una actividad que no funciona sin perder su histórico.

---

## 6. Protección de datos / cifrado (RGPD — categoría especial)

Son **datos de salud** (art. 9 RGPD, categoría especial). El diseño ya parte
bien: pseudonimización (alias interno en las tablas de trabajo, nombre real en
tabla separada `datos_identificativos`), `registro_auditoria`, `consentimientos`,
y bcrypt para contraseñas. Lo que falta para un **piloto con datos reales**:

### Ya presente (mantener)
- **Seudonimización** real: las consultas de trabajo (intentos, evolución,
  alertas) nunca tocan el nombre real. Excelente base.
- **bcrypt** para contraseñas de staff.
- **JWT** para sesiones y **modelo de auditoría** definido.
- **Dispositivos revocables** (token por tablet, `activo=false`) — clave si se
  pierde una tablet.

### Imprescindible antes del piloto
1. **Cifrado en tránsito**: HTTPS/TLS obligatorio extremo a extremo (API,
   tablets, web). Nada de HTTP en claro ni en la red local del centro. HSTS.
2. **Cifrado en reposo**: cifrado de disco/volumen de la BD y de los backups.
   Para el nombre real y notas clínicas, valorar **cifrado a nivel de columna**
   en `datos_identificativos` (clave gestionada aparte de la BD).
3. **Gestión de secretos**: `JWT_SECRET` y credenciales de BD fuera del código y
   del repo, en gestor de secretos/variables de entorno del despliegue. Rotables.
4. **Sesiones/JWT**: expiración razonable, **revocación** (logout real /
   lista de revocados), y refresh controlado. Hoy `jwt_expire_minutes=480`
   (8 h) encaja con una jornada; añadir bloqueo de pantalla con re-desbloqueo
   rápido en la maestra (distinto del token) para cuando la deja encima de una
   mesa.
5. **Control de acceso por rol y por centro**: garantizar que cada consulta
   filtra por `centro_id` del staff autenticado (aislamiento multi-centro), y
   que `familia` solo ve a los suyos. Revisar que ningún endpoint permita leer
   usuarios de otro centro cambiando un id en la URL (IDOR).
6. **Auditoría efectiva**: escribir en `registro_auditoria` en cada acceso a
   datos identificativos y a la evolución de un usuario (quién, a quién, cuándo,
   qué). Hoy la tabla existe; hay que asegurarse de que **se escribe** de verdad.
7. **Minimización**: no recoger más de lo necesario (no hace falta DNI, dirección
   ni diagnóstico detallado para el piloto). Fecha de nacimiento solo si aporta.
8. **Retención y borrado**: política de plazos + **borrado/anonimización real**
   al dar de baja a una persona o al cerrar el piloto. Export de sus datos
   (derecho de acceso/portabilidad).

### Marco legal del piloto (ya bien encaminado en la presentación)
- **El centro es Responsable del tratamiento; vosotros, Encargado** → firmar
  **contrato de encargo (art. 28)**. El consentimiento con las familias lo
  gestiona el centro (relación de confianza existente).
- **EIPD/DPIA**: evaluación de impacto (obligatoria por ser categoría especial +
  personas vulnerables). Hacerla antes del piloto con datos reales.
- **Registro de actividades de tratamiento**, información a los interesados y,
  si el volumen lo pide, valorar **DPO**.
- **Piloto inicial sin datos identificables** (como ya se plantea en la Fase 1):
  arrancar solo con alias, y activar el nombre real solo cuando el marco legal
  esté firmado. Encaja perfecto con la seudonimización ya diseñada.

### Recomendación
Para código: **HTTPS + cifrado en reposo + secretos fuera del repo + auditoría
que se escriba + filtrado por centro** son el mínimo técnico. Para negocio:
**contrato de encargo + DPIA + consentimiento vía centro** antes de tocar un solo
dato real. La arquitectura ya lo pone fácil; es sobre todo "activar" y formalizar.

---

## 7. Notas de monetización (futuro, breve)

Modelos realistas para este sector (residencias y centros de día):
- **Suscripción por centro, escalada por plazas/usuarios activos** (p. ej.
  tramos por nº de usuarios). Es el modelo que mejor entiende el sector y el más
  predecible.
- **Piloto gratuito acotado** (1 centro, 1-2 meses, grupo pequeño) como puerta
  de entrada — coincide con la Fase 1 del roadmap. Convierte por evidencia, no
  por promesa.
- **Licencia por dispositivo/tablet** como alternativa simple para centros
  pequeños.
- **Add-ons de mayor margen**: panel para familias (informe periódico de
  evolución), integración con la historia del centro, soporte/formación.
- **Vía institucional**: convenios con **grupos de residencias** o
  administración (dependencia) — ciclos de venta largos pero contratos grandes.

Recomendación: **suscripción por centro con tramos de plazas + piloto gratuito**
como estándar; el informe a familias como upsell natural una vez hay datos.

---

## Resumen de acciones prioritarias

1. Maestra = **un tablero de una pantalla** (monitor), acciones frecuentes a 1
   toque, cero texto en caliente, sin modales que bloqueen.
2. **Guía de estilo adulta**: foto real > dibujo, paleta natural, tipografía
   grande y seria, feedback sobrio, cero elementos infantiles.
3. **Ayuda solo desde la maestra** (imposible de falsear por el usuario);
   esquina+PIN reservada a recuperar/reasignar la tablet.
4. Progresión **invisible al usuario, explícita al profesional/familia**.
5. Catálogo **100% data-driven** (hecho): añadir actividad = añadir fila al JSON.
6. Antes del piloto real: **HTTPS, cifrado en reposo, secretos fuera del repo,
   auditoría efectiva, filtrado por centro** + **contrato de encargo y DPIA**.
7. Monetización: **suscripción por centro (tramos de plazas) + piloto gratuito**.
