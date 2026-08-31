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


def _grada(fraccion: float, hubo_intento: bool, umbral_parcial: float = _UMBRAL_PARCIAL) -> str:
    """Convierte una fracción de acierto (0..1) en logrado/parcial/no_logrado.

    `umbral_parcial` permite subir el listón cuando la métrica base tiene un azar
    alto (p. ej. la fracción de pares concordantes de una ordenación vale 0.5 al
    azar: usar 0.5 premiaría con 'parcial' a más de la mitad de ordenaciones
    aleatorias — bug de la ronda 3)."""
    if fraccion >= 0.999:
        return "logrado"
    if fraccion >= umbral_parcial:
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
    # En las comparaciones (cual_tiene_mas/menos) el widget manda {grupo, objeto};
    # en sumar/contar manda un número. Normalizamos al valor comparable.
    if isinstance(respuesta, dict):
        respuesta = respuesta.get("objeto")
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
    # "Tocar TODO por si acaso" (conducta muy típica del mayor confundido): con
    # pocos distractores, aciertos(3-5) > fallos(2) daría 'parcial' y subiría el
    # desempeño de quien NO discrimina (bug de la ronda 3, 198/198). Si tocó TODOS
    # los distractores de la rejilla, no ha discriminado nada -> no_logrado, sin
    # importar cuántos objetivos haya "acertado" (los tocó todos).
    total = int(_num(o.get("n_rejilla") or o.get("total"), 0) or 0)
    n_distractores = total - objetivos if total > objetivos else 0
    if n_distractores > 0 and fallos >= n_distractores:
        return "no_logrado"
    # Solo hay 'parcial' si acierta MÁS de lo que falla (discrimina de verdad).
    if aciertos >= 1 and aciertos > fallos:
        return "parcial"
    return "no_logrado"  # no acertó ninguna, o tocó a bulto (fallos>=aciertos)


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
    # Exactitud posicional (señal estricta).
    aciertos = sum(1 for i in range(n) if orden_final[i] == correcto[i])
    ratio_pos = aciertos / len(correcto)
    # Orden RELATIVO (señal justa): fracción de pares en el orden correcto. Así un
    # desplazamiento de un paso puntúa alto en vez de hundir a 0 la exactitud
    # posicional; refleja mejor el desempeño real (principio: medir, no castigar).
    rank = {paso: i for i, paso in enumerate(correcto)}
    seq = [rank[p] for p in orden_final if p in rank]
    ratio_pares = ratio_pos
    if len(seq) >= 2:
        total = concordantes = 0
        for i in range(len(seq)):
            for j in range(i + 1, len(seq)):
                total += 1
                if seq[i] < seq[j]:
                    concordantes += 1
        ratio_pares = concordantes / total if total else ratio_pos
    # Umbral de 'parcial' por ENCIMA del azar (0.5 = permutación aleatoria): 0.67
    # exige estar claramente cerca del orden correcto (un desplazamiento de un paso
    # sigue puntuando parcial; ordenar al azar ya no).
    return _grada(max(ratio_pos, ratio_pares), hubo_intento=True, umbral_parcial=0.66)


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
    # Guardia anti-"responder a bulto": volcar TODAS las piezas en una sola zona
    # (conducta del mayor confundido) acierta las de esa zona y sacaría 'parcial'
    # sin discriminar. Si usó una sola zona habiendo ≥2 zonas correctas distintas,
    # no ha clasificado -> no_logrado (mismo criterio que memoria/búsqueda).
    zonas_correctas = set(emparejamientos.values())
    zonas_usadas = set(colocaciones.values())
    if len(zonas_correctas) >= 2 and len(zonas_usadas) == 1:
        return "no_logrado"
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
        h12 = int(_num(h, -1)) % 12
        oh12 = int(_num(oh, -2)) % 12
        om_i = int(_num(om, -2))
        # Tolerancia clínica: con minutos altos (>=40) la aguja horaria ya está a
        # 2/3 hacia la hora siguiente; leer "las X menos veinte/cuarto" (hora+1) es
        # una lectura razonable, no un fallo. El minuto sí debe coincidir.
        if om_i >= 40:
            hora_ok = h12 == oh12 or h12 == (oh12 + 1) % 12
        else:
            hora_ok = h12 == oh12
        min_ok = int(_num(m, -1)) == om_i
        # Acertar la HORA pero fallar el minuto es un logro parcial (leyó bien la
        # aguja de las horas): informa mejor que un no_logrado seco.
        if hora_ok and min_ok:
            return "logrado"
        if hora_ok:
            return "parcial"
        return "no_logrado"
    # Dinero: el objetivo está en CÉNTIMOS. El cliente puede enviar el total en
    # céntimos (245) o en euros (2.45); aceptamos ambas unidades para que un
    # importe compuesto EXACTO se puntúe logrado venga en la unidad que venga.
    total = v.get("total_compuesto")
    monedas = v.get("monedas_usadas") or []
    if total is None and not monedas:
        return "sin_valorar"  # no puso ninguna moneda
    if total is None:
        total = sum((_num(m, 0) or 0) for m in monedas)
    objetivo_c = o.get("importe_c")
    if objetivo_c is None and o.get("pago_c") is not None and o.get("precio_c") is not None:
        objetivo_c = int(_num(o["pago_c"], 0)) - int(_num(o["precio_c"], 0))  # vuelta
    if objetivo_c is None:
        return "sin_valorar"
    t = _num(total)
    if t is None:
        return "no_logrado"
    obj = int(_num(objetivo_c, -2))
    # El total puede venir en céntimos (245) o en euros (2.45): mide la distancia
    # en la interpretación más favorable.
    diff = min(abs(int(round(t)) - obj), abs(int(round(t * 100)) - obj))
    if diff == 0:
        return "logrado"
    # Se quedó CERCA (<=10% del importe, mínimo 5 cént.): logro parcial, no un
    # fallo seco. Reconoce el casi-acierto (p. ej. 2,40 € para 2,45 €).
    if diff <= max(5, round(abs(obj) * 0.10)):
        return "parcial"
    return "no_logrado"


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


def _parejas(v, o):
    # El juego SOLO termina cuando se encuentran todas las parejas; por eso el
    # desempeño se mide por los ERRORES (destapes fallidos), no por si acabó.
    n = int(_num(o.get("n_pares"), 0) or 0)
    encontradas = _num(v.get("pares_encontrados"))
    if n <= 0 or encontradas is None:
        return "sin_valorar"
    encontradas = int(encontradas)
    if encontradas < n:
        return "sin_valorar"  # lo dejó a medias: no es un fallo, no puntúa
    errores = int(_num(v.get("errores"), 0) or 0)
    # Un tablero de n parejas requiere n aciertos; cada error es un intento de más.
    # fracción = aciertos / (aciertos + errores). 0 errores -> 1.0 (logrado).
    return _grada(n / (n + errores) if (n + errores) else 1.0, hubo_intento=True)


def hubo_interaccion(plantilla: str, valores: dict | None) -> bool:
    """¿La persona TOCÓ/interactuó con la actividad? (independiente de acertar).

    Sirve para la vigilancia de "dejar de participar" (missingness): distingue el
    NO-INTENTO real de una tarea que la app no puede juzgar pero sí se intentó.
    Ante la duda (reloj, respuesta abierta), asumimos que SÍ interactuó, para no
    inflar falsamente la señal de desconexión.
    """
    v = valores or {}
    if plantilla == "seleccion_multiple":
        return bool(v.get("eleccion"))
    if plantilla == "conteo_comparacion":
        return v.get("respuesta") not in (None, "")
    if plantilla in ("memoria_visual", "busqueda_visual"):
        aciertos = int(_num(v.get("aciertos"), 0) or 0)
        fallos = int(_num(v.get("fallos"), 0) or 0)
        return (aciertos + fallos) > 0 or bool(v.get("seleccionadas"))
    if plantilla == "secuencia_ordenar":
        return int(_num(v.get("movimientos"), 0) or 0) > 0
    if plantilla == "arrastrar_posicion":
        return bool(v.get("colocaciones"))
    if plantilla == "trazo":
        return int(_num(v.get("puntos_capturados"), 0) or 0) > 0
    if plantilla == "manejo_cantidad":
        if "hora_elegida" in v:
            return True  # reloj: no podemos saberlo -> asumimos que sí
        return bool(v.get("monedas_usadas"))
    if plantilla == "parejas":
        return (int(_num(v.get("pares_encontrados"), 0) or 0) > 0
                or int(_num(v.get("errores"), 0) or 0) > 0)
    return True


def _reto_garrafas(v, o):
    """Reto de garrafas: lo resuelve el grupo en la tablet y esta llega ya
    autoevaluada (`resuelto`). Es un juego de grupo, no una medida individual:
    'logrado' si lo consiguieron, 'sin_valorar' si no (que se revise, sin penalizar)."""
    if v.get("resuelto") is True:
        return "logrado"
    return "sin_valorar"


_CORRECTORES = {
    "reto_garrafas": _reto_garrafas,
    "reto_cruzar": _reto_garrafas,
    "reto_ranas": _reto_garrafas,
    "reto_hanoi": _reto_garrafas,
    "seleccion_multiple": _seleccion_multiple,
    "conteo_comparacion": _conteo_comparacion,
    "memoria_visual": _memoria_visual,
    "busqueda_visual": _busqueda_visual,
    "secuencia_ordenar": _secuencia_ordenar,
    "arrastrar_posicion": _arrastrar_posicion,
    "manejo_cantidad": _manejo_cantidad,
    "trazo": _trazo,
    "parejas": _parejas,
}
