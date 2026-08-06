"""Sesiones (individual/grupo) y vista en vivo para la facilitadora."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_staff
from app.models import (
    EjercicioCatalogo,
    Intento,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import FichaViva, LiveOut, SesionIn, SesionOut

router = APIRouter(prefix="/sesiones", tags=["sesiones"])

SEGUNDOS_ATASCADO = 30.0


@router.post("", response_model=SesionOut, status_code=status.HTTP_201_CREATED)
async def crear_sesion(
    body: SesionIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    if body.tipo not in ("individual", "grupo"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "tipo inválido")
    modo = body.modo or body.tipo
    if modo not in ("individual", "grupo"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "modo inválido")
    if body.ejercicio_compartido_id is not None:
        ej = await db.get(EjercicioCatalogo, body.ejercicio_compartido_id)
        if ej is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ejercicio compartido no encontrado")
    ses = Sesion(
        centro_id=staff.centro_id,
        tipo=body.tipo,
        modo=modo,
        ejercicio_compartido_id=body.ejercicio_compartido_id,
        staff_id=staff.id,
    )
    db.add(ses)
    await db.flush()
    for uf_id in body.participantes:
        db.add(SesionParticipante(sesion_id=ses.id, usuario_final_id=uf_id))
    await db.commit()
    await db.refresh(ses)
    return ses


@router.get("/{sesion_id}/live", response_model=LiveOut)
async def sesion_live(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Estado en vivo para la vista facilitadora (pensado para polling 3-5s)."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")

    parts = (
        await db.execute(
            select(SesionParticipante).where(SesionParticipante.sesion_id == sesion_id)
        )
    ).scalars().all()

    ahora = datetime.now(timezone.utc)
    fichas: list[FichaViva] = []
    for p in parts:
        uf = await db.get(UsuarioFinal, p.usuario_final_id)
        ultimo = (
            await db.execute(
                select(Intento)
                .where(
                    Intento.sesion_id == sesion_id,
                    Intento.usuario_final_id == p.usuario_final_id,
                )
                .order_by(Intento.timestamp_inicio.desc())
                .limit(1)
            )
        ).scalars().first()

        ejercicio_actual = None
        ultimo_estado = None
        segundos = None
        atascado = False
        if ultimo is not None:
            ej = await db.get(EjercicioCatalogo, ultimo.ejercicio_id)
            ejercicio_actual = ej.nombre if ej else None
            ultimo_estado = ultimo.estado
            ref = ultimo.timestamp_fin or ultimo.timestamp_inicio
            if ref is not None:
                if ref.tzinfo is None:
                    ref = ref.replace(tzinfo=timezone.utc)
                segundos = (ahora - ref).total_seconds()
                atascado = (not ses.cerrada) and segundos >= SEGUNDOS_ATASCADO

        fichas.append(FichaViva(
            usuario_final_id=p.usuario_final_id,
            alias_interno=uf.alias_interno if uf else "?",
            ejercicio_actual=ejercicio_actual,
            ultimo_estado=ultimo_estado,
            segundos_desde_ultimo_intento=segundos,
            atascado=atascado,
        ))

    return LiveOut(sesion_id=sesion_id, tipo=ses.tipo, fichas=fichas)
