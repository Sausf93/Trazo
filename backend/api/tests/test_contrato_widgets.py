"""Contrato widget Flutter -> corrector: los payloads que envían los widgets
reales deben puntuarse bien. Cubre dos bugs que llegaron a producción:
 - dinero: el widget acumula en EUROS (2.45), el objetivo está en céntimos (245).
 - conteo: el widget manda {grupo, objeto} en las comparaciones, no una cadena.
"""
from __future__ import annotations

from app.services.correccion import corregir


def test_dinero_en_euros_se_puntua_bien():
    # Como lo manda manejo_cantidad_widget.dart: total_compuesto en euros.
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 2.45, "modo": "dinero"},
                    {"modo": "dinero", "importe_c": 245}) == "logrado"
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 3.00, "modo": "dinero"},
                    {"modo": "dinero", "importe_c": 245}) == "no_logrado"


def test_dinero_en_centimos_sigue_valiendo():
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 245, "modo": "dinero"},
                    {"modo": "dinero", "importe_c": 245}) == "logrado"


def test_vuelta_en_euros():
    # vuelta = pago - precio (en céntimos). El widget manda euros.
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 1.55, "modo": "vuelta"},
                    {"modo": "vuelta", "pago_c": 500, "precio_c": 345}) == "logrado"


def test_conteo_comparacion_respuesta_como_objeto():
    # Como lo manda conteo_comparacion_widget.dart: {grupo, objeto}.
    ok = {"respuesta": {"grupo": 0, "objeto": "manzana"}, "modo": "cual_tiene_mas"}
    mal = {"respuesta": {"grupo": 1, "objeto": "pera"}, "modo": "cual_tiene_mas"}
    sol = {"modo": "cual_tiene_mas", "solucion": {"objeto_mayor": "manzana"}}
    assert corregir("conteo_comparacion", ok, sol) == "logrado"
    assert corregir("conteo_comparacion", mal, sol) == "no_logrado"
