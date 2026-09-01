# Anexo de medidas técnicas y organizativas (art. 32 RGPD) e infraestructura

> ⚠️ **BORRADOR TÉCNICO generado y verificado contra el código y la infraestructura reales de Trazo (2026-09).** Describe las medidas de seguridad para anexar al **contrato de encargo (art. 28)** y a la **DPIA (art. 35)**. **No es asesoramiento jurídico**; debe revisarlo el DPO/abogado. Los puntos que dependen de una cuenta o configuración concreta (regiones de proveedor, DPAs firmados) están marcados **[CONFIRMAR]**.

Este anexo sustituye la descripción de infraestructura del `00-CHECKLIST.md` que aún mencionaba un despliegue **autoalojado** (servidor propio + `docker-compose` + `./backups` + LUKS manual). **Esa arquitectura ya no se usa.** Trazo funciona hoy sobre **servicios gestionados en la nube**, lo que **cambia sustancialmente el bloqueante de cifrado en reposo (#5)**: pasa de "hay que montarlo" a "lo provee la plataforma por defecto; hay que documentarlo y firmar el DPA del proveedor".

---

## 1. Arquitectura real y ubicación de los datos (residencia EEE)

| Pieza | Proveedor / servicio | Rol respecto a datos personales | Ubicación |
|---|---|---|---|
| **API** (backend) | **Google Cloud Run** (proyecto `trazo-505414`) | Procesa peticiones; **no almacena** datos de forma persistente (contenedor efímero, sin disco de estado) | **`europe-southwest1` = Madrid (España, EEE)** |
| **Base de datos** | **Aiven for PostgreSQL** | **Único almacén persistente** de datos personales y de salud/desempeño | **[CONFIRMAR región Aiven = EEE]** (p. ej. `google-europe-west1`/Madrid) |
| **Frontends** (panel web, tablet web, vitrina, superadmin) | **Cloudflare Pages** | Sirven **código estático** (HTML/JS). **No almacenan datos personales**; el navegador habla directamente con la API por HTTPS | CDN global (solo estáticos, sin datos personales en reposo) |
| **Registro de imágenes** | Google Artifact Registry | Imagen de contenedor de la API (sin datos personales) | `europe-southwest1` (Madrid) |

**Punto clave para la DPIA/DPA:** el **único lugar donde residen datos personales es la base de datos de Aiven**. Cloud Run es sin estado (el catálogo se re-sincroniza en cada arranque, no hay datos de personas en la imagen) y Cloudflare solo distribuye ficheros estáticos. Esto **reduce y concentra la superficie** a un solo proveedor de datos, lo que simplifica el análisis de riesgo.

**Acción [CONFIRMAR]:** verificar en el panel de Aiven que la **región del servicio está en el EEE**. Si estuviera fuera, migrar el servicio a una región EEE **antes del primer dato real** (evita transferencias internacionales del art. 44+).

---

## 2. Cifrado (art. 32.1.a) — cierra el bloqueante #5

### En tránsito
- **TLS** en todas las comunicaciones: navegador↔API (HTTPS gestionado por Cloud Run) y API↔base de datos (`sslmode=require`, forzado en `backend/api/app/database.py`).

### En reposo — **cubierto por defecto por Aiven**
Según la documentación de seguridad de Aiven, el cifrado en reposo cubre **tanto las instancias activas como los backups**:
- **Datos activos y volúmenes:** cifrado de volumen completo con **LUKS** y **clave efímera aleatoria por instancia/volumen**, destruida al destruir la instancia.
- **Backups:** cifrados con **clave aleatoria por fichero**, las claves protegidas con par **RSA (KEK)**, y el cifrado de fichero con **AES-256 en modo CTR + HMAC-SHA256** (integridad).
- Aiven declara cumplimiento **ISO 27001, RGPD, HIPAA, PCI-DSS**.

**Consecuencia:** los datos de salud/desempeño **y** los documentos legales escaneados (que se guardan como base64 **dentro de la propia base de datos**, tabla `documentos_legales`) **están cifrados en reposo** por el cifrado de volumen de Aiven. No se requiere LUKS manual ni cifrado de backups a mano.

**Defensa en profundidad (opcional, no obligatoria):** si el DPO lo considera proporcionado, se puede añadir **cifrado a nivel de aplicación** para el dato más sensible (la tabla `datos_identificativos` que enlaza alias↔nombre real, o los documentos escaneados con DNI) con una clave en secreto de Cloud Run. Hoy **no es un incumplimiento** no tenerlo, porque el volumen ya está cifrado.

**Acción [CONFIRMAR]:** descargar y archivar el **DPA de Aiven** y su **declaración de cifrado/certificaciones** como evidencia (adjuntar al expediente).

---

## 3. Pseudonimización (art. 32.1.a, art. 25) — medida destacada

- La persona mayor se identifica en el trabajo diario **solo por un alias interno** (`usuarios_finales.alias_interno`). **No hay nombre real** en esa tabla.
- El **nombre real y datos identificativos** viven en una **tabla separada de acceso restringido** (`datos_identificativos`), que las consultas de trabajo (intentos, evolución, alertas, informes internos) **nunca tocan**.
- El histórico clínico-funcional (intentos, desempeño) está ligado al `usuario_final_id` **pseudonimizado**, no al nombre.
- **Derecho de supresión (art. 17):** al suprimir, se **borra** el nombre real, los consentimientos y los documentos escaneados, y **el histórico se conserva DISOCIADO** (estadística sin identidad). Es una anonimización real del vínculo, no un borrado que destruya la evidencia estadística.

---

## 4. Control de acceso y autenticación (art. 32.1.b)

- **Autenticación:** contraseñas con **bcrypt**; sesiones con **JWT** firmado (`JWT_SECRET` en secreto de Cloud Run).
- **Roles (RBAC):** `plataforma` (super-admin), `admin_centro`, personal clínico (integradora, psicóloga, terapeuta ocupacional, integradora social), `familia` (solo consulta). Cada endpoint exige el rol adecuado.
- **Aislamiento multi-tenant:** **todo** va scoped por `centro_id`, con anti-IDOR en cada endpoint (`usuario_del_centro`, `acceso_centro` revalida el centro activo en cada petición). Un centro **no puede ver datos de otro**. Verificado con pruebas E2E de aislamiento (`ecosistema_e2e.py`: 3 centros × 5 profesionales × 20 personas, 12 salas simultáneas → 43/0).
- **Tablets:** se emparejan **desde el panel** (personal autenticado) y usan un **token de dispositivo** por petición (`X-Device-Token`), **revocable** al instante desde la web si se pierde una tablet.
- **Suspensión de centro:** la plataforma puede suspender un centro; el login se corta con 403 en cada petición.

---

## 5. Registro de actividad / trazabilidad (art. 30, art. 32)

- **Registro de auditoría** (`RegistroAuditoria`) en cada acción sensible: alta/edición/baja/supresión de personas, registro de consentimiento, subida/descarga/borrado de documentos legales, exportación CSV. Queda **quién, qué, cuándo**.

---

## 6. Derechos de los interesados (arts. 15-20) — asistencia al responsable (art. 28.3.e)

- **Acceso / portabilidad (art. 20):** exportación **CSV** de los intentos, scoped por centro y auditada (`/export/intentos.csv`).
- **Rectificación (art. 16):** edición de alias y de nombre real (este último va a la tabla restringida).
- **Supresión (art. 17):** disociación descrita en §3, restringida a `admin_centro`.
- **Gestión de consentimiento por persona**, con rol del otorgante (titular / representante legal / tutor / guardador de hecho) para **capacidad modificada**, y archivo del documento firmado.

Trazo, como **encargado**, aporta estas herramientas para que el **centro (responsable)** atienda los derechos.

---

## 7. Disponibilidad y resiliencia (art. 32.1.c) — reencuadra el bloqueante #6

- **Backups gestionados por Aiven** (automáticos, cifrados como en §2), con recuperación **point-in-time** según el plan del servicio. **[CONFIRMAR]** el plan de Aiven y su ventana de retención/PITR; el plan *free* tiene retención limitada — para producción con datos reales, **valorar un plan de pago** con retención y PITR adecuados.
- **Base de datos idempotente al arranque:** el backend crea tablas y migra columnas/índices de forma **aditiva** en cada despliegue (`migraciones.py`), con **lock de arranque anti-carrera** en producción. No hay scripts manuales que puedan dejar la BD a medias.
- **Prueba de restauración:** planificar y **registrar** una prueba de restauración desde Aiven (fecha, responsable, resultado) antes de considerar el sistema operativo. Definir **RPO/RTO** con el plan de Aiven elegido. **[CONFIRMAR]**

---

## 8. Subencargados del tratamiento (art. 28.2 y 28.4)

Trazo, como encargado, se apoya en estos **subencargados**; el contrato de encargo debe **listarlos y autorizarlos**, y cada uno debe tener su propio DPA firmado:

| Subencargado | Servicio | Datos que trata | DPA / garantías |
|---|---|---|---|
| **Google Cloud EMEA / Ireland** | Cloud Run + Artifact Registry (Madrid) | Procesamiento efímero de las peticiones a la API | DPA de Google Cloud + SCCs; región EEE (Madrid) |
| **Aiven** | PostgreSQL gestionado | **Almacenamiento** de todos los datos personales y de salud | **[CONFIRMAR]** DPA de Aiven firmado; región EEE; ISO 27001/HIPAA/RGPD |
| **Cloudflare** | Pages (frontends estáticos) | **Solo estáticos**; no almacena datos personales de la app | DPA de Cloudflare + SCCs |

**Acción [CONFIRMAR]:** firmar/descargar el **DPA de cada proveedor** y archivarlo. Confirmar que **ninguno** implica una **transferencia fuera del EEE** sin garantías del cap. V (SCCs). Si algún proveedor procesa fuera del EEE, documentar las SCCs correspondientes.

---

## 9. Gestión de secretos

- Los secretos (`JWT_SECRET`, `DATABASE_URL` con credenciales de Aiven, `PLATFORM_TOKEN`) viven como **variables de entorno del servicio Cloud Run**, **no en git**.
- El token puntual de Cloudflare para desplegar se guarda fuera de git y se revoca tras su uso.
- **Acción [CONFIRMAR]:** definir por escrito el **responsable de claves** y la política de **rotación** (JWT_SECRET, credenciales de Aiven, PLATFORM_TOKEN).

---

## 10. Limitación de finalidad (art. 5.1.b) — medida organizativa clave

- Trazo mide **desempeño en actividades** y avisa de **cambios respecto a la propia base** de la persona para **revisión profesional**. **No es diagnóstico ni producto sanitario** y **no sustituye la valoración clínica**. Esta limitación debe constar en el consentimiento, en la DPIA y en la información a la familia, y está reflejada en el propio diseño clínico del producto (el intento nace `sin_valorar`; se mide desempeño, no "deterioro").

---

## Resumen para el expediente

- **Cifrado en reposo (#5): CUBIERTO** por Aiven (LUKS/AES-256 en datos y backups). Falta **documentarlo** y archivar el DPA de Aiven. *(Deja de ser un bloqueante de ingeniería.)*
- **Residencia EEE:** API en Madrid; **[CONFIRMAR] región de Aiven en EEE**.
- **Backups/restauración (#6):** gestionados por Aiven; **[CONFIRMAR] plan con PITR** y **registrar una prueba de restauración**.
- **Pseudonimización, RBAC, multi-tenant, auditoría, derechos, portabilidad, supresión:** implementados y verificados en código.
- **Subencargados:** Google Cloud, Aiven, Cloudflare — **firmar/archivar sus DPAs**.

*Referencias: RGPD (UE) 2016/679 arts. 5, 25, 28, 30, 32, 44+; documentación de seguridad de Aiven (cifrado en reposo LUKS/AES-256 de datos y backups; certificaciones ISO 27001/RGPD/HIPAA); Google Cloud (cifrado en reposo AES-256 por defecto). A validar por DPO/abogado.*
