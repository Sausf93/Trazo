"""Bandeja de alertas del centro y revisión profesional."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_staff
from app.models import Alerta, UsuarioFinal, UsuarioStaff
from app.schemas import AlertaOut, RevisarAlertaIn

router = APIRouter(prefix="/alertas", tags=["alertas"])


@router.get("", response_model=list[AlertaOut])
async def listar_alertas(
    centro_id: str | None = Query(default=None),
    revisada: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    # Restringe al centro del staff (salvo que pida el suyo explícitamente).
    centro = centro_id or staff.centro_id
    if centro != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")

    stmt = (
        select(Alerta)
        .join(UsuarioFinal, Alerta.usuario_final_id == UsuarioFinal.id)
        .where(UsuarioFinal.centro_id == centro)
        .order_by(Alerta.fecha_generada.desc())
    )
    if revisada is True:
        stmt = stmt.where(Alerta.fecha_revision.is_not(None))
    elif revisada is False:
        stmt = stmt.where(Alerta.fecha_revision.is_(None))

    return (await db.execute(stmt)).scalars().all()


@router.patch("/{alerta_id}/revisar", response_model=AlertaOut)
async def revisar_alerta(
    alerta_id: str,
    body: RevisarAlertaIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    alerta = await db.get(Alerta, alerta_id)
    if alerta is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Alerta no encontrada")
    alerta.revisada_por = staff.id
    alerta.fecha_revision = datetime.now(timezone.utc)
    alerta.resultado = body.resultado
    await db.commit()
    await db.refresh(alerta)
    return alerta
