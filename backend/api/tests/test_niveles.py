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
    # Banda PROPIA y suave (la memoria de un mayor con deterioro ronda 3-4 ítems):
    # bajo=3, medio=4, alto=5. NO las bandas genéricas (6-8/10-12), imposibles.
    p = PlantillaMemoriaVisual()
    params = {"banco": _banco(16)}
    assert p.generar(params, nivel="bajo", rng=RNG()).cantidad_objetivo["n_figuras"] == 3
    assert p.generar(params, nivel="medio", rng=RNG()).cantidad_objetivo["n_figuras"] == 4
    assert p.generar(params, nivel="alto", rng=RNG()).cantidad_objetivo["n_figuras"] == 5


def test_memoria_siempre_hay_distractores():
    # La rejilla de selección NUNCA puede ser idéntica a lo memorizado (si no, se
    # "gana" tocando todo). Siempre debe quedar al menos 1 distractor.
    p = PlantillaMemoriaVisual()
    for banco_n in (8, 9, 12, 16):
        for nivel in ("bajo", "medio", "alto"):
            inst = p.generar({"banco": _banco(banco_n)}, nivel=nivel, rng=RNG())
            n_rec = len(inst.render["a_recordar"])
            n_rej = len(inst.render["rejilla_seleccion"])
            assert n_rej - n_rec >= 1, (banco_n, nivel, n_rec, n_rej)


def test_memoria_banco_pequeno_degrada_bien():
    # Banco pequeño: se reduce lo memorizado para dejar sitio a distractores.
    p = PlantillaMemoriaVisual()
    inst = p.generar({"banco": _banco(6)}, nivel="alto", rng=RNG())
    n_rec = inst.cantidad_objetivo["n_figuras"]
    n_rej = len(inst.render["rejilla_seleccion"])
    assert n_rec <= 5 and n_rej - n_rec >= 1


def test_conteo_por_nivel():
    p = PlantillaConteoComparacion()
    # "contar" (un solo grupo) respeta la banda del nivel.
    pc = {"objetos": ["manzana"], "modo": "contar"}
    for nivel, (lo, hi) in [("bajo", (3, 3)), ("medio", (6, 8)), ("alto", (10, 12))]:
        # Cuando lo==hi el generador ensancha en 1 (necesita rango); se admite hi+1.
        tope = max(hi, lo + 1)
        for s in range(30):
            inst = p.generar(pc, nivel=nivel, rng=random.Random(s))
            c = inst.cantidad_objetivo["cantidades"][0]
            assert lo <= c <= tope, f"{nivel}: {c} fuera de [{lo},{tope}]"
    # "sumar" acota el TOTAL a <=15 (no obliga a sumar decenas de objetos), y sube
    # con el nivel dentro de ese tope.
    ps = {"objetos": ["manzana", "pera"], "modo": "sumar"}
    for nivel in ("bajo", "medio", "alto"):
        for s in range(30):
            inst = p.generar(ps, nivel=nivel, rng=random.Random(s))
            total = sum(inst.cantidad_objetivo["cantidades"])
            assert 0 < total <= 15, f"{nivel}: total {total} fuera de (0,15]"


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
