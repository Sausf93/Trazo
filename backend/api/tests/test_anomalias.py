"""Tests del motor de detección de anomalías (lógica pura, sin BD).

Es la pieza que más confianza necesita: afecta a decisiones sobre personas
vulnerables. Cubrimos los casos que importan de verdad:
  - no dispara sin datos suficientes,
  - no dispara ante estabilidad o mejora,
  - sí dispara ante un empeoramiento sostenido,
  - NO dispara ante un único mal día (ruido).
"""
from app.services.anomalias import (
    detectar_desviacion,
    rendimiento_intento,
)


# ---- rendimiento_intento ----

def test_no_completado_es_cero():
    assert rendimiento_intento("no_completado", {"precision": 0.9}) == 0.0


def test_con_ayuda_pone_techo_a_la_mitad():
    assert rendimiento_intento("con_ayuda", {"precision": 1.0}) == 0.5


def test_solo_usa_precision():
    assert rendimiento_intento("solo", {"precision": 0.8}) == 0.8


def test_solo_con_correcto_booleano():
    assert rendimiento_intento("solo", {"correcto": True}) == 1.0
    assert rendimiento_intento("solo", {"correcto": False}) == 0.0


def test_solo_con_aciertos_fallos():
    assert rendimiento_intento("solo", {"aciertos": 3, "fallos": 1}) == 0.75


# ---- detectar_desviacion ----

def test_sin_datos_suficientes_devuelve_none():
    assert detectar_desviacion([0.8, 0.8, 0.8]) is None


def test_estabilidad_no_dispara():
    serie = [0.80, 0.81, 0.79, 0.80, 0.82, 0.80, 0.81, 0.80]
    res = detectar_desviacion(serie)
    assert res is not None
    assert res.hay_desviacion is False


def test_mejora_no_dispara():
    serie = [0.60, 0.62, 0.65, 0.68, 0.70, 0.73, 0.80, 0.85]
    res = detectar_desviacion(serie)
    assert res is not None
    assert res.hay_desviacion is False


def test_empeoramiento_sostenido_dispara():
    # Estable alto y luego cae claramente en las dos últimas.
    serie = [0.88, 0.90, 0.89, 0.91, 0.90, 0.90, 0.60, 0.55]
    res = detectar_desviacion(serie)
    assert res is not None
    assert res.hay_desviacion is True
    assert res.caida > 0


def test_un_solo_mal_dia_no_dispara():
    # Baja una sola sesión y se recupera -> no debe alertar (es ruido).
    serie = [0.85, 0.86, 0.84, 0.85, 0.55, 0.86, 0.85, 0.84]
    res = detectar_desviacion(serie)
    assert res is not None
    assert res.hay_desviacion is False


def test_caida_minima_evita_falsos_positivos_con_std_cero():
    # Serie perfectamente plana y una caída minúscula: no debe alertar.
    serie = [0.90] * 6 + [0.89, 0.89]
    res = detectar_desviacion(serie)
    assert res is not None
    assert res.hay_desviacion is False
