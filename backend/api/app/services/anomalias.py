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
from dataclasses import dataclass


# Peso del estado del intento sobre el rendimiento normalizado (0..1).
_PESO_ESTADO = {
    "solo": 1.0,
    "con_ayuda": 0.5,
    "no_completado": 0.0,
}


def rendimiento_intento(estado: str, valores: dict | None) -> float:
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
