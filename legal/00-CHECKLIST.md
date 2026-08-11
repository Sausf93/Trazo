# Checklist legal / RGPD para el piloto de Trazo

> ⚠️ **AVISO IMPORTANTE — LEER ANTES DE USAR**
> Este documento es un **BORRADOR ORIENTATIVO generado por una IA**. **NO es asesoramiento jurídico** ni sustituye la revisión de un profesional. Antes de arrancar el piloto con pacientes reales, **debe revisarlo y adaptarlo un abogado especializado en protección de datos y/o un DPO (Delegado de Protección de Datos)**. Los datos tratados son **datos de salud (categoría especial, art. 9 RGPD)** de **personas vulnerables**, muchas con capacidad de decisión modificada: el margen de error legal es muy bajo. Todos los campos a rellenar están marcados **[ENTRE CORCHETES]**.

**Contexto del caso (para quien revise):**
- **Modelo de roles:** el **CENTRO es RESPONSABLE del tratamiento**; **Trazo (la empresa) es ENCARGADO del tratamiento** (art. 28 RGPD).
- **Naturaleza del dato:** datos de salud / categoría especial (art. 9 RGPD) de personas mayores, mayoría con Alzheimer.
- **Qué hace la app:** pseudonimiza (alias interno; nombre real en tabla separada), mide **desempeño** en actividades, compara a cada persona consigo misma y avisa de cambios para revisión profesional. **No es diagnóstico ni producto sanitario.**
- **Infraestructura:** servidor propio, PostgreSQL, TLS, backups diarios (retención 14 días).
- **Modelo de negocio:** B2B, por paciente activo/mes.

---

## Índice de bloqueantes

| # | Bloqueante | Estado |
|---|------------|--------|
| 1 | Entidad jurídica, datos fiscales y sustitución de placeholders | ☐ Pendiente |
| 2 | Contrato de encargo del tratamiento (art. 28 RGPD) | ☐ Pendiente |
| 3 | Consentimiento informado + representante legal (capacidad modificada) | ☐ Pendiente |
| 4 | DPIA / EIPD (Evaluación de Impacto, art. 35 RGPD) | ☐ Pendiente |
| 5 | Cifrado en reposo de la base de datos y de los backups | ☐ Pendiente |
| 6 | Arrancar producción y probar restauración de backup | ☐ Pendiente |

> Regla práctica: **1, 2, 4 y 5 deben estar cerrados ANTES de introducir el primer dato real**. El 3 debe estar firmado **antes de dar de alta a cada paciente**. El 6 debe estar probado **antes de considerar el sistema operativo**.

---

## 1. Entidad jurídica, datos fiscales y sustitución de placeholders

**Qué es.** Trazo, como encargado del tratamiento, necesita ser una **persona (física o jurídica) identificable y responsable en derecho**. Hoy el aviso legal y la política de privacidad tienen huecos sin rellenar (`[Razón social o nombre del titular]`, `[NIF/CIF pendiente]`, `[Dirección postal pendiente]`) y el único contacto es un correo de Gmail personal.

**Por qué es obligatorio.**
- La **LSSI-CE (Ley 34/2002)** obliga a que el titular del sitio web esté plenamente identificado (razón social, NIF/CIF, domicilio, contacto).
- Un contrato de encargo (bloqueante 2) **no puede firmarlo un titular indeterminado**: el centro necesita saber a quién responsabiliza.
- Sin entidad definida, la responsabilidad recae de forma personal e ilimitada sobre la persona física, lo que es un riesgo grave tratando datos de salud.

**Pasos concretos.**
- [ ] Decidir la **forma jurídica** con un asesor: autónomo (persona física) vs. sociedad (típicamente **S.L.**). Para tratar datos de salud de terceros y vender B2B, valorar **S.L.** por limitación de responsabilidad. Decisión: **[FORMA JURÍDICA ELEGIDA]**.
- [ ] Constituir/dar de alta la entidad y obtener: razón social **[RAZÓN SOCIAL]**, **[NIF/CIF]**, **[DOMICILIO FISCAL]**.
- [ ] Dar de alta un **correo de contacto corporativo** (p. ej. `privacidad@trazo.app` o `[CORREO CORPORATIVO]`) y **dejar de usar el Gmail personal** en documentos legales.
- [ ] Sustituir los placeholders en:
  - `apps/landing/aviso-legal.html` → sección "1. Titular del sitio web" (razón social, NIF/CIF, domicilio; sustituir `saulodlsf@gmail.com`).
  - `apps/landing/privacidad.html` → sección "1. Responsable del tratamiento" y todos los `mailto:saulodlsf@gmail.com` (secciones 1 y 6).
- [ ] Retirar el banner "Borrador pendiente de revisión legal antes de publicar" **solo cuando el DPO/abogado dé el visto bueno** al texto definitivo.
- [ ] Revisar con el asesor si procede designar formalmente un **DPO** (ver bloque 4) e incluir sus datos de contacto en la política de privacidad.
- [ ] Confirmar la **titularidad del dominio** `trazo.app` (o el que se use) a nombre de la entidad: **[DOMINIO]**.

---

## 2. Contrato de encargo del tratamiento (art. 28 RGPD)

**Qué es.** El documento que regula que **el centro (responsable) encarga a Trazo (encargado)** el tratamiento de datos personales por cuenta del centro. Es un contrato firmado, con contenido mínimo tasado por el art. 28.3 RGPD.

**Por qué es obligatorio.**
- El art. 28 RGPD **prohíbe** que un encargado trate datos por cuenta de un responsable sin un contrato (o acto jurídico) que lo vincule. Sin él, el tratamiento es ilícito desde el primer registro.
- Tratándose de **datos de salud de personas vulnerables**, es uno de los primeros documentos que exigirá cualquier centro serio y la primera pieza que revisaría la AEPD ante una inspección o incidente.

**Pasos concretos.**
- [ ] Redactar el contrato (o Anexo de Tratamiento de Datos / DPA) con abogado. Debe incluir como mínimo (art. 28.3):
  - [ ] **Objeto, duración, naturaleza y finalidad** del tratamiento.
  - [ ] **Tipo de datos** (identificativos pseudonimizados + datos de salud/desempeño) y **categorías de interesados** (personas usuarias del centro; también profesionales usuarios de la app).
  - [ ] Tratar los datos **solo siguiendo instrucciones documentadas** del responsable.
  - [ ] **Confidencialidad** del personal de Trazo con acceso a los datos.
  - [ ] **Medidas de seguridad** del art. 32 (enlazar/anexar las técnicas y organizativas: TLS, pseudonimización, cifrado en reposo del bloque 5, control de accesos, backups).
  - [ ] Régimen de **subencargados** (p. ej. proveedor de hosting/servidor): autorización previa del responsable y traslado de las mismas obligaciones. Listar los actuales: **[PROVEEDOR DE HOSTING / SERVIDOR]**, **[OTROS SUBENCARGADOS]**.
  - [ ] **Asistencia al responsable** para atender derechos de los interesados (acceso, rectificación, supresión, etc.) y para el cumplimiento de los arts. 32-36.
  - [ ] **Notificación de brechas** de seguridad al responsable **sin dilación indebida** (definir plazo, p. ej. **[24-72 h]**).
  - [ ] **Devolución o supresión** de los datos al finalizar (elegir opción) y borrado de copias.
  - [ ] Permitir y contribuir a **auditorías/inspecciones** del responsable.
  - [ ] **Ausencia de transferencias internacionales** fuera del EEE (o, si las hubiera, garantías del cap. V RGPD). Confirmar que el servidor está en **[UBICACIÓN DEL SERVIDOR — debe estar en EEE]**.
- [ ] Preparar una **plantilla estándar** que el centro pueda revisar y firmar (facilita la venta B2B).
- [ ] **Firmar con el centro del piloto ANTES de cargar datos reales**. Centro: **[NOMBRE DEL CENTRO]**, firmante: **[REPRESENTANTE DEL CENTRO]**, fecha: **[FECHA]**.
- [ ] Confirmar por escrito quién ejerce de **DPO del centro** y establecer el canal de comunicación entre DPOs/responsables.
- [ ] Verificar que el centro dispone de su propia base de legitimación y de su **Registro de Actividades de Tratamiento (RAT)**; Trazo, como encargado, debe llevar también su **RAT de encargado** (art. 30.2 RGPD).

---

## 3. Consentimiento informado + representante legal (capacidad modificada)

**Qué es.** La información y, en su caso, el consentimiento (o base jurídica alternativa) que legitima tratar los datos de salud de cada persona usuaria. Como muchas personas tienen la **capacidad de decisión modificada** (Alzheimer), interviene el **representante legal / guardador de hecho / titular de medidas de apoyo**.

**Por qué es obligatorio.**
- Los datos de salud son **categoría especial (art. 9 RGPD)**: su tratamiento está prohibido salvo que concurra una excepción del art. 9.2 (consentimiento explícito, fines de asistencia sanitaria/social, etc.). Hay que **fijar y documentar** cuál aplica.
- Debe cumplirse el **deber de información** (arts. 13-14 RGPD): quién trata, para qué, base jurídica, plazos, derechos, destinatarios.
- Con **capacidad modificada**, un consentimiento firmado por la propia persona sin capacidad para otorgarlo **no es válido**; hay que articular la intervención del apoyo/representante y, cuando sea posible, **la participación de la persona** conforme a la Ley 8/2021 (reforma de la discapacidad: se prioriza la voluntad y preferencias de la persona con los apoyos necesarios).

**Pasos concretos.**
- [ ] **Definir con el abogado/DPO la base jurídica del art. 9.2** para el piloto (habitualmente: consentimiento explícito del interesado o su representante, y/o art. 9.2.h — asistencia social/sanitaria por profesional sujeto a secreto). Base elegida: **[BASE JURÍDICA ART. 9.2]**.
- [ ] **El centro (responsable) es quien recaba el consentimiento**, no Trazo. Trazo aporta la **plantilla y la cláusula informativa**; el centro la usa e integra en su circuito.
- [ ] Redactar una **hoja de información + consentimiento** en lenguaje claro y accesible que cubra:
  - [ ] Identidad del **responsable (el centro)** y del **encargado (Trazo)**.
  - [ ] Finalidad real: **medir desempeño en actividades y avisar de cambios para revisión profesional**. Dejar explícito que **NO es diagnóstico ni producto sanitario** y que **no sustituye la valoración clínica**.
  - [ ] Categorías de datos, plazo de conservación y **pseudonimización** (alias interno; nombre real en tabla separada).
  - [ ] Derechos RGPD y cómo ejercerlos; derecho a **retirar el consentimiento** sin consecuencias asistenciales.
  - [ ] Carácter **voluntario** de la participación en el piloto.
- [ ] Crear un **circuito de firma por representante**:
  - [ ] Identificar para cada paciente si hay **sentencia/medida de apoyo, tutela, curatela o guarda de hecho** y quién es el representante. Registrar: **[REPRESENTANTE POR PACIENTE]**.
  - [ ] Recabar la firma del representante y, cuando la persona conserve capacidad para comprender, **informarla y recoger su asentimiento** en la medida de lo posible.
  - [ ] Conservar copia del **documento que acredita la representación**.
- [ ] Establecer un **registro de consentimientos** (quién, cuándo, versión de la hoja informativa firmada) para poder **demostrar** el cumplimiento (accountability, art. 5.2).
- [ ] **No dar de alta a ningún paciente en la app hasta tener su consentimiento/representación documentado.**
- [ ] Prever el procedimiento de **baja y borrado** cuando se retire el consentimiento o finalice el piloto.

---

## 4. DPIA / EIPD — Evaluación de Impacto (art. 35 RGPD)

**Qué es.** Un análisis documentado del riesgo que el tratamiento supone para los derechos y libertades de las personas, con las medidas para mitigarlo.

**Por qué es obligatorio.**
- El art. 35 RGPD exige EIPD cuando el tratamiento **entrañe alto riesgo**. Aquí concurren **varios criterios que la disparan**: **datos de categoría especial** (salud), **sujetos vulnerables** (mayores con deterioro cognitivo), **evaluación/scoring** del desempeño y **datos a gran escala** si escala a varios centros.
- El tratamiento encaja en la **lista de la AEPD** de tratamientos que requieren EIPD (datos de salud + colectivos vulnerables). Realizarla **antes** de iniciar el tratamiento es obligatorio, no opcional.
- **Titular formal de la EIPD:** el **responsable (el centro)**. Pero Trazo, como fabricante/encargado, debe **proporcionar la información técnica** y lo más práctico es que **aporte una EIPD-plantilla** que el centro adopte y adapte. Aclarar el reparto con el DPO.

**Pasos concretos.**
- [ ] Usar una metodología reconocida (**Guía de EIPD de la AEPD** y/o la herramienta **PIA de la CNIL**).
- [ ] **Describir el tratamiento** de forma sistemática: flujos de datos (tablet → API → PostgreSQL), finalidades, roles, categorías de datos, conservación, subencargados.
- [ ] Evaluar **necesidad y proporcionalidad**: minimización (¿se recogen solo los datos imprescindibles?), pseudonimización, base jurídica.
- [ ] **Identificar y valorar riesgos** para los interesados: reidentificación, acceso no autorizado, uso indebido del desempeño como si fuera diagnóstico, brechas, pérdida de datos.
- [ ] **Medidas de mitigación** (enlazar con bloques 2, 3, 5): pseudonimización con nombre real en tabla separada, control de accesos por rol, TLS en tránsito, **cifrado en reposo (bloque 5)**, backups probados (bloque 6), registro de accesos, formación del personal, limitación de finalidad ("no es diagnóstico").
- [ ] Determinar el **riesgo residual**. Si tras las medidas sigue siendo **alto**, procede **consulta previa a la AEPD** (art. 36) antes de tratar.
- [ ] **Documentar, fechar y firmar** la EIPD; revisarla si cambia el tratamiento o al menos periódicamente. Responsable de la EIPD: **[NOMBRE / DPO]**, fecha: **[FECHA]**.
- [ ] Valorar la **designación de un DPO** (art. 37): dado el tratamiento a gran escala de datos de salud, es muy probablemente **obligatorio**. Decisión y datos: **[DPO DESIGNADO]**.

---

## 5. Cifrado en reposo de la base de datos y de los backups

**Qué es.** Que los datos almacenados en disco (la base de datos PostgreSQL y los ficheros de backup) estén **cifrados**, de modo que quien acceda físicamente al disco o robe una copia **no pueda leerlos**.

**Por qué es obligatorio.**
- El **art. 32 RGPD** exige medidas de seguridad adecuadas al riesgo y **cita expresamente el cifrado y la pseudonimización**. Con datos de salud, el estándar exigible es alto.
- Hoy la infraestructura tiene **TLS (cifrado en tránsito)** y backups, pero **el cifrado en reposo no está confirmado**: los backups se guardan como `.sql.gz` en `./backups` y también se copian fuera del servidor, lo que **multiplica los puntos donde una copia sin cifrar podría filtrarse**.
- Si hay una brecha y los datos estaban cifrados en reposo, el impacto (y las obligaciones de notificación a los interesados) se reduce sustancialmente.

**Pasos concretos.**
- [ ] **Cifrado del volumen/disco del servidor** donde vive PostgreSQL: activar **cifrado a nivel de disco** (LUKS en Linux, o el cifrado de volúmenes del proveedor cloud si aplica). Confirmar: **[MÉTODO DE CIFRADO DE DISCO]**.
- [ ] **Cifrar los backups** antes de que salgan del servidor: cifrar cada `trazo-AAAAMMDD-HHMMSS.sql.gz` (p. ej. con **GPG/age** o cifrado del destino de almacenamiento) y **custodiar la clave por separado**, nunca junto a la copia. Actualizar el paso de backup en `docker-compose.prod.yml` / el servicio `backup`.
- [ ] Verificar que **el volumen de la BD y el directorio `./backups` no están expuestos** ni son legibles por otros usuarios/servicios del host.
- [ ] Cifrar (o proteger equivalentemente) **la copia externa** de `./backups` que la guía recomienda sacar del servidor. Destino externo: **[UBICACIÓN COPIA EXTERNA]**.
- [ ] **Gestión de claves y secretos**: `.env.prod` (contiene `JWT_SECRET`, `POSTGRES_PASSWORD`) **fuera de git**, con permisos restringidos; definir custodia y rotación de claves. Responsable de claves: **[RESPONSABLE]**.
- [ ] (Opcional, según valoración) Cifrado a nivel de columna para el dato más sensible (p. ej. la tabla que enlaza alias ↔ nombre real) con `pgcrypto`, si el DPO lo considera proporcionado.
- [ ] **Documentar** todas estas medidas en el anexo de seguridad del contrato (bloque 2) y en la EIPD (bloque 4).

---

## 6. Arrancar producción y probar la restauración de backup

**Qué es.** Poner el backend en el servidor de producción siguiendo `DESPLIEGUE.md` y **verificar que un backup se puede restaurar realmente**.

**Por qué es obligatorio.**
- El art. 32 RGPD exige garantizar la **disponibilidad y resiliencia** de los sistemas y la **capacidad de restaurar** el acceso a los datos tras un incidente. Una copia **que nunca se ha restaurado no es una copia fiable** (la propia guía de despliegue lo advierte).
- Perder los datos de desempeño de pacientes con deterioro cognitivo, sin copia recuperable, sería un incidente de disponibilidad grave y notificable.

**Pasos concretos.**
- [ ] Desplegar según `DESPLIEGUE.md`: crear `.env.prod` (fuera de git) con `JWT_SECRET` generado (`openssl rand -hex 32`), `POSTGRES_PASSWORD` fuerte, `DOMINIO`, `ACME_EMAIL`, `CORS_ORIGINS`.
- [ ] Levantar con `docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build`.
- [ ] Comprobar que **HTTPS funciona** (`https://TU_DOMINIO/health` → `{"status":"ok","database":"up"}`) y que la BD **no está expuesta** al exterior.
- [ ] Confirmar que **`ENTORNO=prod`**: la BD arranca **sin datos de demo**. Crear el primer centro y cuenta con el comando de **bootstrap**.
- [ ] Verificar que el **servidor está físicamente en el EEE** y que el cifrado en reposo (bloque 5) está activo **antes de introducir el primer dato real**.
- [ ] **Prueba de restauración (imprescindible):**
  - [ ] Restaurar un backup en un entorno de prueba: `gunzip -c backups/trazo-AAAAMMDD-HHMMSS.sql.gz | docker compose -f docker-compose.prod.yml exec -T db psql -U trazo -d trazo`.
  - [ ] **Validar** que los datos restaurados están completos y son coherentes.
  - [ ] Si los backups van cifrados (bloque 5), probar el **flujo completo con descifrado**.
  - [ ] **Registrar** fecha, responsable y resultado de la prueba. Última prueba: **[FECHA]**, responsable: **[NOMBRE]**, resultado: **[OK/KO]**.
- [ ] Verificar que la **copia externa** de `./backups` se genera y también es restaurable.
- [ ] Definir por escrito **RPO/RTO** del piloto (cada cuánto se pierde como máximo / cuánto se tarda en recuperar): **[RPO]** / **[RTO]**.
- [ ] Establecer un **procedimiento de gestión de brechas** (detección, contención, evaluación, notificación a la AEPD en 72 h y a los interesados si procede) y designar responsable: **[RESPONSABLE DE INCIDENTES]**.

---

## Resumen de campos [ENTRE CORCHETES] a rellenar

- **Entidad:** [FORMA JURÍDICA], [RAZÓN SOCIAL], [NIF/CIF], [DOMICILIO FISCAL], [CORREO CORPORATIVO], [DOMINIO].
- **Encargo (art. 28):** [NOMBRE DEL CENTRO], [REPRESENTANTE DEL CENTRO], [PROVEEDOR DE HOSTING/SERVIDOR], [OTROS SUBENCARGADOS], [UBICACIÓN DEL SERVIDOR — EEE], [PLAZO NOTIFICACIÓN BRECHAS], [FECHA FIRMA].
- **Consentimiento:** [BASE JURÍDICA ART. 9.2], [REPRESENTANTE POR PACIENTE].
- **DPIA / DPO:** [RESPONSABLE EIPD], [FECHA EIPD], [DPO DESIGNADO].
- **Cifrado:** [MÉTODO DE CIFRADO DE DISCO], [UBICACIÓN COPIA EXTERNA], [RESPONSABLE DE CLAVES].
- **Producción/backups:** [FECHA PRUEBA RESTAURACIÓN], [RESPONSABLE], [RESULTADO], [RPO], [RTO], [RESPONSABLE DE INCIDENTES].

---

*Documento generado como borrador orientativo. Requiere validación por abogado y/o DPO antes de su uso con datos reales. Referencias normativas: RGPD (UE) 2016/679 (arts. 5, 6, 9, 13-14, 28, 30, 32, 35-36, 37), LOPDGDD 3/2018, LSSI-CE 34/2002, Ley 8/2021 (apoyos a personas con discapacidad), guías y listas de la AEPD.*
