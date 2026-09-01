# Evaluación de Impacto relativa a la Protección de Datos (EIPD / DPIA)

## Proyecto TRAZO — App de estimulación cognitiva para centros de día y residencias

> **AVISO IMPORTANTE — LEER ANTES DE USAR**
>
> Este documento es un **BORRADOR ORIENTATIVO generado por una inteligencia artificial**. **NO constituye asesoramiento jurídico** ni sustituye la revisión por un profesional. Debe ser **revisado, validado y adaptado por un abogado especialista en protección de datos y/o por el Delegado de Protección de Datos (DPO)** antes de su aprobación y uso.
>
> Los campos marcados **[ENTRE CORCHETES]** deben completarse con la información real de cada organización. Las valoraciones de riesgo, controles y decisiones aquí propuestas son **hipótesis de partida** que exigen contraste con la realidad del tratamiento.
>
> Marco de referencia: art. 35 RGPD (Reglamento (UE) 2016/679); LOPDGDD (Ley Orgánica 3/2018); Directrices WP248 rev.01 del GT29 sobre EIPD; Guías y listas de la AEPD (herramienta *Gestiona EIPD/RGPD*, *Lista de cumplimiento normativo*); y, en su caso, normativa autonómica de servicios sociales aplicable.

---

## 0. Control del documento

| Campo | Contenido |
|---|---|
| Título | EIPD del tratamiento "Estimulación cognitiva y medición de desempeño — Trazo" |
| Versión | 0.9 (borrador técnico, pendiente de revisión por DPO/asesoría) |
| Fecha | [FECHA de aprobación] |
| Autor del borrador | Saulo Miguel De la Santacruz Fernández (Trazo, encargado del tratamiento), con la parte técnica completada y verificada contra el código y la infraestructura reales |
| Revisado por (DPO) | [NOMBRE DPO] |
| Revisado por (asesoría jurídica) | [DESPACHO / ABOGADO] |
| Aprobado por (responsable del tratamiento) | [NOMBRE / CARGO EN EL CENTRO] |
| Próxima revisión prevista | [FECHA — recomendado: al menos anual o ante cambios sustanciales] |
| Estado | Borrador / En revisión / Aprobado |

**Nota sobre quién debe realizar la EIPD:** la obligación del art. 35 RGPD recae sobre el **responsable del tratamiento**, que en este modelo es **cada CENTRO/residencia**. TRAZO, como **encargado del tratamiento**, elabora esta plantilla y aporta la información técnica (art. 28.3.f RGPD: deber de asistencia al responsable), pero **cada centro debe apropiarse del documento, completarlo y aprobarlo** para su propio tratamiento. Si un grupo empresarial gestiona varios centros (p. ej. [GRUPO / EMPRESA CLIENTE], [Nº] centros), puede elaborarse una EIPD marco y particularizarse por centro.

---

## 1. Descripción sistemática del tratamiento (art. 35.7.a RGPD)

### 1.1. Identificación de las partes

| Rol | Entidad | Datos |
|---|---|---|
| **Responsable del tratamiento** | El CENTRO / residencia | [RAZÓN SOCIAL DEL CENTRO], [NIF], [DIRECCIÓN], [CONTACTO] — a cumplimentar por cada centro |
| **Encargado del tratamiento** | TRAZO (proveedor del software) | Saulo Miguel De la Santacruz Fernández (empresario individual/autónomo), NIF 42238667H, Santa Cruz de Tenerife (Islas Canarias, España), saulodlsf@gmail.com |
| **DPO del responsable** | [NOMBRE / CONTACTO — lo designa el centro; obligatorio si se cumple art. 37 RGPD, probable por tratamiento a gran escala de datos de salud] |
| **DPO / contacto RGPD de Trazo** | Saulo Miguel De la Santacruz Fernández, saulodlsf@gmail.com (contacto RGPD; la designación formal de DPO se valorará según art. 37) |
| **Subencargados** | **Google Cloud** (Cloud Run, región Madrid `europe-southwest1`) · **Aiven** (PostgreSQL gestionado, base de datos) · **Cloudflare** (Pages, webs estáticas). Detalle en `04-medidas-seguridad-infraestructura.md` §8 |

Relación regulada mediante **contrato de encargo de tratamiento (art. 28 RGPD)** entre cada centro y Trazo. [REFERENCIA AL CONTRATO / ANEXO].

### 1.2. Finalidad del tratamiento

- **Finalidad principal:** apoyar la intervención no farmacológica de estimulación cognitiva de las personas usuarias del centro, presentando actividades en tablet y **midiendo el DESEMPEÑO** de cada persona en dichas actividades.
- **Finalidad secundaria (derivada):** comparar a cada persona **consigo misma** a lo largo del tiempo y **generar avisos de cambios relevantes** en el desempeño, para que **el profesional del centro los revise** y decida.
- **Lo que el tratamiento NO hace (delimitación expresa):**
  - **No** realiza diagnóstico clínico ni cribado diagnóstico.
  - **No** es un producto sanitario ni pretende serlo. [CONFIRMAR con asesoría regulatoria que el posicionamiento como "no producto sanitario" es sostenible según el uso previsto y la publicidad; ver MDR (UE) 2017/745 y guías AEMPS.]
  - **No** toma decisiones automatizadas con efectos jurídicos o similarmente significativos sobre la persona: las alertas son **apoyo a la decisión**; la valoración y cualquier consecuencia asistencial la adopta un profesional (no hay decisión individual automatizada del art. 22 RGPD). [VALIDAR jurídicamente que el diseño garantiza intervención humana significativa.]
  - **No** infiere ni etiqueta "deterioro" ni categorías diagnósticas; mide desempeño en actividad.

### 1.3. Naturaleza y alcance

- Aplicación en tablet usada por profesionales y/o personas usuarias en las instalaciones del centro.
- Volumen estimado: [Nº] personas usuarias activas; [Nº] centros; [Nº] profesionales con acceso.
- Ámbito territorial: España. [INDICAR comunidades autónomas / normativa de servicios sociales aplicable.]
- **Escala:** tratamiento a **gran escala** de **datos de categoría especial (salud)** sobre **colectivo vulnerable** — factor que, por sí solo, típicamente **exige** EIPD.

### 1.4. Contexto y flujos de datos

1. Alta de la persona usuaria: el centro registra el nombre real y datos identificativos en una **tabla separada** y le asigna un **alias interno (seudónimo)**.
2. La operativa de actividades y medición trabaja **solo con el alias**; el desempeño se asocia al seudónimo.
3. Los datos se alojan en **servicios gestionados en la nube dentro del EEE**: la API corre en **Google Cloud Run** (región `europe-southwest1`, **Madrid**), sin almacenamiento persistente; el **único almacén de datos** es **Aiven for PostgreSQL** (cifrado en reposo por defecto, ver §5); las webs son estáticas en **Cloudflare Pages** (sin datos personales). **TLS** en tránsito. Detalle técnico en `04-medidas-seguridad-infraestructura.md`. [CONFIRMAR que la región del servicio de Aiven está en el EEE.]
4. El profesional consulta la evolución y los avisos desde la app, limitado a las personas de **su centro** (control de acceso por centro).
5. [DESCRIBIR cualquier flujo adicional: exportaciones, informes en PDF, integración con historia del centro, soporte técnico de Trazo con acceso a datos, etc.]

> **Recomendación:** adjuntar un **diagrama de flujo de datos** y el **inventario/Registro de Actividades de Tratamiento (RAT, art. 30 RGPD)** correspondiente como anexos. [ANEXO I: diagrama] · [ANEXO II: RAT].

---

## 2. Necesidad y proporcionalidad (art. 35.7.b RGPD)

### 2.1. Base jurídica (art. 6 RGPD)

- Tratamiento de datos personales: **propuesta (a confirmar por el DPO)** → **art. 6.1.b** (ejecución del contrato de prestación asistencial con la persona usuaria o su representante) como base principal, reforzada por **art. 6.1.e/f** (misión de interés público en servicios sociales / interés legítimo del centro en la calidad asistencial). El centro es el responsable y elige/justifica la base según su título de prestación del servicio.

### 2.2. Condición que levanta la prohibición del art. 9 (datos de salud)

Los datos de desempeño en actividades de estimulación, vinculados a personas con patologías cognitivas, son **datos relativos a la salud (art. 9.1 RGPD)**. Condición habilitante **propuesta (a confirmar por el DPO)**: **art. 9.2.h** (fines de asistencia sanitaria o social prestada por/ bajo la responsabilidad de profesional sujeto a secreto — encaja con un centro de día), **reforzada con el consentimiento explícito (art. 9.2.a)** del interesado o su representante para transparencia y por el carácter voluntario del uso de la herramienta. Base legal interna: **art. 9 LOPDGDD** y la normativa autonómica de servicios sociales aplicable. El profesional del centro que interpreta los datos está sujeto a **deber de secreto**, lo que sustenta la vía 9.2.h.

> **Consentimiento y capacidad modificada:** muchas personas usuarias tienen su **capacidad de decisión modificada**. Debe articularse la intervención de la persona y, cuando proceda, de quien preste **apoyo/representación** conforme a la **Ley 8/2021** (reforma del apoyo a personas con discapacidad), **respetando la voluntad y preferencias de la persona** y evitando sustituir su decisión más de lo estrictamente necesario. [DEFINIR con asesoría jurídica el circuito de información y, en su caso, consentimiento/apoyo, y su documentación.] El **deber de información (arts. 13-14 RGPD)** debe cumplirse en formato **accesible y comprensible**.

### 2.3. Principios (art. 5 RGPD) y test de proporcionalidad

| Principio | Cómo se cumple | A completar |
|---|---|---|
| Licitud, lealtad y transparencia | Información a personas usuarias/representantes; contrato de encargo | [Nº/modelo de cláusula informativa] |
| Limitación de la finalidad | Solo estimulación y medición de desempeño; no reutilización incompatible | [Confirmar prohibición de usos secundarios: marketing, seguros, etc.] |
| **Minimización** | Se trata solo el desempeño y el alias; el nombre real queda segregado | [Revisar que no se capturan datos innecesarios] |
| Exactitud | El profesional revisa; posibilidad de corrección | [Procedimiento de rectificación] |
| Limitación del plazo de conservación | [DEFINIR plazos: p. ej. mientras dure la relación asistencial + plazo legal; después, supresión o anonimización] | [PLAZOS CONCRETOS] |
| Integridad y confidencialidad | Cifrado, control de acceso, backups | Ver secciones 4-5 |
| Responsabilidad proactiva | Esta EIPD, RAT, contratos, políticas | [Evidencias] |

**Valoración de proporcionalidad (borrador):** el tratamiento parece **necesario** para la finalidad asistencial y **proporcionado** si se mantiene la minimización, la seudonimización y el carácter de "apoyo a la decisión". No se aprecia una alternativa menos intrusiva que cumpla la misma finalidad con eficacia equivalente. [El DPO debe confirmar esta valoración.]

### 2.4. Derechos de los interesados

Procedimientos para atender **acceso, rectificación, supresión, limitación, oposición y portabilidad** (arts. 15-22 RGPD), adaptados a personas con capacidad modificada y a la intervención de figuras de apoyo. Como **encargado**, Trazo asistirá al responsable en su atención (art. 28.3.e). [DESCRIBIR canal, plazos y responsable de respuesta.]

---

## 3. Categorías de datos e interesados

### 3.1. Categorías de interesados

- **Personas usuarias del centro**, mayoritariamente personas **mayores** con **Alzheimer u otras demencias** → **colectivo especialmente vulnerable**; muchas con **capacidad de decisión modificada**.
- **Profesionales del centro** (usuarios de la app): terapeutas, personal asistencial. [Detallar perfiles.]
- [Otros: representantes legales/figuras de apoyo, familiares, personal de soporte de Trazo.]

### 3.2. Categorías de datos

| Categoría | Ejemplos | Tabla / ubicación |
|---|---|---|
| Identificativos (segregados) | Nombre real, [DNI si aplica], vinculación con alias | Tabla separada, acceso restringido |
| Seudónimo | Alias interno | Base operativa |
| **Datos de salud (art. 9)** | Desempeño en actividades, evolución, avisos de cambio | Base operativa (por alias) |
| Datos de uso técnico | Registros de acceso, logs, ID de dispositivo | [DEFINIR] |
| Datos de profesionales | Credenciales, centro asignado, actividad | [DEFINIR] |
| [Otros] | [p. ej. edad, sexo, nivel educativo si se recogen para normalizar] | [Justificar necesidad] |

> **Nota:** aunque la vinculación desempeño↔alias se separe del nombre real, **el conjunto sigue siendo dato personal de salud** mientras exista posibilidad de reidentificación (seudonimización ≠ anonimización). El régimen del art. 9 se mantiene.

---

## 4. Identificación y evaluación de riesgos para los derechos y libertades (art. 35.7.c)

*Escala orientativa — Probabilidad (P) y Severidad (S): Baja / Media / Alta. Riesgo residual tras medidas de la sección 5. Valores a validar por el DPO.*

### R1 — Reidentificación de personas seudonimizadas
- **Descripción:** cruce de la tabla de alias con la base operativa, o inferencia por patrones/datos de contexto, que revele la identidad y el estado de salud.
- **Afección a derechos:** confidencialidad, intimidad, protección de datos de salud; estigmatización.
- **P/S (bruto):** [P: Media] / [S: Alta]

### R2 — Falsos positivos de las alertas (aviso de cambio inexistente)
- **Descripción:** el sistema avisa de un empeoramiento que no es real (ruido, mal día, error de medición).
- **Afección a derechos:** decisiones asistenciales injustificadas, ansiedad de la persona/familia, cambios de plan no necesarios, **estigmatización**.
- **P/S (bruto):** [P: Media] / [S: Media-Alta]

### R3 — Falsos negativos de las alertas (no avisa de un cambio real)
- **Descripción:** el sistema no detecta un cambio relevante de desempeño.
- **Afección a derechos:** pérdida de oportunidad de revisión profesional; **exceso de confianza** en la herramienta.
- **P/S (bruto):** [P: Media] / [S: Media-Alta]
- **Nota clínica:** el diseño de Trazo fija que el sistema **mide desempeño y avisa, no diagnostica**; el falso negativo no debe interpretarse como "ausencia de problema".

### R4 — Decisiones sobre personas vulnerables / sesgo de automatización
- **Descripción:** que el profesional (o el centro) trate los avisos como conclusiones y adopte decisiones que afecten a una persona vulnerable sin valoración propia.
- **Afección a derechos:** dignidad, autonomía, no discriminación; riesgo de tratar la medición como "etiqueta de deterioro".
- **P/S (bruto):** [P: Media] / [S: Alta]

### R5 — Brecha de seguridad (confidencialidad/integridad/disponibilidad)
- **Descripción:** acceso no autorizado, exfiltración, ransomware, pérdida de backups, fuga por dispositivo (tablet perdida/robada).
- **Afección a derechos:** exposición masiva de datos de salud de colectivo vulnerable → **alto riesgo**.
- **P/S (bruto):** [P: Media] / [S: Alta]

### R6 — Acceso indebido entre centros / exceso de permisos
- **Descripción:** un profesional accede a datos de personas de **otro centro** o a más datos de los necesarios.
- **Afección a derechos:** confidencialidad; vulneración de minimización.
- **P/S (bruto):** [P: Baja-Media] / [S: Media-Alta]

### R7 — Falta de transparencia / consentimiento o información inadecuados
- **Descripción:** personas con capacidad modificada que no comprenden el tratamiento; información no accesible; circuito de apoyo/representación mal documentado.
- **Afección a derechos:** información, autonomía, licitud del tratamiento.
- **P/S (bruto):** [P: Media] / [S: Media]

### R8 — Conservación excesiva / uso incompatible
- **Descripción:** datos guardados más de lo necesario o reutilizados para fines distintos (comercial, cesión indebida).
- **P/S (bruto):** [P: Baja-Media] / [S: Media-Alta]

### R9 — Subencargados / ubicación y transferencias
- **Descripción:** proveedores de hosting/soporte con acceso; transferencias fuera del EEE sin garantías.
- **P/S (bruto):** [P: Baja] / [S: Alta] — [CONFIRMAR que todo el tratamiento y los backups permanecen en el EEE y que los subencargados están contractualmente vinculados (art. 28.4).]

### R10 — Continuidad y disponibilidad
- **Descripción:** caída del servicio o pérdida de datos que impida la continuidad asistencial o la recuperación.
- **P/S (bruto):** [P: Baja-Media] / [S: Media]

> Añadir los riesgos adicionales que identifique el centro: [OTROS RIESGOS].

---

## 5. Medidas previstas para afrontar los riesgos (art. 35.7.d)

*Para cada medida, indicar responsable de implantación y evidencia. El riesgo residual objetivo debería ser Bajo/Aceptable; el DPO debe confirmarlo.*

### Medidas frente a R1 (reidentificación)
- **Seudonimización** por diseño: alias interno; el nombre real en **tabla separada** con acceso restringido y segregado.
- Separación lógica y de permisos entre la tabla identificativa (`datos_identificativos`) y la base operativa (que trabaja solo con alias).
- **Cifrado en reposo: cubierto** — toda la base de datos (incluida la tabla identificativa) reside en Aiven, cifrada en reposo por defecto (LUKS/AES-256); cifrado en tránsito (TLS/`sslmode=require`). Ver `04-…` §2.
- Minimización de datos de contexto que faciliten inferencia.
- [Evaluar reglas para evitar reidentificación por grupos muy pequeños en informes.]
- **Riesgo residual:** [ ]

### Medidas frente a R2 y R3 (falsos positivos / negativos)
- **Principio de diseño no revertible (Trazo):** el intento nace **sin valorar**; se mide **desempeño, no "deterioro"**; se compara a la persona **consigo misma**.
- Las salidas son **avisos para revisión profesional**, nunca conclusiones automáticas.
- [Documentar umbrales de alerta, su justificación y su calibración; evitar sobre-alertado.]
- Mensajería en la interfaz que recuerde el carácter orientativo del aviso y la necesidad de juicio profesional.
- [Registrar tasas de acierto/falsos avisos si es viable, para mejora continua.]
- **Riesgo residual:** [ ]

### Medidas frente a R4 (decisiones sobre personas vulnerables)
- **El profesional decide** (intervención humana significativa); la app **no automatiza** decisiones del art. 22.
- Formación al personal sobre interpretación de avisos y **sesgo de automatización**.
- Redacción de la interfaz y de los informes evitando lenguaje diagnóstico o de "deterioro".
- Enfoque centrado en la persona, respeto a su voluntad y preferencias (Ley 8/2021).
- **Riesgo residual:** [ ]

### Medidas frente a R5 (brechas)
- **Cifrado** en tránsito (TLS) y **en reposo** (Aiven cifra datos y backups por defecto, LUKS/AES-256).
- **Copias de seguridad** gestionadas por Aiven (automáticas y cifradas). Pendiente: **confirmar plan con retención/PITR** adecuado y **registrar una prueba de restauración** (el plan gratuito retiene poco).
- Base de datos gestionada por Aiven (parcheado y endurecimiento del proveedor); API sin estado en Cloud Run; secretos en variables de entorno del servicio, fuera de git.
- Gestión de dispositivos (tablets): bloqueo, cifrado del dispositivo, borrado remoto, no persistencia local de datos sensibles [CONFIRMAR].
- Registro de accesos (logs) y monitorización.
- **Procedimiento de notificación de brechas** (arts. 33-34 RGPD): 72 h a la AEPD y, si alto riesgo, a los interesados; como encargado, Trazo notificará al responsable **sin dilación indebida** (art. 33.2). [DEFINIR protocolo y contactos.]
- **Riesgo residual:** [ ]

### Medidas frente a R6 (acceso entre centros / permisos)
- **Control de acceso por centro** (aislamiento multi-tenant): cada profesional solo ve su centro.
- Roles y permisos mínimos (RBAC); revisión periódica de accesos.
- Autenticación robusta [MFA — CONFIRMAR], política de contraseñas, expiración de sesiones.
- **Riesgo residual:** [ ]

### Medidas frente a R7 (transparencia / capacidad)
- Cláusula informativa **accesible y comprensible**; entrega a persona usuaria y a figura de apoyo/representante.
- Circuito documentado de información y, en su caso, consentimiento/apoyo conforme a Ley 8/2021 y arts. 13-14 RGPD.
- [Definir responsable y registro de entrega de la información.]
- **Riesgo residual:** [ ]

### Medidas frente a R8 (conservación / uso)
- **Política de conservación** con plazos definidos y **supresión o anonimización** al término.
- Prohibición contractual de usos incompatibles y de cesiones no previstas.
- **Riesgo residual:** [ ]

### Medidas frente a R9 (subencargados / ubicación)
- Alojamiento en **servicios gestionados del EEE**: API en Google Cloud Madrid; datos y backups en Aiven [CONFIRMAR región Aiven = EEE]; webs estáticas en Cloudflare (sin datos personales).
- **Firmar/archivar el DPA de cada subencargado** (Google Cloud, Aiven, Cloudflare) con las garantías del cap. V (SCCs / EU-US DPF) para cualquier acceso desde fuera del EEE. Autorización del responsable en el contrato de encargo.
- **Riesgo residual:** [ ]

### Medidas frente a R10 (continuidad)
- Plan de continuidad y recuperación; pruebas de restauración de backups; [RTO/RPO].
- [Plan de reversibilidad/portabilidad de datos al finalizar el contrato con Trazo.]
- **Riesgo residual:** [ ]

---

## 6. Consulta y valoraciones

- **DPO:** dictamen sobre esta EIPD (art. 35.2). [INCORPORAR informe del DPO.]
- **Interesados / representantes:** cuando proceda, recabar opiniones (art. 35.9) o justificar por qué no. [DOCUMENTAR.]
- **Encargado (Trazo):** información técnica aportada y compromisos de seguridad. [REFERENCIA.]
- **Consulta previa a la AEPD (art. 36 RGPD):** obligatoria **solo si**, pese a las medidas, subsiste un **alto riesgo residual**. Valoración de partida: [PENDIENTE — el DPO debe decidir. Con las medidas previstas, no debería ser necesaria, pero requiere confirmación.]

---

## 7. Conclusión y plan de acción

**Valoración global (borrador):** con las medidas de la sección 5 correctamente implantadas y evidenciadas, el riesgo residual se estima **[aceptable / pendiente de confirmación]**. Persisten puntos que **exigen decisión jurídica**: base jurídica y condición del art. 9, circuito de consentimiento/apoyo, posicionamiento como no producto sanitario, plazos de conservación y ubicación de subencargados.

| Acción pendiente | Responsable | Fecha límite | Estado |
|---|---|---|---|
| Validar base jurídica (art. 6) y condición art. 9 | DPO / Asesoría | [FECHA] | [ ] |
| Definir circuito de información/consentimiento y apoyo (Ley 8/2021) | DPO / Centro | [FECHA] | [ ] |
| Cifrado en reposo | Trazo | — | ✅ Cubierto (Aiven). Pendiente solo archivar DPA/certificaciones de Aiven |
| Gestión de tablets (revocación de dispositivo perdido) | Trazo | — | ✅ Implementado (token revocable desde el panel). MFA del panel: [valorar] |
| Definir plazos de conservación y borrado/anonimización | DPO / Centro | [FECHA] | [ ] Pendiente (ver propuesta en `04-…` / política de retención) |
| Confirmar región EEE de Aiven y firmar DPAs de subencargados (Google/Aiven/Cloudflare) | Trazo | [FECHA] | [ ] API en Madrid ✅; falta confirmar región Aiven y archivar DPAs |
| Aprobar cláusula informativa accesible | DPO | [FECHA] | [ ] |
| Protocolo de brechas (33-34) y contactos | DPO / Trazo | [FECHA] | [ ] |
| Decidir sobre consulta previa AEPD (art. 36) | DPO | [FECHA] | [ ] |

**Revisión:** esta EIPD debe **revisarse periódicamente** y **siempre que cambie el riesgo** que representa el tratamiento (art. 35.11): nuevas funcionalidades, cambios de proveedor, incidentes, cambios normativos.

---

### Anexos (a completar)
- **Anexo I** — Diagrama de flujos de datos.
- **Anexo II** — Registro de Actividades de Tratamiento (art. 30).
- **Anexo III** — Contrato de encargo de tratamiento (art. 28) Centro ↔ Trazo y subencargos.
- **Anexo IV** — Cláusula/política de información a interesados y modelo de consentimiento/apoyo.
- **Anexo V** — Política de seguridad, gestión de dispositivos y plan de continuidad.
- **Anexo VI** — Informe del DPO.

---

> **Recordatorio final:** documento **generado por IA con fines orientativos**. **No es asesoramiento jurídico.** Requiere revisión y adaptación por **abogado y/o DPO** antes de su uso. Complete todos los campos **[ENTRE CORCHETES]** y contraste cada valoración de riesgo con la realidad del tratamiento.
