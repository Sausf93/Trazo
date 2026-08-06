# Trazo — Especificación técnica para arrancar el desarrollo

> Documento de arranque para pegar en Claude Code (u otro asistente de código) y empezar a construir. Incluye stack, arquitectura, modelo de datos, y un prompt final listo para usar.

---

## 1. Visión del proyecto

Trazo es una herramienta de estimulación cognitiva para personas mayores (mayoría con Alzheimer) en centros de día. Combina:
- Una **app de tablet** con ejercicios de 8 dominios cognitivos (atención/memoria, lenguaje, razonamiento, gnosias, praxias, percepción, función ejecutiva, vida cotidiana).
- Un **panel web** para el centro, con evolución por persona y por grupo.
- Un **motor de detección temprana**: si el rendimiento o la ayuda necesitada se sale del patrón habitual de una persona, se marca para revisión profesional.

El objetivo no es que mejoren siempre — es que no empeoren sin que nadie se dé cuenta a tiempo.

---

## 2. Stack tecnológico recomendado

| Componente | Tecnología | Por qué |
|---|---|---|
| App tablet | **Flutter** | El núcleo del producto es capturar trazo a mano con precisión (velocidad, desviación). Flutter dibuja con motor propio (Skia), no depende de widgets nativos por plataforma — rendimiento consistente incluso en tablets Android antiguas/baratas. Un solo código para Android/iPad. Offline-first robusto con `sqflite`/`drift`. |
| Backend | **FastAPI (Python) + PostgreSQL** | Reutilizas tu experiencia previa (bot de trading). Async nativo, tipado con Pydantic, fácil desplegar en Oracle Cloud igual que ya haces. PostgreSQL en vez de SQLite desde el día 1: aquí hay escrituras concurrentes desde varias tablets a la vez y datos de salud — quieres integridad ACID real, no un archivo. |
| Web dashboard | **React + TypeScript + Vite** | Ligero, rápido de montar, buen ecosistema de gráficas (Recharts). Si más adelante quieres una web pública de marketing para captar otros centros, se puede migrar a Next.js sin reescribir toda la lógica. |
| Infraestructura | **Oracle Cloud Free Tier + Coolify** | Mismo patrón que ya usas — reutilizas conocimiento de despliegue. |
| Comunicación en tiempo real (panel en vivo) | **Polling cada 3-5s al principio**, WebSocket (FastAPI lo soporta nativo) si hace falta más adelante | No sobre-construir desde el día 1. Con pocos usuarios por sesión, polling simple es suficiente y mucho menos complejo de depurar. |
| Autenticación | JWT emitido por FastAPI, roles (integradora / admin centro / familia opcional) | Mismo patrón que tu dashboard de trading, ya lo conoces. |

---

## 3. Decisión de arquitectura clave: motor de ejercicios data-driven

**Esto es lo más importante de todo el documento.** Ahora mismo tienes ~30 ejercicios repartidos en 8 bloques, y la lista sigue creciendo cada vez que hablas con tu pareja. Si cada ejercicio es una pantalla de código distinta, en 3 meses tienes un código inmantenible.

En vez de eso, define **tipos de ejercicio reutilizables** (plantillas), y cada ejercicio concreto es solo una configuración de datos sobre esa plantilla:

| Tipo de plantilla | Ejercicios que cubre |
|---|---|
| `trazo` | Grafomotricidad, copiar figuras, unir puntos, copiar patrón, completar dibujo |
| `seleccion_multiple` | El intruso, palabra e imagen, cómo se llama esto, cuál es igual, el rasgo que falta, qué sonido es, solo un trozo |
| `memoria_visual` | Memoria de figuras, la lista corta |
| `secuencia_ordenar` | Ordenar pasos de una tarea, vestirse en orden, seguir la serie |
| `conteo_comparacion` | Cuál tiene más, cuenta cuántos hay, cuenta y suma sin decir suma, de mayor a menor |
| `arrastrar_posicion` | Poner la mesa, encaja la pieza, la lista de la compra |
| `evocacion_libre` | Objetos por categoría, palabras por sílaba, completar refranes |
| `manejo_cantidad` | Dinero, la vuelta, qué hora marca |

Cada plantilla define: qué datos necesita (imágenes, cantidad objetivo, rango de dificultad), qué mide (precisión, tiempo, desviación), y cómo se renderiza. Un ejercicio nuevo entero puede ser **una fila en una tabla de configuración**, no una pantalla nueva de código. Esto es lo que hace viable seguir añadiendo ejercicios sin que el proyecto se vuelva imposible de mantener.

---

## 4. Modelo de datos (entidades principales)

```
centros
  id, nombre, activo

usuarios_staff (integradoras, admin)
  id, centro_id, nombre, rol, email, password_hash

usuarios_finales (personas mayores — pseudonimizados)
  id, centro_id, alias_interno, fecha_alta, nivel_base_json, activo
  -- nombre real y datos identificativos en tabla separada con acceso restringido

consentimientos
  id, usuario_final_id, tipo, fecha, otorgado_por, documento_ref

sesiones
  id, centro_id, fecha, tipo (individual/grupo), staff_id

sesion_participantes
  sesion_id, usuario_final_id

ejercicios_catalogo
  id, bloque (atencion_memoria / lenguaje / razonamiento / gnosias / praxias / percepcion / funcion_ejecutiva / vida_cotidiana)
  plantilla_tipo, nombre, descripcion, parametros_json, activo

intentos
  id, usuario_final_id, sesion_id, ejercicio_id
  timestamp_inicio, timestamp_fin
  estado (solo / con_ayuda / no_completado)
  valores_json (métricas específicas del tipo de ejercicio: precisión, tiempo, desviación...)
  cantidad_objetivo_json (qué cantidades se usaron esa vez, por la dificultad cambiante)

alertas
  id, usuario_final_id, fecha_generada, tipo (individual / grupo)
  bloque_afectado, descripcion, revisada_por, fecha_revision, resultado
```

---

## 5. Endpoints API principales (FastAPI)

```
POST   /auth/login
GET    /centros/{id}/usuarios
POST   /usuarios                          # alta de usuario final (pseudonimizado)

GET    /ejercicios?bloque=&activo=
POST   /ejercicios                        # crear/editar plantilla de ejercicio

POST   /sesiones                          # crear sesión (individual o grupo)
GET    /sesiones/{id}/live                # estado en vivo para vista facilitadora (polling)
POST   /sesiones/{id}/intentos            # registrar un intento
PATCH  /intentos/{id}/estado              # marcar "con ayuda" / "no completado" desde control facilitador

GET    /usuarios/{id}/evolucion?bloque=&desde=&hasta=
GET    /usuarios/{id}/alertas
GET    /grupos/{sesion_id}/evolucion

GET    /alertas?centro_id=&revisada=false
PATCH  /alertas/{id}/revisar
```

---

## 6. App tablet (Flutter) — especificación funcional

**Modo participante**
- Pantalla completa, un ejercicio a la vez, sin menús ni navegación visible.
- Feedback inmediato visual/sonoro, nunca mensajes de "has fallado".
- Registro silencioso de trazo/interacción según el tipo de plantilla.
- Offline-first: todo se guarda en SQLite local con UUID generado en el cliente; sincroniza contra el backend cuando hay conexión (reintentos idempotentes por UUID).
- **Modo kiosco**: bloquear la tablet dentro de la app durante la sesión (Guided Access en iPad / modo kiosco de Android) para evitar salidas accidentales — imprescindible en uso real con personas con Alzheimer.

**Modo facilitadora**
- Vista en vivo: una ficha por participante activo de la sesión, con nombre, ejercicio actual, y botón de un toque "Ayuda".
- Aviso sonoro suave cuando un participante lleva ~30s sin interactuar ("atascado") — evita que la integradora tenga que vigilar activamente todo el rato.
- Control para saltar ejercicio, cambiar de usuario dentro del grupo.

---

## 7. Panel web — especificación funcional

- **Vista individual**: evolución temporal por bloque cognitivo (precisión + ayuda necesitada), no solo un número — la tendencia importa más que el dato suelto.
- **Vista de grupo**: cómo evoluciona el grupo en conjunto, y quién se desvía del patrón habitual del grupo.
- **Vista de alertas**: lista de alertas pendientes de revisión, con contexto (qué cambió, desde cuándo).
- **Gestión de ejercicios**: alta/edición de ejercicios sobre las plantillas (sin tocar código) — esto es lo que hace que el catálogo pueda seguir creciendo sin que dependa de ti para cada ejercicio nuevo.

---

## 8. Motor de detección de anomalías (MVP)

Empieza simple, no hace falta ML desde el día 1:
- Por cada usuario y bloque cognitivo, calcula una media móvil y desviación estándar de las últimas N sesiones.
- Si un nuevo resultado (precisión o nivel de ayuda) se sale de ese rango habitual de forma sostenida (no un solo mal día), genera una alerta.
- Compara siempre contra el histórico **de esa misma persona**, nunca entre usuarios distintos.
- Cuando haya suficientes datos reales del piloto, se puede afinar con algo más sofisticado (Isolation Forest) — no antes.

---

## 9. Requisitos no funcionales

- **RGPD / datos de salud (categoría especial)**: pseudonimización de usuarios finales desde el diseño de la base de datos (alias interno, no nombre real en las tablas de trabajo). Tabla de consentimientos separada. El centro es responsable del tratamiento; vosotros actuáis como encargados del tratamiento (proveedores del software).
- **Seguridad**: patrón `.env` + `.gitignore` + `.env.example` desde el primer commit. Sin credenciales en código en ningún caso.
- **Accesibilidad**: texto grande configurable, alto contraste, sin dependencia solo del color (por daltonismo), opción de audio en instrucciones.
- **Auditoría**: registro de quién accede a datos de qué usuario final, con fecha — exigible bajo RGPD para datos de categoría especial.

---

## 10. Fases de desarrollo

**Fase 1 — Esqueleto (1-2 semanas)**
Backend con modelo de datos + auth. Un ejercicio funcional por cada uno de los 8 bloques (8 en total) usando el motor de plantillas. App tablet en modo participante básico, sin offline todavía.

**Fase 2 — Panel individual**
Dashboard web con vista de evolución por persona. Sincronización app-backend con offline real.

**Fase 3 — Grupo y vista facilitadora**
Sesiones en grupo, panel en vivo con fichas, botón de ayuda, aviso sonoro de "atascado".

**Fase 4 — Alertas**
Motor de detección de anomalías (media móvil + desviación estándar), vista de alertas en el panel.

**Fase 5 — Piloto real**
Con datos reales del centro, ajustar umbrales de alerta, ampliar catálogo de ejercicios según feedback de tu pareja.

---

## 11. Mejoras adicionales a tener en cuenta

- **Bot de Telegram para alertas de operación** (no clínicas, técnicas): reutilizando tu experiencia con los bots de trading, un bot simple que te avise si el servidor cae, falla una sincronización, o hay un error crítico — mismo patrón que ya dominas.
- **Modo demo con datos sintéticos**: una copia del panel con usuarios y datos falsos, para poder enseñar el proyecto a otros centros sin exponer datos reales de nadie — útil para la fase de "ofrecer a otros centros" del plan original.
- **Tests automáticos sobre el motor de alertas**: es la pieza que más confianza necesita generar (afecta a decisiones sobre personas vulnerables) — vale la pena invertir en tests unitarios ahí desde el principio, aunque el resto del MVP vaya más rápido y menos testeado.
- **Versionado de parámetros de ejercicio**: cuando cambies la dificultad de un ejercicio ya en uso, guarda el histórico de qué parámetros se usaron en cada intento pasado (ya contemplado en `cantidad_objetivo_json`) — si no, la comparación histórica para las alertas se rompe en cuanto ajustes algo.

---

## 12. Prompt para pegar en Claude Code

```
Quiero construir "Trazo", una aplicación de estimulación cognitiva para personas
mayores (mayoría con Alzheimer) en centros de día. Tiene tres partes en un monorepo:

1. App de tablet en Flutter — ejercicios de 8 dominios cognitivos (atención/memoria,
   lenguaje, razonamiento, gnosias, praxias, percepción, función ejecutiva, vida
   cotidiana). Modo participante (pantalla completa, sin menús) y modo facilitadora
   (vista en vivo de todos los participantes de la sesión, botón de ayuda de un toque,
   aviso sonoro si alguien lleva ~30s sin interactuar). Offline-first con sync por UUID.

2. Backend en FastAPI + PostgreSQL — sirve tanto a la app de tablet como al panel web.
   Motor de ejercicios data-driven: los ejercicios son configuraciones sobre un
   conjunto reducido de "plantillas" reutilizables (trazo, selección múltiple, memoria
   visual, secuencia a ordenar, conteo/comparación, arrastrar a posición, evocación
   libre, manejo de cantidad) — nada de una pantalla de código por ejercicio.

3. Panel web en React + TypeScript + Vite — vista de evolución individual y de grupo,
   vista de alertas, gestión del catálogo de ejercicios sin tocar código.

Estructura del repo:
trazo/
├── apps/
│   ├── tablet/      (Flutter)
│   └── web/         (React)
├── backend/
│   └── api/         (FastAPI)
├── docs/
└── README.md

Modelo de datos: centros, usuarios_staff, usuarios_finales (pseudonimizados),
consentimientos, sesiones, sesion_participantes, ejercicios_catalogo, intentos
(con estado solo/con_ayuda/no_completado y cantidad_objetivo_json para las
cantidades cambiantes de cada intento), alertas.

Requisitos no negociables desde el primer commit:
- Patrón .env + .gitignore + .env.example, cero credenciales en código.
- Pseudonimización de usuarios finales desde el diseño de la BD.
- Todo intento de ejercicio se guarda con estado (solo/con_ayuda/no_completado),
  nunca solo acierto/fallo.
- Comparaciones de alertas siempre contra el histórico de la misma persona,
  nunca entre usuarios distintos.

Empieza por la Fase 1: monta el esqueleto del backend (modelo de datos + auth JWT +
motor de plantillas de ejercicios) y un ejercicio funcional de cada uno de los 8
bloques usando ese motor. Después la app tablet en modo participante básico
consumiendo esos ejercicios. Ve preguntándome antes de tomar decisiones de
arquitectura que no estén ya especificadas aquí.
```

---

## 13. Sobre el stack elegido

Propusiste .NET MAUI para la app móvil — es una opción razonable si ya dominas C#/.NET, pero para Trazo específicamente **Flutter encaja mejor**: el núcleo del producto es capturar trazo a mano con precisión, y Flutter dibuja con motor propio (Skia) en vez de depender de widgets nativos por plataforma, lo que da rendimiento más consistente en tablets Android antiguas/baratas — justo el tipo de hardware que vas a encontrar en un centro de día.
