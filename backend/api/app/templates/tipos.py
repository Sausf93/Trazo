"""Las 8 plantillas de ejercicio de Trazo.

Cada una toma los `parametros` del catálogo + el `nivel` de la persona y produce
una instancia con CANTIDADES CAMBIANTES, por dos motivos (ver presentación):
  1. Evita que se memorice la respuesta sin razonar (falsearía la métrica).
  2. Permite subir/bajar exigencia sin que se note como examen.
"""
from __future__ import annotations

import random
from typing import Any

from app.templates.base import InstanciaEjercicio, PlantillaBase


def _rango(nivel, parametros, clave_min, clave_max, def_min, def_max, rng):
    """Devuelve un entero dentro del rango efectivo (nivel manda sobre parámetros)."""
    lo = PlantillaBase._nivel_val(nivel, clave_min, parametros.get(clave_min, def_min))
    hi = PlantillaBase._nivel_val(nivel, clave_max, parametros.get(clave_max, def_max))
    lo, hi = int(lo), int(hi)
    if hi < lo:
        hi = lo
    return rng.randint(lo, hi)


class PlantillaTrazo(PlantillaBase):
    """Grafomotricidad, copiar figuras, unir puntos, copiar patrón, completar dibujo."""

    tipo = "trazo"
    metricas = ["precision", "tiempo_ms", "desviacion_media", "longitud_recorrida"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        figuras = parametros.get("figuras") or [
            {"id": "onda", "path": "M20,100 Q90,20 150,80 T280,60"},
        ]
        figura = rng.choice(figuras)
        tolerancia = self._nivel_val(nivel, "tolerancia_px", parametros.get("tolerancia_px", 24))
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": parametros.get("instruccion", "Sigue la línea con el dedo"),
                "guide_path": figura["path"],
                "tolerancia_px": tolerancia,
                "viewbox": parametros.get("viewbox", "0 0 300 140"),
            },
            cantidad_objetivo={"figura_id": figura.get("id"), "tolerancia_px": tolerancia},
            solucion={"guide_path": figura["path"]},
            metricas=self.metricas,
        )


class PlantillaSeleccionMultiple(PlantillaBase):
    """El intruso, palabra e imagen, cómo se llama esto, qué sonido es, solo un trozo..."""

    tipo = "seleccion_multiple"
    metricas = ["correcto", "tiempo_ms", "num_toques"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        items = parametros.get("items") or []
        if not items:
            raise ValueError("seleccion_multiple requiere 'items' en parametros")
        item = rng.choice(items)
        n_opciones = _rango(nivel, parametros, "opciones_min", "opciones_max", 3, 4, rng)

        correcta = item["correcta"]
        distractores = [d for d in item.get("distractores", []) if d != correcta]
        rng.shuffle(distractores)
        opciones = [correcta] + distractores[: max(1, n_opciones - 1)]
        rng.shuffle(opciones)

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": item.get("instruccion", parametros.get("instruccion", "Elige la correcta")),
                "enunciado": item.get("enunciado"),
                "imagen": item.get("imagen"),
                "audio": item.get("audio"),
                "opciones": opciones,
            },
            cantidad_objetivo={"n_opciones": len(opciones), "item_id": item.get("id")},
            solucion={"correcta": correcta},
            metricas=self.metricas,
        )


class PlantillaMemoriaVisual(PlantillaBase):
    """Memoria de figuras, la lista corta."""

    tipo = "memoria_visual"
    metricas = ["aciertos", "fallos", "tiempo_ms"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        banco = parametros.get("banco") or []
        if len(banco) < 4:
            raise ValueError("memoria_visual requiere al menos 4 elementos en 'banco'")
        n = _rango(nivel, parametros, "recordar_min", "recordar_max", 2, 5, rng)
        n = min(n, len(banco))

        a_recordar = rng.sample(banco, n)
        restantes = [x for x in banco if x not in a_recordar]
        n_distractores = min(len(restantes), max(n, parametros.get("distractores", n)))
        distractores = rng.sample(restantes, n_distractores) if restantes else []
        rejilla = a_recordar + distractores
        rng.shuffle(rejilla)

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": parametros.get("instruccion", "Memoriza estas figuras"),
                "segundos_memorizar": self._nivel_val(nivel, "segundos", parametros.get("segundos", 60)),
                "a_recordar": a_recordar,
                "rejilla_seleccion": rejilla,
            },
            cantidad_objetivo={"n_figuras": n, "n_rejilla": len(rejilla)},
            solucion={"correctas": [x.get("id", x) for x in a_recordar]},
            metricas=self.metricas,
        )


class PlantillaSecuenciaOrdenar(PlantillaBase):
    """Ordenar pasos de una tarea, vestirse en orden, seguir la serie."""

    tipo = "secuencia_ordenar"
    metricas = ["correcto", "movimientos", "tiempo_ms"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        tareas = parametros.get("tareas") or []
        if not tareas:
            raise ValueError("secuencia_ordenar requiere 'tareas' en parametros")
        tarea = rng.choice(tareas)
        pasos_ordenados = tarea["pasos"]  # ya en orden correcto

        # Recorta al nivel: nº de pasos a presentar.
        n = _rango(nivel, parametros, "pasos_min", "pasos_max", 3, len(pasos_ordenados), rng)
        n = min(n, len(pasos_ordenados))
        pasos_ordenados = pasos_ordenados[:n]

        barajados = list(enumerate(pasos_ordenados))  # (indice_correcto, paso)
        rng.shuffle(barajados)

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": tarea.get("instruccion", parametros.get("instruccion", "Ordena los pasos")),
                "titulo": tarea.get("titulo"),
                "pasos_barajados": [{"paso": p, "pos_mostrada": i} for i, (_, p) in enumerate(barajados)],
            },
            cantidad_objetivo={"n_pasos": n, "tarea_id": tarea.get("id")},
            solucion={"orden_correcto": [idx for idx, _ in barajados]},
            metricas=self.metricas,
        )


class PlantillaConteoComparacion(PlantillaBase):
    """Cuál tiene más, cuenta cuántos hay, cuenta y suma sin decir suma, de mayor a menor."""

    tipo = "conteo_comparacion"
    metricas = ["correcto", "tiempo_ms"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        objetos = parametros.get("objetos") or ["pato_amarillo", "pato_verde"]
        modo = parametros.get("modo", "cual_tiene_mas")  # cual_tiene_mas | contar | sumar
        lo = self._nivel_val(nivel, "cantidad_min", parametros.get("cantidad_min", 2))
        hi = self._nivel_val(nivel, "cantidad_max", parametros.get("cantidad_max", 8))

        grupos = []
        for obj in objetos[:3]:
            grupos.append({"objeto": obj, "cantidad": rng.randint(int(lo), int(hi))})

        if modo == "cual_tiene_mas":
            gmax = max(grupos, key=lambda g: g["cantidad"])
            solucion = {"objeto_mayor": gmax["objeto"]}
        elif modo == "sumar":
            solucion = {"total": sum(g["cantidad"] for g in grupos)}
        else:  # contar (uno concreto)
            objetivo = rng.choice(grupos)
            solucion = {"objeto": objetivo["objeto"], "cantidad": objetivo["cantidad"]}

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": parametros.get("instruccion", "¿Cuál tiene más?"),
                "modo": modo,
                "grupos": grupos,
            },
            cantidad_objetivo={"modo": modo, "cantidades": [g["cantidad"] for g in grupos]},
            solucion=solucion,
            metricas=self.metricas,
        )


class PlantillaArrastrarPosicion(PlantillaBase):
    """Poner la mesa, encaja la pieza, la lista de la compra."""

    tipo = "arrastrar_posicion"
    metricas = ["colocados_correctos", "colocados_incorrectos", "tiempo_ms"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        piezas = parametros.get("piezas") or []
        if not piezas:
            raise ValueError("arrastrar_posicion requiere 'piezas' en parametros")
        # Cantidad cambiante: p.ej. nº de comensales al poner la mesa.
        n = _rango(nivel, parametros, "cantidad_min", "cantidad_max", 2, 4, rng)
        seleccion = rng.sample(piezas, min(n, len(piezas))) if parametros.get("muestrear") else piezas

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": parametros.get("instruccion", "Arrastra cada cosa a su sitio"),
                "multiplicador": n,  # p.ej. comensales
                "piezas": seleccion,
                "zonas": parametros.get("zonas", []),
            },
            cantidad_objetivo={"cantidad": n, "n_piezas": len(seleccion)},
            solucion={"emparejamientos": {p["id"]: p.get("zona_correcta") for p in seleccion if "id" in p}},
            metricas=self.metricas,
        )


class PlantillaEvocacionLibre(PlantillaBase):
    """Objetos por categoría, palabras por sílaba, completar refranes.

    La respuesta es abierta (dicha/escrita) — la valida la integradora desde su
    control, no se autocorrige. Se registra cuántas válidas sobre las pedidas.
    """

    tipo = "evocacion_libre"
    metricas = ["n_pedidas", "n_validas", "tiempo_ms"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        prompts = parametros.get("prompts") or [{"texto": "objetos de la cocina"}]
        prompt = rng.choice(prompts)
        n_pedidas = _rango(nivel, parametros, "pedir_min", "pedir_max", 5, 10, rng)

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": parametros.get("instruccion", "Di o escribe:"),
                "prompt": prompt,
                "n_pedidas": n_pedidas,
                "respuesta_abierta": True,
            },
            cantidad_objetivo={"n_pedidas": n_pedidas, "prompt": prompt},
            solucion={"validacion": "manual_integradora"},
            metricas=self.metricas,
        )


class PlantillaManejoCantidad(PlantillaBase):
    """Dinero, la vuelta, qué hora marca."""

    tipo = "manejo_cantidad"
    metricas = ["correcto", "tiempo_ms", "num_ajustes"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        modo = parametros.get("modo", "dinero")  # dinero | vuelta | reloj

        if modo == "reloj":
            hora = rng.randint(1, 12)
            minuto = rng.choice(parametros.get("minutos", [0, 15, 30, 45]))
            return InstanciaEjercicio(
                plantilla=self.tipo,
                render={"instruccion": "¿Qué hora marca?", "modo": modo, "hora": hora, "minuto": minuto},
                cantidad_objetivo={"hora": hora, "minuto": minuto},
                solucion={"hora": hora, "minuto": minuto},
                metricas=self.metricas,
            )

        monedas = parametros.get("monedas", [1, 2, 5])
        total_min = self._nivel_val(nivel, "total_min", parametros.get("total_min", 5))
        total_max = self._nivel_val(nivel, "total_max", parametros.get("total_max", 12))
        total = rng.randint(int(total_min), int(total_max))

        if modo == "vuelta":
            billete = min(b for b in parametros.get("billetes", [10, 20]) if b >= total) \
                if any(b >= total for b in parametros.get("billetes", [10, 20])) else 20
            return InstanciaEjercicio(
                plantilla=self.tipo,
                render={
                    "instruccion": f"Pagas con {billete}€ algo que cuesta {total}€. ¿Cuánto te devuelven?",
                    "modo": modo, "precio": total, "billete": billete, "monedas": monedas,
                },
                cantidad_objetivo={"precio": total, "billete": billete},
                solucion={"vuelta": billete - total},
                metricas=self.metricas,
            )

        # modo dinero: alcanzar un total con monedas
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": f"Junta {total}€ con las monedas",
                "modo": modo, "total": total, "monedas": monedas,
            },
            cantidad_objetivo={"total": total, "monedas": monedas},
            solucion={"total": total},
            metricas=self.metricas,
        )
