"""Evolución individual y de grupo."""
from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import auditar, get_current_staff, usuario_del_centro
from app.models import (
    Alerta,
    EjercicioCatalogo,
    Intento,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import AlertaOut, EvolucionOut, PuntoEvolucion
from app.services.anomalias import rendimiento_resultado

router = APIRouter(tags=["evolucion"])


def _precision(valores: dict) -> float | None:
    if not valores:
        return None
    if valores.get("precision") is not None:
        return float(valores["precision"])
    if valores.get("correcto") is not None:
        return 1.0 if valores["correcto"] else 0.0
    if "aciertos" in valores:
        a = float(valores.get("aciertos", 0)); f = float(valores.get("fallos", 0))
        return a / (a + f) if (a + f) > 0 else None
    return None


@router.get("/usuarios/{usuario_id}/evolucion", response_model=EvolucionOut)
async def evolucion_individual(
    usuario_id: str,
    bloque: str | None = Query(default=None),
    desde: datetime | None = Query(default=None),
    hasta: datetime | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR (datos de salud)
    ev = await _calcular_evolucion(db, usuario_id, bloque, desde, hasta)
    await auditar(db, staff, "ver_evolucion", usuario_final_id=usuario_id,
                  detalle=f"bloque={bloque}")
    await db.commit()
    return ev


async def _calcular_evolucion(
    db: AsyncSession,
    usuario_id: str,
    bloque: str | None,
    desde: datetime | None,
    hasta: datetime | None,
) -> EvolucionOut:
    """Calcula la evolución de una persona (sin auditar ni commitear: lo hace
    quien llama). Reutilizable para individual y para grupo con un solo commit."""
    stmt = (
        select(Intento, EjercicioCatalogo)
        .join(EjercicioCatalogo, Intento.ejercicio_id == EjercicioCatalogo.id)
        .where(Intento.usuario_final_id == usuario_id)
        .order_by(Intento.timestamp_inicio.asc())
    )
    if bloque:
        stmt = stmt.where(EjercicioCatalogo.bloque == bloque)
    if desde:
        stmt = stmt.where(Intento.timestamp_inicio >= desde)
    if hasta:
        stmt = stmt.where(Intento.timestamp_inicio <= hasta)

    filas = (await db.execute(stmt)).all()

    puntos: list[PuntoEvolucion] = []
    rendimientos: list[float] = []
    n_ayuda = 0
    n_sin_valorar = 0
    for intento, ej in filas:
        # Los intentos sin valorar (no-intento o pendientes de revisión) no son
        # evidencia: se cuentan aparte y NO entran en la evolución ni en la media.
        if intento.resultado == "sin_valorar":
            n_sin_valorar += 1
            continue
        puntos.append(PuntoEvolucion(
            fecha=intento.timestamp_inicio,
            ejercicio_id=intento.ejercicio_id,
            bloque=ej.bloque,
            estado=intento.resultado,  # el resultado autocorregido
            precision=_precision(intento.valores_json),
            valores=intento.valores_json or {},
        ))
        rendimientos.append(rendimiento_resultado(intento.resultado))
        # 'con_ayuda' es la capa SECUNDARIA (la marca la integradora), separada
        # del resultado. Se cuenta como matiz, no dispara nada por sí sola.
        if intento.con_ayuda:
            n_ayuda += 1

    resumen = {
        "n_intentos": len(puntos),
        "n_sin_valorar": n_sin_valorar,
        "rendimiento_medio": round(sum(rendimientos) / len(rendimientos), 4) if rendimientos else None,
        "tasa_ayuda": round(n_ayuda / len(puntos), 4) if puntos else None,
    }
    return EvolucionOut(usuario_final_id=usuario_id, bloque=bloque, puntos=puntos, resumen=resumen)


@router.get("/usuarios/{usuario_id}/alertas", response_model=list[AlertaOut])
async def alertas_usuario(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR (datos de salud)
    alertas = (
        await db.execute(
            select(Alerta).where(Alerta.usuario_final_id == usuario_id)
            .order_by(Alerta.fecha_generada.desc())
        )
    ).scalars().all()
    return alertas


@router.get("/grupos/{sesion_id}/evolucion", response_model=list[EvolucionOut])
async def evolucion_grupo(
    sesion_id: str,
    bloque: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Evolución de cada participante del grupo (una entrada por persona)."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    parts = (
        await db.execute(
            select(SesionParticipante).where(SesionParticipante.sesion_id == sesion_id)
        )
    ).scalars().all()

    # Un solo commit para todo el grupo (antes: N consultas + N commits en un GET).
    salida: list[EvolucionOut] = []
    for p in parts:
        salida.append(
            await _calcular_evolucion(db, p.usuario_final_id, bloque, None, None))
    await auditar(db, staff, "ver_evolucion_grupo",
                  detalle=f"sesion={sesion_id} n={len(parts)}")
    await db.commit()
    return salida
