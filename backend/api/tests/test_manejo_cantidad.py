"""Tests del motor de dinero/cantidad (`PlantillaManejoCantidad`).

Lo que importa de verdad en esta plantilla:
  - trabaja en CÉNTIMOS enteros (sin errores de coma flotante),
  - los importes con céntimos se forman y se formatean bien ('2,45 €'),
  - el desglose de monedas/billetes suma exactamente el importe,
  - "la vuelta" se calcula correctamente (pago - precio) y su desglose cuadra,
  - el modo "¿llega para pagar?" decide bien,
  - cada tirada varía (importes distintos) según banda/rango.
"""
from __future__ import annotations

import random

from app.templates.tipos import (
    PlantillaManejoCantidad,
    _desglose_greedy,
    _fmt_eur,
)


def _pl():
    return PlantillaManejoCantidad()


# ---- formato en céntimos ----

def test_formato_euros_con_centimos():
    assert _fmt_eur(245) == "2,45 €"
    assert _fmt_eur(11223) == "112,23 €"
    assert _fmt_eur(500) == "5,00 €"
    assert _fmt_eur(7) == "0,07 €"


def test_desglose_suma_exacta_con_centimos():
    denoms = [1, 2, 5, 10, 20, 50, 100, 200]
    for importe in (1, 45, 99, 245, 999, 12300):
        desg = _desglose_greedy(importe, denoms)
        assert sum(int(k) * v for k, v in desg.items()) == importe


# ---- modo dinero: reúne el importe ----

def test_dinero_desglose_cuadra_y_hay_centimos():
    pl = _pl()
    params = {
        "modo": "dinero", "con_centimos": True,
        "denominaciones_c": [1, 2, 5, 10, 20, 50, 100, 200],
        "importe_min_c": 45, "importe_max_c": 990,
    }
    rng = random.Random(1)
    vistos = set()
    for _ in range(40):
        inst = pl.generar(params, rng=rng)
        importe = inst.render["importe_c"]
        desg = inst.solucion["desglose_c"]
        # el desglose suma exactamente el importe objetivo
        assert sum(int(k) * v for k, v in desg.items()) == importe
        # importe dentro del rango
        assert 45 <= importe <= 990
        vistos.add(importe)
    # cambia de una tirada a otra (aleatoriedad real)
    assert len(vistos) > 5


def test_dinero_con_billetes_importes_grandes():
    pl = _pl()
    params = {
        "modo": "dinero", "con_centimos": True,
        "denominaciones_c": [50, 100, 200, 500, 1000, 2000, 5000, 10000],
        "importe_min_c": 1500, "importe_max_c": 24000, "paso_c": 50,
    }
    rng = random.Random(2)
    uso_billete = False
    for _ in range(40):
        inst = pl.generar(params, rng=rng)
        importe = inst.render["importe_c"]
        desg = inst.solucion["desglose_c"]
        assert sum(int(k) * v for k, v in desg.items()) == importe
        if any(int(k) >= 500 for k in desg):
            uso_billete = True
    assert uso_billete  # al menos una tirada usa billetes


# ---- modo vuelta ----

def test_vuelta_bien_calculada_y_desglose_cuadra():
    pl = _pl()
    params = {
        "modo": "vuelta", "con_centimos": True,
        "denominaciones_c": [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000],
        "paga_con_c": [500, 1000, 2000],
        "importe_min_c": 120, "importe_max_c": 1850,
    }
    rng = random.Random(3)
    for _ in range(40):
        inst = pl.generar(params, rng=rng)
        r, sol = inst.render, inst.solucion
        assert sol["vuelta_c"] == r["pago_c"] - r["precio_c"]
        assert sol["vuelta_c"] >= 0
        assert r["pago_c"] >= r["precio_c"]
        desg = sol["desglose_c"]
        assert sum(int(k) * v for k, v in desg.items()) == sol["vuelta_c"]


# ---- modo llega_para_pagar ----

def test_llega_para_pagar_decide_bien():
    pl = _pl()
    params = {
        "modo": "llega_para_pagar", "con_centimos": True,
        "denominaciones_c": [5, 10, 20, 50, 100, 200],
        "importe_min_c": 60, "importe_max_c": 700,
    }
    rng = random.Random(4)
    for _ in range(40):
        inst = pl.generar(params, rng=rng)
        r, sol = inst.render, inst.solucion
        assert sol["llega"] == (r["disponible_c"] >= r["precio_c"])


# ---- reloj ----

def test_reloj_devuelve_hora_valida():
    pl = _pl()
    rng = random.Random(5)
    for _ in range(20):
        inst = pl.generar({"modo": "reloj"}, rng=rng)
        assert 1 <= inst.solucion["hora"] <= 12
        assert 0 <= inst.solucion["minuto"] < 60
