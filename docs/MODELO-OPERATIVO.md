# Trazo — Modelo operativo (cómo se usa de verdad en el centro)

> Documento de diseño acordado. Describe el flujo real de uso y las decisiones
> tomadas. Es la guía para reorientar la app hacia este funcionamiento.
> (El código actual de la tablet fue un andamiaje para validar la API; esta es
> la UX definitiva.)

## Principio rector
Máxima usabilidad para el equipo: **un solo login (la trabajadora)**, cero
fricción al repartir, y todo el "pensar qué hace cada uno" resuelto **antes**, no
en el momento.

---

## 1. Roles y dispositivos

| Dispositivo | Quién | Login | Qué hace |
|---|---|---|---|
| **Tablet maestra** | La trabajadora / integradora | **Sí** (solo ella) | Monta la sesión, reparte, vigila |
| **Tablets participantes** | Personas usuarias | **No** | Solo muestran la actividad (modo kiosco) |

Las tablets participantes se **emparejan al centro una sola vez** (setup inicial).
A partir de ahí son "del centro" y se pueden **desvincular desde la web** si se
pierde una (importante para RGPD). En el día a día no piden login nunca.

---

## 2. El plan de trabajo por paciente  ⭐ (el corazón del sistema)

Cada persona tiene un **plan** que el profesional monta **en la web**, con calma.
Evita elegir ejercicios a mano en cada sesión.

- **Formato mixto**: por defecto se marca por **dominio + nivel**
  (ej. *"praxias, nivel bajo"* + *"memoria, nivel medio"*) y el motor rota
  ejercicios de esos dominios; pero se puede **fijar un ejercicio concreto**
  cuando interese uno en particular.
- **Nº de ejercicios por sesión**: lo define el plan. Cuando la persona completa
  esa cantidad, **termina** su sesión (previsible y con sentido clínico).
- **Niveles**: **auto-sugerencia que el profesional aprueba**. El sistema propone
  subir o bajar según la evolución y las alertas; la profesional confirma. Nunca
  cambia solo sin visto bueno.

Durante la sesión, cada tablet **construye sola la cola** de ejercicios de esa
persona a partir de su plan, con las cantidades cambiantes de siempre.

---

## 3. Dos formas de sesión

- **Individual (por defecto)**: cada participante hace **su propio plan**.
- **Grupo (actividad compartida)**: la trabajadora marca *"todos la misma
  actividad"* y elige cuál. Matiz clave: **misma actividad, cada uno a su nivel**
  — no se nota que a unos les toca más fácil que a otros.

---

## 4. Ciclo de una sesión (el reparto)

```
[Reposo] --abre sesión--> [Elegir participantes] --> [Sesión activa]
                                                          |
   tablets muestran "¿Quién eres?" con los N nombres  <---+
                                                          |
   reparto por toque: dar tablet a Juan -> pulsar "Juan" -> arranca su plan
                                                          |
                        [Trabajar + monitor]  --cerrar--> [Reposo]
```

1. **Montar**: la maestra abre sesión y **elige quién participa ahora** (toca los
   nombres de la lista del centro; ya están dados de alta con su historial).
2. **Repartir**: las tablets emparejadas muestran esos nombres. Se le da la tablet
   a Juan → **pulsar "Juan"** → se queda con Juan y arranca. María en otra, etc.
   Sin logins.
3. **Trabajar**: cada uno hace su cola. Reasignar/añadir/quitar es posible a mitad.
4. **Cerrar**: la maestra cierra; las tablets vuelven a reposo.

Un gesto discreto (esquina + PIN del equipo) permite recuperar/reasignar una
tablet sin que la persona usuaria pueda salir sola.

---

## 5. El monitor de la maestra

Tarjetas pequeñas **de tres en tres, con scroll**. Cada una en tiempo real:

- Estado: **trabajando · atascado · ayudado · terminó su plan**
- **Atascado**: si lleva ~1 min sin tocar la pantalla (configurable) → se resalta
  y avisa con sonido suave.
- **Ayuda**: se marca desde la tarjeta del monitor **o** desde la propia tablet
  del paciente. Queda registrado (`con_ayuda`), no penaliza en pantalla.
- Cuando alguien completa su cola, su tarjeta lo indica; la trabajadora puede
  darle más ejercicios o dejarlo.

---

## 6. Cómo enlaza con la detección temprana
El "estado" de cada intento (solo / con ayuda / no completado) y la precisión
alimentan el motor de alertas que ya existe (comparando siempre con el histórico
propio). Además, esas mismas señales son las que generan la **auto-sugerencia de
nivel** del plan. Todo conectado.

---

## 7. Qué cambia respecto a lo ya construido

La API actual (sesiones, participantes, intentos, `/live`, alertas) **aguanta casi
todo**. Se añadirían dos conceptos nuevos:

- **`planes_paciente`** — líneas de plan (dominio/ejercicio + nivel + nº por sesión).
- **`dispositivos`** — tablets emparejadas al centro (token revocable).
- Campo **modo** en la sesión (individual / grupo) + ejercicio compartido opcional.

### Arquitectura de las apps (decidido)

**Una sola app de tablet, NO dos.** El rol se elige al **emparejar** el aparato:
- **Modo maestra**: requiere login; es la tablet de la trabajadora.
- **Modo participante (kiosco)**: sin login; es una tablet de usuario.

Motivos: una sola app que construir, distribuir y actualizar; el rol queda fijado
en el emparejamiento y protegido (no se puede cambiar sin el PIN del equipo), así
una tablet de participante nunca muestra controles de maestra por accidente.

**Qué contiene cada modo:**
- **Maestra** = montar sesión (elegir participantes / modo) + **monitor en vivo**
  + **seguimiento del centro** (evolución y alertas de los pacientes, para
  consultarlo desde la propia tablet). Es decir, la maestra también puede ver el
  panel, no solo controlar la sesión.
- **Participante** = "¿quién eres?" → reparto por toque → cola del plan a pantalla
  completa. (Sustituye al login + selector del andamiaje actual.)

**El panel web (React) se mantiene** para uso en ordenador: enseñar la evolución a
familiares desde un PC, administración, y el **editor de planes** por paciente.
Misma información, dos ventanas (tablet maestra y web).

> Reutilización: como el panel web ya es responsive, el "seguimiento" de la maestra
> puede reimplementarse nativo en la tablet o reaprovechar el panel web (a decidir;
> no bloquea el diseño).

Nada de esto tira lo hecho: lo reorienta.

---

## 8. Pantallas (esquema)

**Maestra**
1. Login (solo aquí).
2. Nueva sesión → elegir participantes en un **desplegable** (los 10/12/15 que
   toquen, ya dados de alta) + modo individual/grupo.
3. Monitor en vivo (tarjetas 3 en 3, estados, marcar ayuda).
4. **Seguimiento**: evolución y alertas de los pacientes (el mismo panel, para
   consultarlo desde la tablet).

**Participante (kiosco, emparejada)**
1. Reposo ("esperando sesión").
2. "¿Quién eres?" → lista de participantes de la sesión.
3. Ejercicio a pantalla completa (su cola de plan). Sin menús.

**Web (profesional)**
1. Ficha de paciente + **editor de plan** (dominios/nivel + ejercicios fijos + nº).
2. Evolución + alertas (ya existe) + **aprobar sugerencias de nivel**.
3. Gestión de dispositivos emparejados.

---

## Detalles menores aún por decidir (no bloquean)
- ¿Rotación de ejercicios dentro del plan: orden fijo, aleatorio, o "el que menos
  se ha trabajado"?
- ¿El modo grupo permite mezclar (unos en grupo, otros en su plan) o es para toda
  la sala?
- Umbral exacto de "atascado" y tipo de aviso sonoro.
- PIN/gesto concreto para recuperar una tablet.
