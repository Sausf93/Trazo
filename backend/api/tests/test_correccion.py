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
    # Acierta MÁS de lo que falla (discrimina) -> parcial.
    assert corregir("memoria_visual", {"aciertos": 3, "fallos": 1}, {"n_figuras": 3}) == "parcial"
    # 3 aciertos con 4 fallos: "tocar a bulto" (tantos o más fallos que aciertos)
    # NO discrimina -> no_logrado (antes daba 'parcial' e inflaba el desempeño).
    assert corregir("memoria_visual", {"aciertos": 3, "fallos": 4}, {"n_figuras": 3}) == "no_logrado"
    # Tocó y no acertó ninguna -> no_logrado.
    assert corregir("busqueda_visual", {"aciertos": 0, "fallos": 2}, {"objetivos": 3}) == "no_logrado"
    # No tocó nada -> sin_valorar (no-intento), NO no_logrado.
    assert corregir("busqueda_visual", {"aciertos": 0, "fallos": 0}, {"objetivos": 3}) == "sin_valorar"


def test_secuencia_ordenar():
    o3 = {"orden_correcto_pasos": ["a", "b", "c"]}
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["a", "b", "c"], "movimientos": 2}, o3) == "logrado"
    # Solo b y c intercambiados: la exactitud posicional es 1/3, pero el ORDEN
    # RELATIVO es 2/3 (a antes que b y c) -> parcial (más justo que no_logrado).
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["a", "c", "b"], "movimientos": 3}, o3) == "parcial"
    # Orden totalmente al revés -> no_logrado (0 pares concordantes).
    assert corregir("secuencia_ordenar",
                    {"orden_final": ["c", "b", "a"], "movimientos": 3}, o3) == "no_logrado"
    # Último par intercambiado en 4: orden relativo alto -> parcial.
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
    # Dinero CERCA (2,40 para 2,45 = 5 cént.) -> parcial, no fallo seco.
    assert corregir("manejo_cantidad",
                    {"total_compuesto": 240, "monedas_usadas": [200, 40]},
                    {"modo": "dinero", "importe_c": 245}) == "parcial"
    # Reloj: acierta la HORA pero falla el minuto -> parcial.
    assert corregir("manejo_cantidad",
                    {"hora_elegida": 3, "minuto_elegido": 30},
                    {"modo": "reloj", "hora": 15, "minuto": 0}) == "parcial"
    # Reloj: falla la hora -> no_logrado.
    assert corregir("manejo_cantidad",
                    {"hora_elegida": 5, "minuto_elegido": 0},
                    {"modo": "reloj", "hora": 15, "minuto": 0}) == "no_logrado"


def test_trazo_solo_extremos():
    # Trazo amplio y preciso -> logrado.
    assert corregir("trazo", {"precision": 0.9, "puntos_capturados": 20}, {}) == "logrado"
    # Apenas trazó -> no_logrado.
    assert corregir("trazo", {"precision": 0.9, "puntos_capturados": 3}, {}) == "no_logrado"
    # Banda intermedia -> revisar (sin_valorar).
    assert corregir("trazo", {"precision": 0.6, "puntos_capturados": 20}, {}) == "sin_valorar"
    # No dibujó nada.
    assert corregir("trazo", {"precision": None, "puntos_capturados": 0}, {}) == "sin_valorar"


def test_parejas_puntua_por_errores():
    o = {"n_pares": 6}
    # Tablero completo sin fallos -> logrado.
    assert corregir("parejas", {"pares_encontrados": 6, "errores": 0}, o) == "logrado"
    # Completo con bastantes fallos (6 aciertos / 12 destapes) -> parcial.
    assert corregir("parejas", {"pares_encontrados": 6, "errores": 6}, o) == "parcial"
    # Completo con muchísimos fallos -> no_logrado.
    assert corregir("parejas", {"pares_encontrados": 6, "errores": 18}, o) == "no_logrado"
    # Lo dejó a medias: no puntúa (no tocar todo no es fallar).
    assert corregir("parejas", {"pares_encontrados": 3, "errores": 2}, o) == "sin_valorar"
    # Sin datos -> sin_valorar.
    assert corregir("parejas", {}, o) == "sin_valorar"


def test_plantilla_desconocida_no_revienta():
    assert corregir("algo_raro", {"x": 1}, {}) == "sin_valorar"
