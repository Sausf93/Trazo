"""Dispositivos (tablets) emparejados al centro.

Ver MODELO-OPERATIVO §1: las tablets se emparejan una vez y son "del centro";
se pueden revocar desde la web si se pierde una (RGPD).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import Acceso, acceso_centro, get_current_staff
from app.models import ROLES_DISPOSITIVO, Dispositivo, UsuarioStaff
from app.schemas import DispositivoIn, DispositivoOut, DispositivoYoOut

router = APIRouter(prefix="/dispositivos", tags=["dispositivos"])


@router.get("/yo", response_model=DispositivoYoOut)
async def dispositivo_actual(acceso: Acceso = Depends(acceso_centro)):
    """La tablet emparejada valida su token y obtiene su contexto (centro, rol).

    Sirve para la pantalla de emparejamiento del kiosco: si el token es válido,
    devuelve a qué centro pertenece; si no, el propio acceso da 401."""
    disp = acceso.dispositivo
    if disp is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Falta el token de dispositivo (X-Device-Token)"
        )
    return DispositivoYoOut(
        id=disp.id, centro_id=disp.centro_id, nombre=disp.nombre, rol=disp.rol
    )


@router.post("", response_model=DispositivoOut, status_code=status.HTTP_201_CREATED)
async def emparejar_dispositivo(
    body: DispositivoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    if body.rol not in ROLES_DISPOSITIVO:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"rol inválido: {body.rol}")
    centro_id = body.centro_id or staff.centro_id
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    disp = Dispositivo(centro_id=centro_id, nombre=body.nombre, rol=body.rol)
    db.add(disp)
    await db.commit()
    await db.refresh(disp)
    return disp


@router.get("", response_model=list[DispositivoOut])
async def listar_dispositivos(
    centro_id: str | None = Query(default=None),
    activo: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    centro = centro_id or staff.centro_id
    if centro != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    stmt = select(Dispositivo).where(Dispositivo.centro_id == centro)
    if activo is not None:
        stmt = stmt.where(Dispositivo.activo.is_(activo))
    return (await db.execute(stmt.order_by(Dispositivo.emparejado_en))).scalars().all()


@router.patch("/{dispositivo_id}/revocar", response_model=DispositivoOut)
async def revocar_dispositivo(
    dispositivo_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Desvincula una tablet (activo=False). Reversible con un nuevo emparejamiento."""
    disp = await db.get(Dispositivo, dispositivo_id)
    if disp is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Dispositivo no encontrado")
    if disp.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    disp.activo = False
    await db.commit()
    await db.refresh(disp)
    return disp
