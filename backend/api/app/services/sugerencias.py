"""Auto-sugerencia de nivel para las líneas del plan (el profesional aprueba).

Principio (MODELO-OPERATIVO §2): el sistema PROPONE subir o bajar el nivel según
la evolución propia de la persona, pero NUNCA lo cambia solo — lo confirma el
profesional. Reutiliza el motor de anomalías (comparación contra el histórico de
la misma persona, nunca entre usuarios).
"""
from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import EjercicioCatalogo, Intento, PlanPacienteLinea
from app.services.anomalias import detectar_desviacion, rendimiento_intento

NIVELES = ["bajo", "medio", "alto"]

# Umbrales (conservadores: mejor no sugerir que sugerir a la ligera).
MIN_INTENTOS = 4
VENTANA = 5
UMBRAL_SUBIR = 0.85
UMBRAL_BAJAR = 0.45


@dataclass
class SugerenciaNivel:
    plan_linea_id: str
    bloque: str
    nivel_actual: str | None
    sugerencia: str  # "subir" | "bajar"
    nivel_propuesto: str
    motivo: str
    media_reciente: float
    n_intentos: int


def _siguiente(nivel: str | None, arriba: bool) -> str | None:
    """Nivel adyacente. Si el nivel actual no es uno de NIVELES, no proponemos."""
    if nivel not in NIVELES:
        return None
    i = NIVELES.index(nivel)
    j = i + 1 if arriba else i - 1
    if 0 <= j < len(NIVELES):
        return NIVELES[j]
    return None


async def sugerencias_para_usuario(
    db: AsyncSession, usuario_final_id: str
) -> list[SugerenciaNivel]:
    """Recorre las líneas activas del plan y propone ajustes de nivel."""
    lineas = (
        await db.execute(
            select(PlanPacienteLinea).where(
                PlanPacienteLinea.usuario_final_id == usuario_final_id,
                PlanPacienteLinea.activo.is_(True),
            )
        )
    ).scalars().all()

    salida: list[SugerenciaNivel] = []
    # Cache de rendimiento por bloque (varias líneas pueden compartir bloque).
    cache: dict[str, list[float]] = {}

    for ln in lineas:
        bloque = ln.bloque
        if bloque is None and ln.ejercicio_id:
            ej = await db.get(EjercicioCatalogo, ln.ejercicio_id)
            bloque = ej.bloque if ej else None
        if not bloque:
            continue

        if bloque not in cache:
            cache[bloque] = await _serie_rendimiento(db, usuario_final_id, bloque)
        serie = cache[bloque]

        if len(serie) < MIN_INTENTOS:
            continue  # datos insuficientes: no sugerimos

        reciente = serie[-VENTANA:]
        media = round(sum(reciente) / len(reciente), 4)

        # ¿Empeoramiento sostenido? -> bajar.
        desv = detectar_desviacion(serie)
        if desv is not None and desv.hay_desviacion:
            prop = _siguiente(ln.nivel, arriba=False)
            if prop:
                salida.append(SugerenciaNivel(
                    plan_linea_id=ln.id, bloque=bloque, nivel_actual=ln.nivel,
                    sugerencia="bajar", nivel_propuesto=prop,
                    motivo="Empeoramiento sostenido respecto a su patrón habitual.",
                    media_reciente=media, n_intentos=len(serie),
                ))
            continue

        # ¿Rendimiento alto y estable? -> subir.
        if media >= UMBRAL_SUBIR:
            prop = _siguiente(ln.nivel, arriba=True)
            if prop:
                salida.append(SugerenciaNivel(
                    plan_linea_id=ln.id, bloque=bloque, nivel_actual=ln.nivel,
                    sugerencia="subir", nivel_propuesto=prop,
                    motivo="Rendimiento alto y estable: puede asumir más dificultad.",
                    media_reciente=media, n_intentos=len(serie),
                ))
            continue

        # ¿Rendimiento bajo mantenido? -> bajar.
        if media <= UMBRAL_BAJAR:
            prop = _siguiente(ln.nivel, arriba=False)
            if prop:
                salida.append(SugerenciaNivel(
                    plan_linea_id=ln.id, bloque=bloque, nivel_actual=ln.nivel,
                    sugerencia="bajar", nivel_propuesto=prop,
                    motivo="Rendimiento bajo mantenido: la dificultad puede ser excesiva.",
                    media_reciente=media, n_intentos=len(serie),
                ))

    return salida


async def _serie_rendimiento(
    db: AsyncSession, usuario_final_id: str, bloque: str
) -> list[float]:
    stmt = (
        select(Intento)
        .join(EjercicioCatalogo, Intento.ejercicio_id == EjercicioCatalogo.id)
        .where(
            Intento.usuario_final_id == usuario_final_id,
            EjercicioCatalogo.bloque == bloque,
        )
        .order_by(Intento.timestamp_inicio.asc())
    )
    intentos = (await db.execute(stmt)).scalars().all()
    return [rendimiento_intento(i.estado, i.valores_json) for i in intentos]
