"""Motor de detección temprana (MVP) — lógica PURA, sin base de datos.

Principios (ver especificación §8):
  - Se compara SIEMPRE contra el histórico de la MISMA persona, nunca entre
    usuarios distintos.
  - El objetivo no es detectar que no mejora, sino que EMPEORA de forma
    sostenida (no un solo mal día).
  - Empieza simple: media móvil + desviación estándar. Nada de ML todavía.

Separado de la capa de BD a propósito para poder testearlo con datos sintéticos
(la pieza que más confianza necesita: afecta a personas vulnerables).
"""
from __future__ import annotations

import statistics
from collections import Counter
from dataclasses import dataclass


# Peso del estado del intento sobre el rendimiento normalizado (0..1).
_PESO_ESTADO = {
    "solo": 1.0,
    "con_ayuda": 0.5,
    "no_completado": 0.0,
}

# Rendimiento a partir del RESULTADO autocorregido (la señal primaria actual).
# 'sin_valorar' no está: esos intentos se EXCLUYEN antes de llegar aquí.
_PESO_RESULTADO = {
    "logrado": 1.0,
    "parcial": 0.5,
    "no_logrado": 0.0,
}


def rendimiento_resultado(resultado: str) -> float:
    """Escalar 0..1 del resultado autocorregido (logrado/parcial/no_logrado)."""
    return _PESO_RESULTADO.get(resultado, 0.0)


def rendimiento_intento(estado: str, valores: dict | None) -> float:  # LEGACY
    # Ruta ANTIGUA (estado solo/con_ayuda/no_completado). Ya no la usa ninguna
    # ruta de producción: el rendimiento sale de `rendimiento_resultado`. Se
    # conserva solo por compatibilidad de tests históricos.
    """Normaliza un intento a un escalar 0..1 combinando estado + métricas.

    - `estado` marca el techo: no_completado=0, con_ayuda=0.5, solo=1.0.
    - dentro de ese techo se modula por la métrica de acierto disponible.
    """
    techo = _PESO_ESTADO.get(estado, 0.0)
    if techo == 0.0:
        return 0.0

    valores = valores or {}
    calidad = 1.0
    if "precision" in valores and valores["precision"] is not None:
        calidad = _clip01(float(valores["precision"]))
    elif "correcto" in valores and valores["correcto"] is not None:
        calidad = 1.0 if valores["correcto"] else 0.0
    elif "aciertos" in valores:
        aciertos = float(valores.get("aciertos", 0))
        fallos = float(valores.get("fallos", 0))
        total = aciertos + fallos
        calidad = _clip01(aciertos / total) if total > 0 else 1.0
    elif "n_validas" in valores and "n_pedidas" in valores:
        pedidas = float(valores.get("n_pedidas", 0))
        calidad = _clip01(float(valores["n_validas"]) / pedidas) if pedidas > 0 else 1.0

    return techo * calidad


def _clip01(x: float) -> float:
    return max(0.0, min(1.0, x))


@dataclass
class ResultadoDesviacion:
    hay_desviacion: bool
    baseline_media: float
    baseline_std: float
    reciente_media: float
    umbral_inferior: float
    n_baseline: int
    n_reciente: int
    caida: float  # cuánto por debajo del umbral (0 si no hay desviación)


def detectar_desviacion(
    serie: list[float],
    ventana_reciente: int = 2,
    min_baseline: int = 4,
    k: float = 1.5,
    caida_minima: float = 0.08,
) -> ResultadoDesviacion | None:
    """Detecta un empeoramiento sostenido respecto al patrón propio.

    `serie` va de más antiguo a más reciente (un valor por intento/sesión).

    Devuelve None si no hay datos suficientes para juzgar (no es lo mismo que
    "todo bien": es "aún no sé"). Si hay datos, devuelve el resultado con
    `hay_desviacion` a True/False.

    Regla: la media de la ventana reciente cae por debajo de
    (media_baseline - k * std_baseline), y además al menos `caida_minima` por
    debajo de la media baseline (evita disparos por ruido cuando std≈0).
    """
    if len(serie) < min_baseline + ventana_reciente:
        return None

    baseline = serie[:-ventana_reciente]
    reciente = serie[-ventana_reciente:]

    media_base = statistics.fmean(baseline)
    std_base = statistics.pstdev(baseline) if len(baseline) > 1 else 0.0
    media_rec = statistics.fmean(reciente)

    umbral = media_base - k * std_base
    hay = (media_rec < umbral) and ((media_base - media_rec) >= caida_minima)

    return ResultadoDesviacion(
        hay_desviacion=hay,
        baseline_media=round(media_base, 4),
        baseline_std=round(std_base, 4),
        reciente_media=round(media_rec, 4),
        umbral_inferior=round(umbral, 4),
        n_baseline=len(baseline),
        n_reciente=len(reciente),
        caida=round(max(0.0, media_base - media_rec), 4) if hay else 0.0,
    )


# ==========================================================================
#  Agregación por sesión + segmentación por dificultad + señal de latencia
# --------------------------------------------------------------------------
#  Motivación (auditoría de calidad):
#   1) La serie CRUDA por intento es ruidosa: dos actividades flojas seguidas la
#      misma tarde no son "empeoramiento sostenido". Agregamos el rendimiento
#      POR SESIÓN (media de sus intentos) y comparamos sesión-a-sesión.
#   2) Cuando cambia la dificultad (nivel/cantidad) el rendimiento baja de forma
#      natural: comparar contra un baseline de otra dificultad da falsas alarmas.
#      Segmentamos la serie por "firma de dificultad" y solo juzgamos DENTRO del
#      tramo de dificultad vigente (baseline se reinicia al cambiar de nivel).
#   3) El TIEMPO de respuesta se captura pero no se usa. "Tarda cada vez más en
#      lo mismo" precede al fallo: lo añadimos como SEGUNDA señal (tendencia
#      creciente de tiempo, normalizado por ejercicio, también puede alertar).
#
#  Todo esto es lógica PURA (sin BD) para poder testearla con datos sintéticos.
# ==========================================================================


@dataclass
class IntentoObs:
    """Observación mínima de un intento para el motor (la arma la capa de BD)."""

    sesion_id: str
    ejercicio_id: str
    rendimiento: float
    dificultad: str
    tiempo_ms: float | None = None


@dataclass
class SesionObs:
    """Rendimiento agregado de UNA sesión (un punto de la serie de detección)."""

    sesion_id: str
    rendimiento: float
    dificultad: str
    tiempo_rel: float | None
    n_intentos: int


# Claves de `cantidad_objetivo` que describen la DIFICULTAD (estables entre
# instancias de la misma actividad/nivel). El resto de claves cambian en cada
# tirada (respuesta correcta, ids, importes, hora...) y NO deben entrar en la
# firma: si entran, cada intento sale con firma única, nunca se acumula baseline
# y la alerta de declive no puede dispararse (regresión detectada en auditoría).
# OJO: 'modo' y 'banda' NO entran: en las actividades con `modos`/`bandas` se
# eligen AL AZAR por tirada (rng.choice), así que cambiarían la firma en cada
# intento y el baseline nunca acumularía (agujero detectado en verificación).
# Solo van descriptores deterministas por nivel.
_CLAVES_DIFICULTAD = frozenset({
    "n_opciones", "n_figuras", "n_rejilla", "n_pasos", "cantidad",
    "n_piezas", "objetivos", "total", "tolerancia_px",
})


def firma_dificultad(cantidad_objetivo: dict | None, nivel: str | None = None) -> str:
    """Firma estable de la dificultad de un intento (nivel + descriptores de
    dificultad), ignorando lo que cambia por instancia.

    Dos intentos con la misma firma son comparables; al cambiar la firma se
    reinicia el baseline (evita la falsa alarma tras subir el nivel).
    """
    partes: list[str] = []
    if nivel not in (None, ""):
        partes.append(f"nivel={nivel}")
    if cantidad_objetivo:
        for clave in sorted(cantidad_objetivo):
            if clave in _CLAVES_DIFICULTAD:
                partes.append(f"{clave}={cantidad_objetivo[clave]}")
    return "|".join(partes) if partes else "base"


def _medianas_tiempo(intentos: list[IntentoObs]) -> dict[str, float]:
    """Mediana del tiempo por ejercicio (para normalizar 'por tipo/plantilla')."""
    por_ejercicio: dict[str, list[float]] = {}
    for it in intentos:
        if it.tiempo_ms and it.tiempo_ms > 0:
            por_ejercicio.setdefault(it.ejercicio_id, []).append(float(it.tiempo_ms))
    return {ej: statistics.median(v) for ej, v in por_ejercicio.items() if v}


def agregar_por_sesion(intentos: list[IntentoObs]) -> list[SesionObs]:
    """Agrega los intentos (ya en orden cronológico) a un punto POR SESIÓN.

    - rendimiento de la sesión = media de sus intentos,
    - dificultad = la más frecuente de la sesión,
    - tiempo_rel = tiempo medio de la sesión normalizado por la mediana de cada
      ejercicio (1.0 = tarda lo normal; >1 = tarda más de lo habitual).
    """
    medianas = _medianas_tiempo(intentos)

    orden: list[str] = []
    grupos: dict[str, list[IntentoObs]] = {}
    for it in intentos:
        if it.sesion_id not in grupos:
            grupos[it.sesion_id] = []
            orden.append(it.sesion_id)
        grupos[it.sesion_id].append(it)

    salida: list[SesionObs] = []
    for sid in orden:
        items = grupos[sid]
        rend = statistics.fmean([x.rendimiento for x in items])
        dificultad = Counter(x.dificultad for x in items).most_common(1)[0][0]
        rels: list[float] = []
        for x in items:
            m = medianas.get(x.ejercicio_id)
            if x.tiempo_ms and m and m > 0:
                rels.append(float(x.tiempo_ms) / m)
        tiempo_rel = statistics.fmean(rels) if rels else None
        salida.append(
            SesionObs(sid, round(rend, 6), dificultad, tiempo_rel, len(items))
        )
    return salida


def segmento_dificultad_actual(items: list) -> list:
    """Tramo FINAL de `items` que comparte la dificultad del último punto.

    Al cambiar la dificultad se reinicia el baseline: solo comparamos dentro del
    nivel/cantidad vigente. Sirve para SesionObs y para IntentoObs (ambos tienen
    atributo `dificultad`).
    """
    if not items:
        return []
    vigente = items[-1].dificultad
    seg: list = []
    for x in reversed(items):
        if x.dificultad == vigente:
            seg.append(x)
        else:
            break
    seg.reverse()
    return seg


@dataclass
class ResultadoTiempo:
    hay_tendencia: bool
    baseline_media: float
    reciente_media: float
    subida_relativa: float
    n_baseline: int
    n_reciente: int


def detectar_tendencia_tiempo(
    serie: list[float],
    ventana_reciente: int = 2,
    min_baseline: int = 4,
    k: float = 1.5,
    subida_minima: float = 0.25,
) -> ResultadoTiempo | None:
    """Detecta que la persona TARDA sistemáticamente más que su propio patrón.

    `serie` es el tiempo (normalizado por ejercicio) de más antiguo a más
    reciente. Alerta solo si la ventana reciente supera media+k*std del baseline
    Y sube al menos `subida_minima` en términos relativos (evita ruido con
    tiempos ~constantes: subida 0 -> nunca dispara).
    """
    if len(serie) < min_baseline + ventana_reciente:
        return None

    baseline = serie[:-ventana_reciente]
    reciente = serie[-ventana_reciente:]

    media_base = statistics.fmean(baseline)
    std_base = statistics.pstdev(baseline) if len(baseline) > 1 else 0.0
    media_rec = statistics.fmean(reciente)
    if media_base <= 0:
        return None

    umbral = media_base + k * std_base
    subida = (media_rec - media_base) / media_base
    hay = (media_rec > umbral) and (subida >= subida_minima)

    return ResultadoTiempo(
        hay_tendencia=hay,
        baseline_media=round(media_base, 4),
        reciente_media=round(media_rec, 4),
        subida_relativa=round(subida, 4),
        n_baseline=len(baseline),
        n_reciente=len(reciente),
    )


@dataclass
class ResultadoMissingness:
    hay_desconexion: bool
    baseline_tasa: float
    reciente_tasa: float
    n_baseline: int
    n_reciente: int


def detectar_missingness(
    serie_tasa: list[float],
    ventana_reciente: int = 2,
    min_baseline: int = 4,
    subida_absoluta: float = 0.25,
    piso_reciente: float = 0.4,
) -> ResultadoMissingness | None:
    """Detecta que la persona DEJA DE PARTICIPAR cada vez más.

    Guarda del neuropsicólogo: dejar de interactuar (no-intento) no puede caer en
    el olvido, porque quien se deteriora suele hacer justo eso. `serie_tasa` es la
    FRACCIÓN de actividades sin interacción por sesión (0..1), de más antigua a
    más reciente. Alerta si la ventana reciente sube de forma sostenida respecto
    al patrón habitual Y supera un piso absoluto (evita falsas alarmas cuando
    todo el histórico ya tenía algo de no-intento por la mezcla de actividades).
    """
    if len(serie_tasa) < min_baseline + ventana_reciente:
        return None

    baseline = serie_tasa[:-ventana_reciente]
    reciente = serie_tasa[-ventana_reciente:]
    media_base = statistics.fmean(baseline)
    media_rec = statistics.fmean(reciente)

    # Sostenido: TODA la ventana reciente por encima del baseline (no un pico).
    sostenido = all(x > media_base for x in reciente)
    hay = (
        sostenido
        and (media_rec - media_base) >= subida_absoluta
        and media_rec >= piso_reciente
    )
    return ResultadoMissingness(
        hay_desconexion=hay,
        baseline_tasa=round(media_base, 4),
        reciente_tasa=round(media_rec, 4),
        n_baseline=len(baseline),
        n_reciente=len(reciente),
    )
