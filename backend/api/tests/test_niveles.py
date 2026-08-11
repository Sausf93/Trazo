"""Tests de los niveles de dificultad por CANTIDAD (básico/intermedio/alto).

El `nivel` (bajo/medio/alto) fija cuántas imágenes/objetos tiene el ejercicio:
básico ~3 · intermedio ~6-8 · alto ~10-12 (ver MODELO-OPERATIVO).
"""
import random

from app.templates.base import PlantillaBase
from app.templates.tipos import (
    PlantillaConteoComparacion,
    PlantillaMemoriaVisual,
)

RNG = lambda: random.Random(1234)  # noqa: E731  (semilla fija = determinista)


def test_banda_cantidad():
    assert PlantillaBase.banda_cantidad("bajo") == (3, 3)
    assert PlantillaBase.banda_cantidad("medio") == (6, 8)
    assert PlantillaBase.banda_cantidad("alto") == (10, 12)
    assert PlantillaBase.banda_cantidad("BAJO") == (3, 3)  # case-insensitive
    assert PlantillaBase.banda_cantidad(None) is None
    assert PlantillaBase.banda_cantidad({"recordar_min": 2}) is None  # dict -> no banda


def _banco(n):
    return [{"id": f"fig{i}", "label": f"fig{i}"} for i in range(n)]


def test_memoria_bajo_medio_alto():
    p = PlantillaMemoriaVisual()
    params = {"banco": _banco(16)}
    assert p.generar(params, nivel="bajo", rng=RNG()).cantidad_objetivo["n_figuras"] == 3
    n_medio = p.generar(params, nivel="medio", rng=RNG()).cantidad_objetivo["n_figuras"]
    assert 6 <= n_medio <= 8
    n_alto = p.generar(params, nivel="alto", rng=RNG()).cantidad_objetivo["n_figuras"]
    assert 10 <= n_alto <= 12


def test_memoria_alto_se_limita_al_banco():
    # Banco pequeño: alto no puede superar el tamaño del banco (degradación elegante).
    p = PlantillaMemoriaVisual()
    n = p.generar({"banco": _banco(6)}, nivel="alto", rng=RNG()).cantidad_objetivo["n_figuras"]
    assert n <= 6


def test_conteo_por_nivel():
    # En modo "sumar" (o contar) las cantidades respetan la banda del nivel.
    p = PlantillaConteoComparacion()
    params = {"objetos": ["manzana", "pera"], "modo": "sumar"}
    for nivel, (lo, hi) in [("bajo", (3, 3)), ("medio", (6, 8)), ("alto", (10, 12))]:
        inst = p.generar(params, nivel=nivel, rng=RNG())
        for c in inst.cantidad_objetivo["cantidades"]:
            assert lo <= c <= hi, f"{nivel}: {c} fuera de [{lo},{hi}]"


def test_conteo_comparacion_extremo_unico():
    # Una comparación DEBE tener un único ganador; si empata, no tiene respuesta.
    # Incluye la banda degenerada "bajo" (3,3), que se amplía para poder desempatar.
    p = PlantillaConteoComparacion()
    for modo in ("cual_tiene_mas", "cual_tiene_menos"):
        params = {"objetos": ["manzana", "pera", "uva"], "modo": modo}
        for nivel in ("bajo", "medio", "alto"):
            for semilla in range(50):
                inst = p.generar(params, nivel=nivel, rng=random.Random(semilla))
                cs = inst.cantidad_objetivo["cantidades"]
                extremo = max(cs) if modo == "cual_tiene_mas" else min(cs)
                assert cs.count(extremo) == 1, f"{modo}/{nivel}: empate en {cs}"




def test_nivel_dict_sigue_funcionando():
    # Un nivel en forma de dict (nivel_base_json) mantiene el comportamiento anterior.
    p = PlantillaMemoriaVisual()
    params = {"banco": _banco(16), "recordar_min": 4, "recordar_max": 4}
    n = p.generar(params, nivel={"recordar_min": 4, "recordar_max": 4}, rng=RNG()).cantidad_objetivo["n_figuras"]
    assert n == 4
