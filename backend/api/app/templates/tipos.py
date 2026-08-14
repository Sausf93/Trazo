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
            # `correcta` viaja aquí para que el backend autocorrija el intento
            # (la tablet reenvía cantidad_objetivo sin usarla ni mostrarla).
            cantidad_objetivo={"n_opciones": len(opciones), "item_id": item.get("id"),
                               "correcta": correcta},
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
        banda = self.banda_cantidad(nivel)
        if banda:
            n = rng.randint(banda[0], banda[1])
        else:
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


class PlantillaBusqueda(PlantillaBase):
    """Buscar entre distractores: "toca todas las llaves" (atención sostenida).

    Se muestra un OBJETIVO (p. ej. la llave) y una rejilla con varias copias del
    objetivo mezcladas con distractores; la persona toca todas las que son el
    objetivo. Auto-evaluable (aciertos/fallos). Basada en fichas reales del centro.
    """

    tipo = "busqueda_visual"
    metricas = ["aciertos", "fallos", "objetivos", "tiempo_ms"]

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)
        objetivo = parametros.get("objetivo")
        distractores = parametros.get("distractores") or []
        if not objetivo or len(distractores) < 3:
            raise ValueError("busqueda_visual requiere 'objetivo' y >=3 'distractores'")

        # Más nivel = más celdas (más difícil de rastrear).
        banda = self.banda_cantidad(nivel)
        total = {3: 6, 6: 9, 10: 12}.get(banda[0], 9) if banda \
            else int(parametros.get("total", 9))
        total = max(6, min(total, 12))
        n_obj = max(2, total // 3)  # ~1/3 son el objetivo

        def _cel(x):
            return {"id": x["id"], "label": x.get("label", x["id"])}

        celdas = [_cel(objetivo) for _ in range(n_obj)]
        for _ in range(total - n_obj):
            celdas.append(_cel(rng.choice(distractores)))
        rng.shuffle(celdas)

        etiqueta = objetivo.get("label", objetivo["id"])
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": parametros.get(
                    "instruccion", "Toca todas las que sean igual"),
                "objetivo": _cel(objetivo),
                "objetivo_label": etiqueta,
                "celdas": celdas,
            },
            cantidad_objetivo={
                "objetivos": n_obj, "total": total, "objetivo_id": objetivo["id"]},
            solucion={"objetivo_id": objetivo["id"]},
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
            # `orden_correcto_pasos` = los pasos en su orden bueno, para que el
            # backend compare contra el `orden_final` que manda la tablet.
            cantidad_objetivo={"n_pasos": n, "tarea_id": tarea.get("id"),
                               "orden_correcto_pasos": list(pasos_ordenados)},
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
        # `modos` (lista) permite variar la tarea cada instancia; `modo` (singular)
        # la fija. Compatibilidad hacia atrás: si no hay `modos`, se usa `modo`.
        modos = parametros.get("modos")
        modo = rng.choice(modos) if modos else parametros.get("modo", "cual_tiene_mas")
        banda = self.banda_cantidad(nivel)
        if banda:
            lo, hi = banda
        else:
            lo = self._nivel_val(nivel, "cantidad_min", parametros.get("cantidad_min", 2))
            hi = self._nivel_val(nivel, "cantidad_max", parametros.get("cantidad_max", 8))

        # Nº de grupos también cambiante (mínimo 2 para poder comparar).
        n_grupos = min(len(objetos), max(2, rng.randint(2, 3)))
        objs = objetos[:n_grupos]
        lo, hi = int(lo), int(hi)
        if hi <= lo:
            hi = lo + 1  # hace falta rango para poder desempatar

        grupos = []
        if modo in ("cual_tiene_mas", "cual_tiene_menos"):
            # CLAVE: el extremo debe ser ÚNICO. Si dos grupos empatan en el máximo
            # (o el mínimo), la pregunta no tiene respuesta y la autocorrección se
            # rompe. Se construye un ganador estrictamente mayor/menor que el resto.
            idx = rng.randrange(n_grupos)
            if modo == "cual_tiene_mas":
                ganador = rng.randint(lo + 1, hi)
                for i, obj in enumerate(objs):
                    c = ganador if i == idx else rng.randint(lo, ganador - 1)
                    grupos.append({"objeto": obj, "cantidad": c})
                solucion = {"objeto_mayor": objs[idx]}
            else:
                ganador = rng.randint(lo, hi - 1)
                for i, obj in enumerate(objs):
                    c = ganador if i == idx else rng.randint(ganador + 1, hi)
                    grupos.append({"objeto": obj, "cantidad": c})
                solucion = {"objeto_menor": objs[idx]}
        elif modo == "contar":
            # UN SOLO tipo de objeto: así es inequívoco QUÉ contar (con varios
            # grupos no se sabía cuál y salía un no_logrado injusto).
            obj = objs[0]
            cant = rng.randint(lo, hi)
            grupos = [{"objeto": obj, "cantidad": cant}]
            solucion = {"objeto": obj, "cantidad": cant}
        else:  # sumar
            for obj in objs:
                grupos.append({"objeto": obj, "cantidad": rng.randint(lo, hi)})
            solucion = {"total": sum(g["cantidad"] for g in grupos)}

        # La instrucción se fija por MODO (la actividad varía de modo en cada
        # tirada): así siempre dice sin ambigüedad qué hay que hacer.
        instruccion = {
            "cual_tiene_mas": "Toca el grupo que tiene MÁS",
            "cual_tiene_menos": "Toca el grupo que tiene MENOS",
            "sumar": "¿Cuántos hay en total? Escribe el número",
            "contar": "Cuenta cuántos hay y escribe el número",
        }.get(modo, parametros.get("instruccion", "¿Cuál tiene más?"))

        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": instruccion,
                "modo": modo,
                "grupos": grupos,
            },
            cantidad_objetivo={"modo": modo, "cantidades": [g["cantidad"] for g in grupos],
                               "solucion": solucion},
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
            cantidad_objetivo={"cantidad": n, "n_piezas": len(seleccion),
                               "emparejamientos": {p["id"]: p.get("zona_correcta")
                                                   for p in seleccion if "id" in p}},
            solucion={"emparejamientos": {p["id"]: p.get("zona_correcta") for p in seleccion if "id" in p}},
            metricas=self.metricas,
        )


# --- Denominaciones del euro (trabajo interno SIEMPRE en céntimos enteros) ---
# Monedas: 1c, 2c, 5c, 10c, 20c, 50c, 1€, 2€.  Billetes: 5, 10, 20, 50, 100, 200, 500 €.
MONEDAS_C = [1, 2, 5, 10, 20, 50, 100, 200]
BILLETES_C = [500, 1000, 2000, 5000, 10000, 20000, 50000]
TODAS_C = MONEDAS_C + BILLETES_C


def _fmt_eur(centimos: int) -> str:
    """Formatea céntimos enteros como importe en euros: 245 -> '2,45 €'."""
    centimos = int(centimos)
    signo = "-" if centimos < 0 else ""
    centimos = abs(centimos)
    return f"{signo}{centimos // 100},{centimos % 100:02d} €"


def _etiqueta_denom(c: int) -> str:
    """Etiqueta corta de una denominación: 5 -> '5c', 100 -> '1€', 250 -> '2,50€'."""
    if c < 100:
        return f"{c}c"
    if c % 100 == 0:
        return f"{c // 100}€"
    return f"{c // 100},{c % 100:02d}€"


def _desglose_greedy(importe_c: int, denoms: list[int]) -> dict:
    """Combinación de denominaciones (voraz, de mayor a menor) que suma `importe_c`.

    Con la denominación más pequeña disponible dividiendo al importe (garantizado
    por `paso_c`), el sistema del euro es canónico y la voracidad da resultado
    exacto. Devuelve {valor_c: cantidad} solo con las que se usan.
    """
    restante = int(importe_c)
    piezas: dict[int, int] = {}
    for d in sorted(denoms, reverse=True):
        if d <= 0 or restante < d:
            continue
        n, restante = divmod(restante, d)
        if n:
            piezas[d] = n
    # `restante` deber­ía ser 0; si no (config exótica) se ignora el sobrante.
    return {str(k): v for k, v in piezas.items()}


class PlantillaManejoCantidad(PlantillaBase):
    """Dinero (reúne el importe / monedas justas), la vuelta, ¿llega para pagar?, reloj.

    Trabaja internamente en CÉNTIMOS enteros para evitar errores de coma flotante;
    expone importes ya formateados ('2,45 €'). Soporta billetes y monedas de todo
    el euro, rangos amplios configurables por nivel/parámetros, y varias BANDAS de
    dificultad (`bandas`) y MODOS (`modos`) entre los que se elige al azar en cada
    tirada, de modo que cada instancia sale distinta.
    """

    tipo = "manejo_cantidad"
    metricas = ["correcto", "tiempo_ms", "num_ajustes"]

    # Modos que trabajan con importes de dinero (reloj se trata aparte).
    _MODOS_DINERO = {"dinero", "monedas_justas", "vuelta", "llega_para_pagar"}

    # -- helpers de configuración --

    def _resolver_denoms(self, cfg: dict) -> list[int]:
        """Denominaciones disponibles (en céntimos), de la config o por defecto."""
        if cfg.get("denominaciones_c"):
            denoms = [int(d) for d in cfg["denominaciones_c"]]
        else:
            denoms = []
            # `monedas`/`billetes` vienen expresadas en EUROS (compatibilidad).
            for m in cfg.get("monedas", []) or []:
                denoms.append(int(round(float(m) * 100)))
            for b in cfg.get("billetes", []) or []:
                denoms.append(int(round(float(b) * 100)))
            if not denoms:
                denoms = list(MONEDAS_C)  # por defecto, monedas de euro completas
        return sorted({d for d in denoms if d > 0})

    def _rango_importe_c(self, cfg: dict, nivel) -> tuple[int, int]:
        """Rango del importe en céntimos, aceptando claves en céntimos o en euros."""
        lo = self._nivel_val(nivel, "importe_min_c", cfg.get("importe_min_c"))
        hi = self._nivel_val(nivel, "importe_max_c", cfg.get("importe_max_c"))
        if lo is None:
            lo = int(round(float(self._nivel_val(nivel, "total_min", cfg.get("total_min", 1))) * 100))
        if hi is None:
            hi = int(round(float(self._nivel_val(nivel, "total_max", cfg.get("total_max", 20))) * 100))
        lo, hi = int(lo), int(hi)
        if hi < lo:
            hi = lo
        return lo, hi

    def _genera_importe_c(self, cfg: dict, nivel, denoms: list[int], rng) -> tuple[int, int]:
        """Elige un importe (céntimos) makeable con `denoms`. Devuelve (importe, paso)."""
        lo, hi = self._rango_importe_c(cfg, nivel)
        con_centimos = cfg.get("con_centimos")
        if con_centimos is None:
            con_centimos = any(d < 100 for d in denoms)
        min_denom = min(denoms)
        paso = cfg.get("paso_c")
        if paso is None:
            paso = min_denom if con_centimos else 100
        paso = int(paso)
        # El paso debe ser múltiplo de la denominación más pequeña para que el
        # importe sea siempre exacto con las denominaciones disponibles.
        if paso % min_denom != 0:
            paso = max(min_denom, (paso // min_denom) * min_denom or min_denom)
        # Alinear el rango al paso.
        lo_al = ((lo + paso - 1) // paso) * paso
        hi_al = (hi // paso) * paso
        if hi_al < lo_al:
            hi_al = lo_al
        n = (hi_al - lo_al) // paso
        importe = lo_al + rng.randint(0, n) * paso
        if importe <= 0:
            importe = paso
        return importe, paso

    # -- generación --

    def generar(self, parametros, nivel=None, rng=None):
        rng = self._rng(rng)

        # Una actividad puede ofrecer varias BANDAS (rangos/denominaciones/modos):
        # se elige una al azar y sus claves pisan a las de la config base.
        cfg = dict(parametros)
        bandas = parametros.get("bandas")
        banda_id = None
        if bandas:
            banda = rng.choice(bandas)
            banda_id = banda.get("id")
            cfg.update({k: v for k, v in banda.items() if k != "id"})

        modos = cfg.get("modos")
        modo = rng.choice(modos) if modos else cfg.get("modo", "dinero")

        if modo == "reloj":
            return self._gen_reloj(cfg, rng)

        denoms = self._resolver_denoms(cfg)
        denoms_render = [{"valor_c": d, "etiqueta": _etiqueta_denom(d)} for d in denoms]

        if modo == "vuelta":
            return self._gen_vuelta(cfg, nivel, denoms, denoms_render, banda_id, rng)
        if modo == "llega_para_pagar":
            return self._gen_llega(cfg, nivel, denoms, denoms_render, banda_id, rng)
        # "dinero" (reúne el importe) y "monedas_justas" comparten estructura.
        return self._gen_dinero(cfg, nivel, denoms, denoms_render, modo, banda_id, rng)

    def _gen_reloj(self, cfg, rng):
        hora = rng.randint(1, 12)
        minuto = rng.choice(cfg.get("minutos", [0, 15, 30, 45]))
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={"instruccion": "¿Qué hora marca?", "modo": "reloj", "hora": hora, "minuto": minuto},
            cantidad_objetivo={"modo": "reloj", "hora": hora, "minuto": minuto},
            solucion={"hora": hora, "minuto": minuto},
            metricas=self.metricas,
        )

    def _gen_dinero(self, cfg, nivel, denoms, denoms_render, modo, banda_id, rng):
        importe_c, _ = self._genera_importe_c(cfg, nivel, denoms, rng)
        desglose = _desglose_greedy(importe_c, denoms)
        if modo == "monedas_justas":
            instruccion = f"Elige las monedas justas para pagar {_fmt_eur(importe_c)}"
        else:
            instruccion = f"Reúne {_fmt_eur(importe_c)} con las monedas y billetes"
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": instruccion,
                "modo": modo,
                "importe_c": importe_c,
                "importe_texto": _fmt_eur(importe_c),
                "denominaciones": denoms_render,
            },
            cantidad_objetivo={
                "modo": modo, "banda": banda_id,
                "importe_c": importe_c, "denominaciones_c": denoms,
            },
            solucion={"importe_c": importe_c, "desglose_c": desglose,
                      "n_piezas": sum(int(v) for v in desglose.values())},
            metricas=self.metricas,
        )

    def _gen_vuelta(self, cfg, nivel, denoms, denoms_render, banda_id, rng):
        precio_c, _ = self._genera_importe_c(cfg, nivel, denoms, rng)
        # Con qué se paga: `paga_con_c` explícito, o los billetes disponibles, o
        # el juego estándar de billetes. Se elige el menor que cubra el precio.
        pagos = cfg.get("paga_con_c") or [d for d in denoms if d >= 500] or BILLETES_C
        pagos = sorted(int(p) for p in pagos)
        cubren = [p for p in pagos if p >= precio_c]
        pago_c = cubren[0] if cubren else pagos[-1]
        # Si aún así no cubre (precio enorme), subimos al billete estándar mayor.
        if pago_c < precio_c:
            pago_c = next((b for b in BILLETES_C if b >= precio_c), precio_c)
        vuelta_c = pago_c - precio_c
        desglose = _desglose_greedy(vuelta_c, denoms)
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": f"Pagas {_fmt_eur(precio_c)} con {_fmt_eur(pago_c)}. "
                               f"¿Cuánto te devuelven?",
                "modo": "vuelta",
                "precio_c": precio_c, "precio_texto": _fmt_eur(precio_c),
                "pago_c": pago_c, "pago_texto": _fmt_eur(pago_c),
                "denominaciones": denoms_render,
            },
            cantidad_objetivo={
                "modo": "vuelta", "banda": banda_id,
                "precio_c": precio_c, "pago_c": pago_c,
            },
            solucion={"vuelta_c": vuelta_c, "vuelta_texto": _fmt_eur(vuelta_c),
                      "desglose_c": desglose},
            metricas=self.metricas,
        )

    def _gen_llega(self, cfg, nivel, denoms, denoms_render, banda_id, rng):
        precio_c, paso = self._genera_importe_c(cfg, nivel, denoms, rng)
        # Cuánto lleva la persona en el monedero: entre la mitad y ~1,6x el precio,
        # de modo que unas veces llega y otras no.
        lo = max(paso, (precio_c // 2 // paso) * paso)
        hi = max(lo, (int(precio_c * 1.6) // paso) * paso)
        n = (hi - lo) // paso
        disponible_c = lo + rng.randint(0, n) * paso
        monedero = _desglose_greedy(disponible_c, denoms)
        llega = disponible_c >= precio_c
        return InstanciaEjercicio(
            plantilla=self.tipo,
            render={
                "instruccion": f"Cuesta {_fmt_eur(precio_c)}. Con lo que llevas, "
                               f"¿te llega para pagar?",
                "modo": "llega_para_pagar",
                "precio_c": precio_c, "precio_texto": _fmt_eur(precio_c),
                "disponible_c": disponible_c, "disponible_texto": _fmt_eur(disponible_c),
                "monedero": [
                    {"valor_c": int(k), "etiqueta": _etiqueta_denom(int(k)), "cantidad": v}
                    for k, v in sorted(((int(k), v) for k, v in monedero.items()), reverse=True)
                ],
                "denominaciones": denoms_render,
            },
            cantidad_objetivo={
                "modo": "llega_para_pagar", "banda": banda_id,
                "precio_c": precio_c, "disponible_c": disponible_c,
            },
            solucion={"llega": llega, "precio_c": precio_c, "disponible_c": disponible_c},
            metricas=self.metricas,
        )
