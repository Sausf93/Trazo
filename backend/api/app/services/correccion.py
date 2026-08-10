"""Autocorrección del RESULTADO de un intento (la señal primaria de la medición).

Diseño validado con terapeuta ocupacional y neuropsicólogo:
  - El RESULTADO (logrado/parcial/no_logrado) se calcula de lo que la persona
    hizo de verdad (las métricas que reporta cada widget + la respuesta correcta,
    que viaja en `cantidad_objetivo`). Es objetivo e independiente de la
    integradora.
  - "sin_valorar" NO es un fallo: es un NO-INTENTO (no tocó nada) o una tarea que
    la app no puede juzgar sola (abiertas, o el trazo en su banda intermedia). Se
    EXCLUYE del cálculo hasta que la integradora la revise, pero no se ignora
    (ver `anomalias`: su aumento sostenido es señal en sí mismo).

Regla de oro (TO): "no tocó nada" (sin_valorar) ≠ "tocó y falló" (no_logrado).
"""
from __future__ import annotations

RESULTADOS = ("logrado", "parcial", "no_logrado", "sin_valorar")

# Umbral de "parcial" para tareas de varios ítems (fracción correcta).
_UMBRAL_PARCIAL = 0.5


def _num(v, defecto=None):
    try:
        return float(v)
    except (TypeError, ValueError):
        return defecto


def _grada(fraccion: float, hubo_intento: bool) -> str:
    """Convierte una fracción de acierto (0..1) en logrado/parcial/no_logrado."""
    if fraccion >= 0.999:
        return "logrado"
    if fraccion >= _UMBRAL_PARCIAL:
        return "parcial"
    return "no_logrado" if hubo_intento else "sin_valorar"


def corregir(plantilla: str, valores: dict | None, cantidad_objetivo: dict | None) -> str:
    """Devuelve 'logrado' | 'parcial' | 'no_logrado' | 'sin_valorar'.

    Nunca lanza: ante datos que no puede interpretar, devuelve 'sin_valorar'
    (que la integradora lo revise) en vez de inventarse un resultado.
    """
    v = valores or {}
    o = cantidad_objetivo or {}
    try:
        fn = _CORRECTORES.get(plantilla)
        if fn is None:
            return "sin_valorar"
        return fn(v, o)
    except Exception:
        return "sin_valorar"


# --- Correctores por plantilla -------------------------------------------------

def _seleccion_multiple(v, o):
    eleccion = v.get("eleccion")
    correcta = o.get("correcta")
    if eleccion is None or eleccion == "":
        return "sin_valorar"  # no eligió nada -> no-intento
    if correcta is None:
        return "sin_valorar"  # sin clave (APK vieja): que se revise
    return "logrado" if eleccion == correcta else "no_logrado"


def _conteo_comparacion(v, o):
    respuesta = v.get("respuesta")
    sol = o.get("solucion") or {}
    modo = v.get("modo") or o.get("modo")
    if respuesta is None or respuesta == "":
        return "sin_valorar"
    if not sol:
        return "sin_valorar"
    if modo == "cual_tiene_mas":
        return "logrado" if respuesta == sol.get("objeto_mayor") else "no_logrado"
    if modo == "cual_tiene_menos":
        return "logrado" if respuesta == sol.get("objeto_menor") else "no_logrado"
    if modo == "sumar":
        return "logrado" if _num(respuesta) == _num(sol.get("total")) else "no_logrado"
    # contar (uno concreto)
    return "logrado" if _num(respuesta) == _num(sol.get("cantidad")) else "no_logrado"


def _por_aciertos_fallos(v, o, clave_objetivos):
    """memoria_visual / busqueda_visual: el widget ya trae aciertos/fallos ciertos
    (las respuestas correctas están en el propio render que la persona ve)."""
    aciertos = int(_num(v.get("aciertos"), 0) or 0)
    fallos = int(_num(v.get("fallos"), 0) or 0)
    objetivos = int(_num(o.get(clave_objetivos), 0) or 0)
    if aciertos == 0 and fallos == 0:
        return "sin_valorar"  # no tocó ninguna
    if objetivos <= 0:
        return "sin_valorar"
    # logrado = todos los objetivos y ningún falso positivo. Contar los falsos
    # positivos importa: 3 aciertos con 4 fallos NO es reconocer, es responder a
    # bulto (TO).
    if aciertos >= objetivos and fallos == 0:
        return "logrado"
    if aciertos >= 1:
        return "parcial"
    return "no_logrado"  # tocó (fallos>0) pero no acertó ninguna


def _memoria_visual(v, o):
    return _por_aciertos_fallos(v, o, "n_figuras")


def _busqueda_visual(v, o):
    return _por_aciertos_fallos(v, o, "objetivos")


def _secuencia_ordenar(v, o):
    orden_final = v.get("orden_final")
    correcto = o.get("orden_correcto_pasos")  # lista de pasos en su orden bueno
    movimientos = int(_num(v.get("movimientos"), 0) or 0)
    if not isinstance(orden_final, list) or not orden_final:
        return "sin_valorar"
    # Trampa: si no movió nada y quedó como se presentó, es indistinguible de "no
    # lo intentó" aunque el azar lo deje bien (TO).
    if movimientos == 0:
        return "sin_valorar"
    if not isinstance(correcto, list) or not correcto:
        return "sin_valorar"
    n = min(len(orden_final), len(correcto))
    if n == 0:
        return "sin_valorar"
    aciertos = sum(1 for i in range(n) if orden_final[i] == correcto[i])
    return _grada(aciertos / len(correcto), hubo_intento=True)


def _arrastrar_posicion(v, o):
    colocaciones = v.get("colocaciones")
    emparejamientos = o.get("emparejamientos")  # {pieza: zona_correcta}
    if not isinstance(colocaciones, dict) or not colocaciones:
        return "sin_valorar"  # no colocó nada
    if not isinstance(emparejamientos, dict) or not emparejamientos:
        return "sin_valorar"
    total = len(emparejamientos)
    aciertos = sum(1 for pieza, zona in colocaciones.items()
                   if emparejamientos.get(pieza) == zona)
    return _grada(aciertos / total, hubo_intento=True)


def _manejo_cantidad(v, o):
    modo = v.get("modo") or o.get("modo")
    # Reloj: hora/minuto elegidos vs objetivo, con la ambigüedad de 12 h.
    if "hora_elegida" in v or modo == "reloj":
        h = v.get("hora_elegida")
        m = v.get("minuto_elegido")
        if h is None or m is None:
            return "sin_valorar"
        oh, om = o.get("hora"), o.get("minuto")
        if oh is None or om is None:
            return "sin_valorar"
        hora_ok = (int(_num(h, -1)) % 12) == (int(_num(oh, -2)) % 12)
        min_ok = int(_num(m, -1)) == int(_num(om, -2))
        return "logrado" if (hora_ok and min_ok) else "no_logrado"
    # Dinero: el total compuesto contra el importe/vuelta objetivo (en céntimos).
    total = v.get("total_compuesto")
    monedas = v.get("monedas_usadas") or []
    if total is None and not monedas:
        return "sin_valorar"  # no puso ninguna moneda
    objetivo_c = o.get("importe_c")
    if objetivo_c is None and o.get("pago_c") is not None and o.get("precio_c") is not None:
        objetivo_c = int(_num(o["pago_c"], 0)) - int(_num(o["precio_c"], 0))  # vuelta
    if objetivo_c is None:
        return "sin_valorar"
    return "logrado" if int(_num(total, -1)) == int(_num(objetivo_c, -2)) else "no_logrado"


def _trazo(v, o):
    puntos = int(_num(v.get("puntos_capturados"), 0) or 0)
    precision = _num(v.get("precision"))
    if puntos == 0:
        return "sin_valorar"  # no dibujó nada
    # TO: no dar 'logrado' solo por precisión; autoclasificar SOLO los extremos y
    # dejar la banda intermedia a revisión (un trazo pobre puede ser apraxia o
    # temblor, y eso lo valora la persona).
    if precision is None:
        return "sin_valorar"
    if puntos < 5:
        return "no_logrado"  # apenas trazó
    if precision >= 0.8 and puntos >= 15:
        return "logrado"     # trazo amplio y preciso
    return "sin_valorar"     # banda intermedia -> revisar


def _evocacion_libre(v, o):
    # Respuesta oral/abierta: la app no la oye. SIEMPRE la revisa la integradora.
    return "sin_valorar"


_CORRECTORES = {
    "seleccion_multiple": _seleccion_multiple,
    "conteo_comparacion": _conteo_comparacion,
    "memoria_visual": _memoria_visual,
    "busqueda_visual": _busqueda_visual,
    "secuencia_ordenar": _secuencia_ordenar,
    "arrastrar_posicion": _arrastrar_posicion,
    "manejo_cantidad": _manejo_cantidad,
    "trazo": _trazo,
    "evocacion_libre": _evocacion_libre,
}
