# Trazo — Contrato de la API (Fase 1)

Base URL local: `http://localhost:8000`. Documentación interactiva: `/docs`.

Auth: JWT Bearer. Login con `POST /auth/login` (form: `username`=email, `password`).
Enviar `Authorization: Bearer <token>` en el resto.

## Endpoints

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/auth/login` | Login (form-urlencoded). Devuelve `access_token`, `rol`, `nombre`, `centro_id`. |
| GET | `/centros/{centro_id}/usuarios` | Usuarios finales del centro (pseudonimizados). |
| POST | `/usuarios` | Alta de usuario final. Body: `alias_interno`, `nombre_real?`, `nivel_base_json?`. |
| GET | `/ejercicios?bloque=&activo=` | Catálogo de ejercicios. |
| POST | `/ejercicios` | Crear ejercicio (rol `admin_centro`). Body: `bloque`, `plantilla_tipo`, `nombre`, `parametros_json`. |
| GET | `/ejercicios/{id}/instancia?usuario_final_id=` | Genera una tirada concreta (cantidades cambiantes). |
| POST | `/sesiones` | Crear/abrir sala. Body: `tipo` (individual/grupo), `nombre?` (etiqueta de la sala, ej. "Grupo tarde"), `modo?`, `ejercicio_compartido_id?` (modo grupo), `participantes` (lista de ids). |
| GET | `/sesiones/activa?centro_id=` | Sesión abierta más reciente del centro + participantes (lo que consulta la tablet participante para descubrir la sala). Devuelve `nombre`, `iniciada`, `sesion_id=null` si no hay. |
| PATCH | `/sesiones/{id}/iniciar` | La maestra pulsa "Iniciar actividad" (`iniciada=true`). |
| PATCH | `/sesiones/{id}/cerrar` | Cerrar la sala (`cerrada=true`); las tablets vuelven a elegir rol. |
| GET | `/sesiones/{id}/live` | Estado en vivo (polling 3-5s): fichas por participante, `atascado`. |
| POST | `/sesiones/{id}/intentos` | Registrar intento (idempotente por `id` UUID de cliente). |
| PATCH | `/intentos/{id}/estado` | Cambiar estado (solo/con_ayuda/no_completado). |
| GET | `/usuarios/{id}/evolucion?bloque=&desde=&hasta=` | Serie temporal + resumen. |
| GET | `/usuarios/{id}/alertas` | Alertas de esa persona. |
| GET | `/grupos/{sesion_id}/evolucion` | Evolución de cada participante del grupo. |
| GET | `/alertas?centro_id=&revisada=false` | Bandeja de alertas del centro. |
| PATCH | `/alertas/{id}/revisar` | Marcar alerta revisada. Body: `resultado`. |
| GET | `/usuarios/{id}/plan` | Líneas del plan de trabajo de la persona (ordenadas por `orden`). |
| PUT | `/usuarios/{id}/plan` | Reemplaza TODO el plan. Body: `{ "lineas": [PlanLinea, …] }`. |
| GET | `/usuarios/{id}/cola?sesion_id=` | Cola de ejercicios resuelta desde el plan (lo que pide la tablet). Si `sesion_id` es modo grupo, devuelve el ejercicio compartido a su nivel. |
| POST | `/dispositivos` | Emparejar tablet al centro. Body: `nombre`, `rol` (maestra/participante), `centro_id?`. Devuelve `token`. |
| GET | `/dispositivos?centro_id=&activo=` | Tablets emparejadas del centro. |
| PATCH | `/dispositivos/{id}/revocar` | Desvincular una tablet (`activo=false`). |

## Plan de trabajo (`PlanLinea`)

Formato **mixto** por persona (ver `MODELO-OPERATIVO.md` §2): líneas por **dominio**
(el motor rota ejercicios del bloque) y/o por **ejercicio** concreto.

```json
{
  "tipo": "dominio",            // "dominio" | "ejercicio"
  "bloque": "praxias",          // requerido si tipo=dominio (uno de los bloques)
  "ejercicio_id": null,         // requerido si tipo=ejercicio
  "nivel": "bajo",              // bajo/medio/alto o entero como str
  "n_por_sesion": 2,            // cuántos de esta línea entran en la cola
  "orden": 0,                   // orden dentro del plan
  "activo": true
}
```

## Cola resuelta (respuesta de `/usuarios/{id}/cola`)

```json
{
  "usuario_final_id": "…",
  "sesion_id": "…",
  "modo": "individual",         // "individual" | "grupo"
  "items": [
    { "ejercicio_id": "…", "nombre": "Sigue la línea", "bloque": "praxias",
      "plantilla": "trazo", "nivel": "bajo", "origen": "dominio",
      "plan_linea_id": "…" }
  ]
}
```

`origen` indica de dónde sale el item: `dominio` (resuelto del bloque), `ejercicio`
(fijado en el plan) o `grupo` (ejercicio compartido de la sesión). En modo grupo la
cola es un único item: la misma actividad para todos, **cada uno a su nivel**.

## Vocabulario

- **Bloques**: `atencion_memoria`, `lenguaje`, `razonamiento`, `gnosias`, `praxias`,
  `percepcion`, `funcion_ejecutiva`, `vida_cotidiana`.
- **Plantillas**: `trazo`, `seleccion_multiple`, `memoria_visual`, `secuencia_ordenar`,
  `conteo_comparacion`, `arrastrar_posicion`, `evocacion_libre`, `manejo_cantidad`.
- **Estado de intento**: `solo`, `con_ayuda`, `no_completado` (nunca solo acierto/fallo).
- **Tipo de línea de plan**: `dominio`, `ejercicio`.
- **Rol de dispositivo**: `maestra`, `participante`.
- **Modo de sesión**: `individual`, `grupo`.

## Ejemplo de `intento` (POST body)

```json
{
  "id": "uuid-generado-en-cliente-para-sync-offline",
  "usuario_final_id": "…",
  "sesion_id": "…",
  "ejercicio_id": "…",
  "estado": "solo",
  "valores_json": { "precision": 0.82, "tiempo_ms": 90000 },
  "cantidad_objetivo_json": { "figura_id": "onda", "tolerancia_px": 24 }
}
```

## Instancia generada (respuesta de `/ejercicios/{id}/instancia`)

```json
{
  "ejercicio_id": "…",
  "nombre": "Sigue la línea",
  "bloque": "praxias",
  "plantilla": "trazo",
  "render": { "instruccion": "Sigue la línea con el dedo", "guide_path": "M20,100 …", "tolerancia_px": 24, "viewbox": "0 0 300 140" },
  "cantidad_objetivo": { "figura_id": "onda", "tolerancia_px": 24 },
  "metricas": ["precision", "tiempo_ms", "desviacion_media", "longitud_recorrida"]
}
```

El `render` cambia según la plantilla; el cliente lo interpreta por el campo `plantilla`.

### Instancia de dinero (`plantilla: "manejo_cantidad"`)

El motor de dinero trabaja **internamente en céntimos enteros** (sin errores de
coma flotante) y expone además el importe ya **formateado** (`importe_texto`).
Soporta todas las monedas (1c…2€) y billetes (5…500 €), rangos configurables por
banda/nivel y varios **modos** que se eligen al azar en cada tirada:
`dinero` (reúne el importe), `monedas_justas`, `vuelta`, `llega_para_pagar` y
`reloj`.

Ejemplo de tirada del modo **`vuelta`** (con céntimos y billete):

```json
{
  "ejercicio_id": "…",
  "nombre": "La vuelta del cambio",
  "bloque": "vida_cotidiana",
  "plantilla": "manejo_cantidad",
  "render": {
    "instruccion": "Pagas 12,45 € con 20,00 €. ¿Cuánto te devuelven?",
    "modo": "vuelta",
    "precio_c": 1245, "precio_texto": "12,45 €",
    "pago_c": 2000, "pago_texto": "20,00 €",
    "denominaciones": [ { "valor_c": 1, "etiqueta": "1c" }, { "valor_c": 500, "etiqueta": "5€" } ]
  },
  "cantidad_objetivo": { "modo": "vuelta", "banda": null, "precio_c": 1245, "pago_c": 2000 },
  "metricas": ["correcto", "tiempo_ms", "num_ajustes"]
}
```

La `solucion` (que el backend conserva, no siempre se envía al cliente) incluye
`vuelta_c` (`755`), `vuelta_texto` (`"7,55 €"`) y un `desglose_c` de las
monedas/billetes que la componen (p. ej. `{"500":1,"200":1,"50":1,"5":1}`). En el
modo `dinero`/`monedas_justas` lleva `importe_c` + `desglose_c`; en
`llega_para_pagar`, `llega` (bool) con `precio_c` y `disponible_c`.

Todos los importes concretos de la tirada quedan en `cantidad_objetivo` (en
céntimos) para que la comparación histórica de alertas sea justa aunque cambie la
dificultad después.
