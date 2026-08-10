"""Autocorrección del resultado por plantilla (services/correccion.py)."""
from __future__ import annotations

from app.services.correccion import corregir


def test_seleccion_multiple():
    o = {"correcta": "gato"}
    assert corregir("seleccion_multiple", {"eleccion": "gato"}, o) == "logrado"
    assert corregir("seleccion_multiple", {"eleccion": "perro"}, o) == "no_logrado"
    # No eligió nada -> no-intento.
    assert corregir("seleccion_multiple", {}, o) == "sin_valorar"
    # Sin clave (APK vieja) -> a revisar, no inventar.
    assert corregir("seleccion_multiple", {"eleccion": "gato"}, {}) == "sin_valorar"


def test_memoria_y_busqueda_graduan_y_penalizan_falsos_positivos():
    # Todos los objetivos, sin falsos positivos -> logrado.
    assert corregir("memoria_visual", {"aciertos": 3, "fallos": 0}, {"n_figuras": 3}) == "logrado"
    # 3 aciertos con 4 fallos NO es reconocer -> parcial (tocó bien alguna) no logrado.
    assert corregir("memoria_visual", {"aciertos": 3, "fallos": 4}, {"n_figuras": 3}) == "parcial"
    # Tocó y no acertó ninguna -> no_logrado.
    assert corregir("busqueda_visual", {"aciertos": 0, "fallos": 2}, {"objetivos": 3}) == "no_logrado"
    # No tocó nada -> sin_valorar (no-intento), NO no_logrado.
    assert corregir("busqueda_visual", {"aciertos": 0, "fallos": 0}, {"objetivos": 3}) == "sin_valorar"


def test_secuencia_ordenar():
    o3 = {"orden_correcto_pasos": ["a", "b", "c"]}
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["a", "b", "c"], "movimientos": 2}, o3) == "logrado"
    # 1 de 3 en su sitio (<50%) -> no_logrado.
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["a", "c", "b"], "movimientos": 3}, o3) == "no_logrado"
    # 2 de 4 en su sitio (=50%) -> parcial.
    o4 = {"orden_correcto_pasos": ["a", "b", "c", "d"]}
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["a", "b", "d", "c"], "movimientos": 2}, o4) == "parcial"
    # 0 movimientos = como se presentó -> indistinguible de no intentar.
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["a", "b", "c"], "movimientos": 0}, o3) == "sin_valorar"


def test_arrastrar_posicion():
    o = {"emparejamientos": {"tenedor": "izq", "cuchillo": "der"}}
    assert corregir("arrastrar_posicion",
                    {"colocaciones": {"tenedor": "izq", "cuchillo": "der"}}, o) == "logrado"
    assert corregir("arrastrar_posicion",
                    {"colocaciones": {"tenedor": "izq", "cuchillo": "izq"}}, o) == "parcial"
    assert corregir("arrastrar_posicion", {"colocaciones": {}}, o) == "sin_valorar"


def test_manejo_cantidad_dinero_y_reloj():
    # Dinero: total compuesto == importe objetivo.
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 245, "monedas_usadas": [200, 45]},
                    {"modo": "dinero", "importe_c": 245}) == "logrado"
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 200, "monedas_usadas": [200]},
                    {"modo": "dinero", "importe_c": 245}) == "no_logrado"
    # Reloj con ambigüedad 12h: 3:00 == 15:00.
    assert corregir("manejo_cantidad",
                    {"hora_elegida": 3, "minuto_elegido": 0},
                    {"modo": "reloj", "hora": 15, "minuto": 0}) == "logrado"
    # Vuelta: objetivo = pago - precio.
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 250},
                    {"modo": "vuelta", "pago_c": 500, "precio_c": 250}) == "logrado"


def test_trazo_solo_extremos():
    # Trazo amplio y preciso -> logrado.
    assert corregir("trazo", {"precision": 0.9, "puntos_capturados": 20}, {}) == "logrado"
    # Apenas trazó -> no_logrado.
    assert corregir("trazo", {"precision": 0.9, "puntos_capturados": 3}, {}) == "no_logrado"
    # Banda intermedia -> revisar (sin_valorar).
    assert corregir("trazo", {"precision": 0.6, "puntos_capturados": 20}, {}) == "sin_valorar"
    # No dibujó nada.
    assert corregir("trazo", {"precision": None, "puntos_capturados": 0}, {}) == "sin_valorar"


def test_evocacion_siempre_revisar():
    assert corregir("evocacion_libre", {"n_pedidas": 5}, {}) == "sin_valorar"


def test_plantilla_desconocida_no_revienta():
    assert corregir("algo_raro", {"x": 1}, {}) == "sin_valorar"
