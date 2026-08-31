"""Orquestación de alertas: lee intentos de BD y aplica el motor de anomalías.

Mejoras de calidad de la detección temprana (ver auditoría):
  1. Agregación POR SESIÓN antes de comparar (menos ruido intra-sesión: dos
     actividades flojas la misma tarde ya no simulan "empeoramiento sostenido").
  2. Segmentación por DIFICULTAD (nivel/cantidad): el baseline se reinicia al
     cambiar de nivel, así subir la dificultad a alguien que va bien no dispara
     una falsa alarma. Solo se compara dentro del tramo de dificultad vigente.
  3. Segunda señal: LATENCIA. "Tarda cada vez más en lo mismo" precede al fallo;
     una tendencia creciente del tiempo (normalizado por ejercicio) también
     genera alerta.

El TEXTO de la alerta se alinea con la unidad realmente comparada (sesiones o,
si aún no hay suficientes sesiones, actividades del tramo de dificultad actual).
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Alerta, EjercicioCatalogo, Intento
from app.services.anomalias import (
    IntentoObs,
    agregar_por_sesion,
    detectar_desviacion,
    detectar_missingness,
    detectar_tendencia_tiempo,
    firma_dificultad,
    rendimiento_resultado,
    segmento_dificultad_actual,
)
from app.services.correccion import hubo_interaccion

# Nº máximo de intentos recientes que se reevalúan por bloque (ventana acotada:
# la evaluación corre en cada intento y no debe reescanear años de histórico).
_MAX_HISTORIAL = 80


def _tiempo_ms(intento: Intento) -> float | None:
    """Tiempo de la actividad en ms: de `valores_json.tiempo_ms` o de los sellos."""
    valores = intento.valores_json or {}
    t = valores.get("tiempo_ms")
    if t is not None:
        try:
            t = float(t)
            return t if t > 0 else None
        except (TypeError, ValueError):
            return None
    if intento.timestamp_inicio and intento.timestamp_fin:
        delta = (intento.timestamp_fin - intento.timestamp_inicio).total_seconds()
        return delta * 1000.0 if delta > 0 else None
    return None


def _observaciones(intentos: list[Intento]) -> list[IntentoObs]:
    obs: list[IntentoObs] = []
    for i in intentos:
        # Los intentos SIN VALORAR (no-intento o pendientes de revisión) no son
        # evidencia de rendimiento: se excluyen del cálculo (ni suman ni restan).
        # Su ausencia NO se ignora: se vigila aparte (ver detectar_missingness).
        if i.resultado == "sin_valorar":
            continue
        obs.append(
            IntentoObs(
                sesion_id=i.sesion_id,
                ejercicio_id=i.ejercicio_id,
                rendimiento=rendimiento_resultado(i.resultado),
                dificultad=firma_dificultad(i.cantidad_objetivo_json),
                tiempo_ms=_tiempo_ms(i),
            )
        )
    return obs


async def evaluar_usuario_bloque(
    db: AsyncSession,
    usuario_final_id: str,
    bloque: str,
) -> Alerta | None:
    """Evalúa el histórico de una persona en un bloque y crea alerta si procede.

    Devuelve la Alerta creada (aún sin commit) o None. El commit lo hace quien
    llama, para poder agrupar varias evaluaciones en una transacción.
    """
    # Los RETOS son un extra de grupo, no medibles a nivel individual: nunca
    # generan alertas sobre una persona.
    if bloque == "retos":
        return None
    # Ventana histórica ACOTADA: esta evaluación corre en CADA registro de intento
    # (path caliente del kiosco), así que no reprocesamos todo el pasado. Los
    # últimos _MAX_HISTORIAL intentos bastan de sobra para baseline+reciente.
    stmt = (
        select(Intento)
        .join(EjercicioCatalogo, Intento.ejercicio_id == EjercicioCatalogo.id)
        .where(
            Intento.usuario_final_id == usuario_final_id,
            EjercicioCatalogo.bloque == bloque,
        )
        .order_by(Intento.timestamp_inicio.desc())
        .limit(_MAX_HISTORIAL)
    )
    intentos = list(reversed((await db.execute(stmt)).scalars().all()))
    if not intentos:
        return None

    # Vigilancia de "dejar de participar" (missingness): fracción de actividades
    # SIN INTERACCIÓN por sesión. Necesita la plantilla de cada ejercicio.
    ej_ids = {i.ejercicio_id for i in intentos}
    plantillas = dict((await db.execute(
        select(EjercicioCatalogo.id, EjercicioCatalogo.plantilla_tipo)
        .where(EjercicioCatalogo.id.in_(ej_ids))
    )).all()) if ej_ids else {}
    res_missing = _evaluar_missingness(list(intentos), plantillas)
    hay_missing = res_missing is not None and res_missing.hay_desconexion

    obs = _observaciones(list(intentos))

    # (1) Agregar por sesión y (2) quedarnos con el tramo de dificultad vigente.
    sesiones = agregar_por_sesion(obs)
    seg_sesiones = segmento_dificultad_actual(sesiones)

    # Serie de rendimiento y de tiempo a nivel de SESIÓN.
    serie_rend = [s.rendimiento for s in seg_sesiones]
    serie_tiempo = [s.tiempo_rel for s in seg_sesiones if s.tiempo_rel is not None]
    unidad = "sesiones"

    res_rend = detectar_desviacion(serie_rend)

    # Fallback: aún no hay suficientes SESIONES para juzgar (p. ej. muchas
    # actividades concentradas en una sola sesión). Caemos a nivel de actividad,
    # pero SIEMPRE dentro del tramo de dificultad vigente (sigue evitando el
    # ruido por cambio de nivel). Así una bajada clara y sostenida no se pierde.
    if res_rend is None:
        seg_intentos = segmento_dificultad_actual(obs)
        serie_rend = [x.rendimiento for x in seg_intentos]
        # Tiempo relativo por intento respecto a la mediana de su ejercicio.
        serie_tiempo = _tiempos_relativos_intento(seg_intentos)
        unidad = "actividades"
        res_rend = detectar_desviacion(serie_rend)

    res_tiempo = detectar_tendencia_tiempo(serie_tiempo)

    hay_rend = (
        res_rend is not None
        and res_rend.hay_desviacion
        and _declive_sostenido(serie_rend, res_rend)
    )
    hay_tiempo = res_tiempo is not None and res_tiempo.hay_tendencia
    if not hay_rend and not hay_tiempo and not hay_missing:
        return None

    # Evitar duplicar: ¿ya hay una alerta abierta de este bloque?
    abierta = (
        await db.execute(
            select(Alerta).where(
                Alerta.usuario_final_id == usuario_final_id,
                Alerta.bloque_afectado == bloque,
                Alerta.fecha_revision.is_(None),
            )
        )
    ).scalars().first()
    if abierta is not None:
        return None

    descripcion, contexto = _redactar(bloque, unidad, res_rend, res_tiempo,
                                      hay_rend, hay_tiempo, res_missing, hay_missing)

    alerta = Alerta(
        usuario_final_id=usuario_final_id,
        tipo="individual",
        bloque_afectado=bloque,
        descripcion=descripcion,
        contexto_json=contexto,
    )
    db.add(alerta)
    return alerta


def _evaluar_missingness(intentos: list[Intento], plantillas: dict[str, str]):
    """Serie de fracción SIN INTERACCIÓN por sesión y su detección de tendencia."""
    por_sesion: dict[str, list[bool]] = {}
    orden: list[str] = []
    for i in intentos:
        if i.sesion_id not in por_sesion:
            por_sesion[i.sesion_id] = []
            orden.append(i.sesion_id)
        plantilla = plantillas.get(i.ejercicio_id, "")
        por_sesion[i.sesion_id].append(hubo_interaccion(plantilla, i.valores_json))
    serie_tasa = [
        sum(1 for tocado in por_sesion[s] if not tocado) / len(por_sesion[s])
        for s in orden if por_sesion[s]
    ]
    return detectar_missingness(serie_tasa)


def _declive_sostenido(serie: list[float], res) -> bool:
    """Confirma que el declive es SOSTENIDO, no un único punto reciente flojo.

    Exige que TODOS los puntos de la ventana reciente estén por debajo de la
    media del baseline. Así una sola sesión/tarde mala (que la media de la
    ventana podría arrastrar) no basta para alertar: hace falta que la caída se
    mantenga en toda la ventana reciente.
    """
    reciente = serie[-res.n_reciente:]
    return bool(reciente) and all(v < res.baseline_media for v in reciente)


def _tiempos_relativos_intento(intentos: list[IntentoObs]) -> list[float]:
    """Tiempo por intento normalizado por la mediana de su ejercicio."""
    import statistics

    por_ejercicio: dict[str, list[float]] = {}
    for it in intentos:
        if it.tiempo_ms and it.tiempo_ms > 0:
            por_ejercicio.setdefault(it.ejercicio_id, []).append(float(it.tiempo_ms))
    medianas = {ej: statistics.median(v) for ej, v in por_ejercicio.items() if v}

    serie: list[float] = []
    for it in intentos:
        m = medianas.get(it.ejercicio_id)
        if it.tiempo_ms and m and m > 0:
            serie.append(float(it.tiempo_ms) / m)
    return serie


def _redactar(bloque, unidad, res_rend, res_tiempo, hay_rend, hay_tiempo,
              res_missing=None, hay_missing=False):
    """Construye descripción + contexto alineados con la(s) señal(es)."""
    contexto: dict = {"unidad": unidad}
    senales = []
    if hay_rend:
        senales.append("rendimiento")
    if hay_tiempo:
        senales.append("latencia")
    if hay_missing:
        senales.append("desconexion")
    contexto["senal"] = "_y_".join(senales) if senales else "ninguna"

    frases: list[str] = []
    if hay_missing and res_missing is not None:
        contexto.update({
            "desconexion_baseline_tasa": res_missing.baseline_tasa,
            "desconexion_reciente_tasa": res_missing.reciente_tasa,
            "desconexion_n_baseline": res_missing.n_baseline,
            "desconexion_n_reciente": res_missing.n_reciente,
        })
        pct = round(res_missing.reciente_tasa * 100)
        frases.append(
            f"participa cada vez menos: en las últimas {res_missing.n_reciente} "
            f"sesiones dejó sin intentar el {pct}% de las actividades (antes, un "
            f"{round(res_missing.baseline_tasa * 100)}%)"
        )
    if hay_rend:
        contexto.update({
            "baseline_media": res_rend.baseline_media,
            "baseline_std": res_rend.baseline_std,
            "reciente_media": res_rend.reciente_media,
            "umbral_inferior": res_rend.umbral_inferior,
            "n_baseline": res_rend.n_baseline,
            "n_reciente": res_rend.n_reciente,
            "caida": res_rend.caida,
        })
        frases.append(
            f"las últimas {res_rend.n_reciente} {unidad} (media "
            f"{res_rend.reciente_media}) se salen del patrón habitual de esta "
            f"persona (media {res_rend.baseline_media}, umbral "
            f"{res_rend.umbral_inferior})"
        )
    if hay_tiempo:
        contexto.update({
            "tiempo_baseline_media": res_tiempo.baseline_media,
            "tiempo_reciente_media": res_tiempo.reciente_media,
            "tiempo_subida_relativa": res_tiempo.subida_relativa,
            "tiempo_n_baseline": res_tiempo.n_baseline,
            "tiempo_n_reciente": res_tiempo.n_reciente,
        })
        pct = round(res_tiempo.subida_relativa * 100)
        frases.append(
            f"tarda de media un {pct}% más que su tiempo habitual en las últimas "
            f"{res_tiempo.n_reciente} {unidad}"
        )

    # Encuadre responsable: esto NO es un diagnóstico ni mide "deterioro". Es un
    # cambio en el DESEMPEÑO de la actividad, que puede deberse a muchas causas
    # ajenas a lo cognitivo. El profesional decide tras descartarlas.
    contexto["no_diagnostico"] = True
    contexto["causas_a_descartar"] = [
        "vista o audición", "dolor o malestar físico", "cambio de medicación",
        "estado de ánimo o un día malo", "infección (p. ej. de orina)",
        "sueño o cansancio",
    ]
    descripcion = (
        f"Cambio sostenido en el desempeño de '{bloque}': " + "; y ".join(frases)
        + ". No es un diagnóstico ni indica deterioro por sí solo: conviene "
        "revisarlo descartando antes causas frecuentes (vista/oído, dolor, "
        "medicación, ánimo, un día malo, una infección)."
    )
    return descripcion, contexto
