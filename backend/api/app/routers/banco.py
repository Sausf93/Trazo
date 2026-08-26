"""Veredictos del BANCO DE PRUEBAS (revisión interna de actividades por Saulo y
Laura). SIN datos de personas: solo nombre de actividad + veredicto + nota +
quién la marcó. No usa login de centro (el banco corre sin emparejar); se protege
con un token compartido en la cabecera `X-Lab-Token`. Sirve para que varias
personas marquen y el equipo lo consolide en un solo sitio.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import get_db
from app.models import BancoVeredicto
from app.schemas import BancoVeredictoIn, BancoVeredictoOut

router = APIRouter(prefix="/banco", tags=["banco"])

# Token compartido (secreto de baja seguridad: no hay datos de personas). Debe
# coincidir con el que envía el banco de la tablet.
_BANCO_TOKEN = "trazo-lab-2026"


def _exigir_token(x_lab_token: str | None = Header(default=None)) -> None:
    if x_lab_token != _BANCO_TOKEN:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token del banco no válido")


@router.post("/veredictos", response_model=BancoVeredictoOut, status_code=status.HTTP_201_CREATED)
async def guardar_veredicto(
    body: BancoVeredictoIn,
    db: AsyncSession = Depends(get_db),
    _t: None = Depends(_exigir_token),
):
    """Guarda (o actualiza) el veredicto de una persona sobre una actividad."""
    if body.estado not in ("revisar", "otro_grupo", "valida", "descartar"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "estado no válido")
    existente = (
        await db.execute(
            select(BancoVeredicto).where(
                BancoVeredicto.actividad == body.actividad,
                BancoVeredicto.marcado_por == (body.marcado_por or ""),
            )
        )
    ).scalars().first()
    if existente is not None:
        existente.estado = body.estado
        existente.nota = body.nota or ""
        obj = existente
    else:
        obj = BancoVeredicto(
            actividad=body.actividad[:200],
            estado=body.estado,
            nota=body.nota or "",
            marcado_por=(body.marcado_por or "")[:80],
        )
        db.add(obj)
    await db.commit()
    await db.refresh(obj)
    return obj


@router.get("/veredictos", response_model=list[BancoVeredictoOut])
async def listar_veredictos(
    db: AsyncSession = Depends(get_db),
    _t: None = Depends(_exigir_token),
):
    """Todos los veredictos marcados (de todas las personas), para consolidar."""
    q = select(BancoVeredicto).order_by(
        BancoVeredicto.actividad, BancoVeredicto.marcado_por
    )
    return (await db.execute(q)).scalars().all()


@router.delete("/veredictos/{veredicto_id}", status_code=status.HTTP_204_NO_CONTENT)
async def borrar_veredicto(
    veredicto_id: str,
    db: AsyncSession = Depends(get_db),
    _t: None = Depends(_exigir_token),
):
    obj = await db.get(BancoVeredicto, veredicto_id)
    if obj is not None:
        await db.delete(obj)
        await db.commit()


@router.delete("/veredictos", status_code=status.HTTP_204_NO_CONTENT)
async def vaciar_veredictos(
    db: AsyncSession = Depends(get_db),
    _t: None = Depends(_exigir_token),
):
    """Vacía todos los veredictos (tras consolidar una ronda de revisión)."""
    await db.execute(delete(BancoVeredicto))
    await db.commit()
