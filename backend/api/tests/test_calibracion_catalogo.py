"""Red de seguridad de calibración: genera CADA actividad del catálogo a los 3
niveles y verifica invariantes de sentido clínico, para que ningún ejercicio sea
trivial (se gana sin ejercer la función) ni imposible, ni se rompa al generar.

Habría cazado el fallo de memoria_visual (rejilla sin distractores en 'alto').
Protege las ~104 actividades ante cambios futuros del catálogo o los generadores.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

import pytest

from app.templates.registry import get_plantilla

_CATALOGO = json.loads(
    (Path(__file__).resolve().parents[1] / "app" / "data" / "catalogo.json").read_text(encoding="utf-8")
)
_NIVELES = ("bajo", "medio", "alto")
_SEMILLAS = 40


def _instancias(actividad, nivel):
    p = get_plantilla(actividad["plantilla_tipo"])
    for s in range(_SEMILLAS):
        yield p.generar(actividad["parametros_json"], nivel=nivel, rng=random.Random(s))


@pytest.mark.parametrize("actividad", _CATALOGO, ids=lambda a: a["nombre"])
def test_actividad_se_genera_y_tiene_sentido(actividad):
    plantilla = actividad["plantilla_tipo"]
    for nivel in _NIVELES:
        for inst in _instancias(actividad, nivel):
            render = inst.render

            if plantilla == "seleccion_multiple":
                opciones = render.get("opciones") or []
                assert len(opciones) >= 2, (actividad["nombre"], nivel)
                correcta = inst.cantidad_objetivo.get("correcta")
                assert correcta in opciones, (actividad["nombre"], "correcta no está entre las opciones")

            elif plantilla == "memoria_visual":
                nrec = inst.cantidad_objetivo["n_figuras"]
                nrej = inst.cantidad_objetivo["n_rejilla"]
                # Nunca la rejilla == lo memorizado (si no, se gana tocando todo);
                # y nunca más de 5 figuras a retener (carga inasumible).
                assert nrej > nrec, (actividad["nombre"], nivel, "rejilla sin distractores")
                assert nrec <= 5, (actividad["nombre"], nivel, "demasiadas figuras a recordar")

            elif plantilla == "busqueda_visual":
                objetivos = render.get("objetivos_en_rejilla") or render.get("n_objetivos")
                rejilla = render.get("rejilla") or render.get("celdas") or []
                if isinstance(rejilla, list) and rejilla:
                    # Debe haber al menos un distractor (no toda la rejilla es objetivo).
                    n_obj = objetivos if isinstance(objetivos, int) else None
                    if n_obj is not None:
                        assert n_obj < len(rejilla), (actividad["nombre"], nivel)

            elif plantilla == "conteo_comparacion":
                modo = render.get("modo")
                if modo in ("cual_tiene_mas", "cual_tiene_menos"):
                    cs = sorted(g["cantidad"] for g in render["grupos"])
                    assert all(1 <= c <= 9 for c in cs), (actividad["nombre"], nivel, cs)
                    margen = cs[-1] - cs[-2] if modo == "cual_tiene_mas" else cs[1] - cs[0]
                    assert margen >= 2, (actividad["nombre"], nivel, "extremo indistinguible", cs)

            elif plantilla == "arrastrar_posicion":
                zonas = {z.get("id") for z in render.get("zonas", [])}
                if len(zonas) >= 2:
                    usadas = {pz.get("zona_correcta") for pz in render.get("piezas", [])}
                    assert len(usadas) >= 2, (actividad["nombre"], nivel, "sin decisión: una sola zona en la muestra")


def test_dificultad_dinero_escala_por_nivel():
    """En dinero, 'alto' debe pedir importes mayores que 'bajo' (personalización real)."""
    din = [a for a in _CATALOGO if a["plantilla_tipo"] == "manejo_cantidad"]
    p = get_plantilla("manejo_cantidad")
    subieron = 0
    total = 0
    for a in din:
        medias = {}
        for nivel in _NIVELES:
            imps = []
            for s in range(30):
                r = p.generar(a["parametros_json"], nivel=nivel, rng=random.Random(s)).render
                # En 'vuelta'/'llega' el importe que escala por nivel es el PRECIO;
                # el `importe_c` del render es la vuelta (derivada) y no lo refleja.
                valor = r.get("precio_c", r.get("importe_c"))
                if valor is not None:
                    imps.append(valor)
            if imps:
                medias[nivel] = sum(imps) / len(imps)
        if "bajo" in medias and "alto" in medias:
            total += 1
            if medias["alto"] > medias["bajo"]:
                subieron += 1
    # En la gran mayoría de actividades de dinero, 'alto' > 'bajo'.
    assert total > 0 and subieron >= total, f"el importe no escala por nivel ({subieron}/{total})"
