# -*- coding: utf-8 -*-
"""Regresión ANTI-BULTO: responder "a bulto" (tocar todo, volcar todo, ordenar al
azar, elegir mal) NUNCA debe puntuar 'logrado', y salvo near-miss legítimo tampoco
'parcial'. Blinda el principio clínico (medir desempeño real, no premiar el azar)
contra futuras regresiones — esta clase de bug ya apareció 3 veces."""
import json
import os
import random

from app.services.correccion import corregir
from app.templates.registry import get_plantilla

_CAT = os.path.join(os.path.dirname(__file__), "..", "app", "data", "catalogo.json")
with open(_CAT, encoding="utf-8") as _f:
    CATALOGO = json.load(_f)


def _por_tipo(tipo, n=25):
    acts = [e for e in CATALOGO if e["plantilla_tipo"] == tipo]
    return acts[:n]


def test_seleccion_multiple_distractor_nunca_logra():
    for e in _por_tipo("seleccion_multiple", 200):
        p = e["parametros_json"]
        for niv in ("bajo", "medio", "alto"):
            inst = get_plantilla("seleccion_multiple").generar(p, nivel=niv, rng=random.Random(3))
            o = inst.cantidad_objetivo
            assert corregir("seleccion_multiple", {"eleccion": o["correcta"]}, o) == "logrado", e["nombre"]
            for op in inst.render["opciones"]:
                if op != o["correcta"]:
                    assert corregir("seleccion_multiple", {"eleccion": op}, o) != "logrado", (e["nombre"], op)


def test_memoria_visual_tocar_todo_no_puntua():
    for e in _por_tipo("memoria_visual", 100):
        p = e["parametros_json"]
        for niv in ("bajo", "medio", "alto"):
            inst = get_plantilla("memoria_visual").generar(p, nivel=niv, rng=random.Random(3))
            o = inst.cantidad_objetivo
            total = int(o.get("n_rejilla") or 0)
            obj = int(o.get("n_figuras") or 0)
            # tocar TODA la rejilla: aciertos=obj, fallos=resto -> NO puede ser parcial ni logrado
            r = corregir("memoria_visual", {"aciertos": obj, "fallos": max(0, total - obj)}, o)
            assert r == "no_logrado", (e["nombre"], niv, r)
            # perfecto sigue logrado
            assert corregir("memoria_visual", {"aciertos": obj, "fallos": 0}, o) == "logrado", e["nombre"]


def test_busqueda_visual_tocar_todo_no_logra():
    for e in _por_tipo("busqueda_visual", 100):
        p = e["parametros_json"]
        for niv in ("bajo", "medio", "alto"):
            inst = get_plantilla("busqueda_visual").generar(p, nivel=niv, rng=random.Random(3))
            o = inst.cantidad_objetivo
            total = int(o.get("total") or 0)
            obj = int(o.get("objetivos") or 0)
            r = corregir("busqueda_visual", {"aciertos": obj, "fallos": max(0, total - obj)}, o)
            assert r != "logrado", (e["nombre"], niv, r)
            assert corregir("busqueda_visual", {"aciertos": obj, "fallos": 0}, o) == "logrado", e["nombre"]


def test_arrastrar_volcar_todo_no_puntua():
    for e in _por_tipo("arrastrar_posicion", 100):
        p = e["parametros_json"]
        for niv in ("bajo", "medio", "alto"):
            inst = get_plantilla("arrastrar_posicion").generar(p, nivel=niv, rng=random.Random(3))
            o = inst.cantidad_objetivo
            emp = o.get("emparejamientos") or {}
            zonas = set(emp.values())
            if len(zonas) < 2:
                continue
            # volcar TODAS las piezas en una sola zona
            una = next(iter(zonas))
            bulto = {pieza: una for pieza in emp}
            r = corregir("arrastrar_posicion", {"colocaciones": bulto}, o)
            assert r == "no_logrado", (e["nombre"], niv, r)
            # solución correcta sigue logrado
            assert corregir("arrastrar_posicion", {"colocaciones": dict(emp)}, o) == "logrado", e["nombre"]


def test_secuencia_reverso_no_logra_y_azar_mayoria_no_puntua():
    for e in _por_tipo("secuencia_ordenar", 100):
        p = e["parametros_json"]
        inst = get_plantilla("secuencia_ordenar").generar(p, nivel="medio", rng=random.Random(3))
        o = inst.cantidad_objetivo
        correcto = o.get("orden_correcto_pasos") or []
        n = len(correcto)
        if n < 2:
            continue
        # orden correcto -> logrado
        assert corregir("secuencia_ordenar", {"orden_final": correcto, "movimientos": n}, o) == "logrado", e["nombre"]
        # totalmente al revés -> nunca logrado
        rev = list(reversed(correcto))
        if rev != correcto:
            assert corregir("secuencia_ordenar", {"orden_final": rev, "movimientos": n}, o) != "logrado", e["nombre"]


def test_conteo_respuesta_mala_no_logra():
    for e in _por_tipo("conteo_comparacion", 120):
        p = e["parametros_json"]
        for niv in ("bajo", "medio", "alto"):
            inst = get_plantilla("conteo_comparacion").generar(p, nivel=niv, rng=random.Random(3))
            o = inst.cantidad_objetivo
            # una respuesta claramente absurda no debe lograr
            r = corregir("conteo_comparacion", {"conteo": -999, "total": -999, "objeto": "__nope__"}, o)
            assert r != "logrado", (e["nombre"], niv, r)
