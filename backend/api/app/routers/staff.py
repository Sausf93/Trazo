"""Equipo del centro (nivel 1): el admin del centro da de alta y gestiona a sus
integradoras (maestras). Todo queda acotado al centro del admin (multi-tenant):
nunca puede tocar staff de otro centro.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import require_roles
from app.models import UsuarioStaff
from app.schemas import StaffIn, StaffOut, StaffPassword, StaffPin, StaffUpdate
from app.security import hash_password

router = APIRouter(prefix="/staff", tags=["equipo"])


@router.get("", response_model=list[StaffOut])
async def listar_staff(
    db: AsyncSession = Depends(get_db),
    admin: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """Lista el equipo del centro del admin (integradoras y admins)."""
    filas = (await db.execute(
        select(UsuarioStaff)
        .where(UsuarioStaff.centro_id == admin.centro_id)
        .order_by(UsuarioStaff.creado_en.asc())
    )).scalars().all()
    return filas


@router.post("", response_model=StaffOut, status_code=status.HTTP_201_CREATED)
async def crear_staff(
    body: StaffIn,
    db: AsyncSession = Depends(get_db),
    admin: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """Da de alta una cuenta de equipo (por defecto integradora) en ESTE centro."""
    email = body.email.strip().lower()
    ya = (await db.execute(
        select(UsuarioStaff).where(UsuarioStaff.email == email)
    )).scalars().first()
    if ya is not None:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            "Ya existe una cuenta con ese email")
    nuevo = UsuarioStaff(
        centro_id=admin.centro_id,
        nombre=body.nombre.strip(),
        rol=body.rol,
        email=email,
        password_hash=hash_password(body.password),
    )
    db.add(nuevo)
    await db.commit()
    await db.refresh(nuevo)
    return nuevo


@router.patch("/{staff_id}", response_model=StaffOut)
async def actualizar_staff(
    staff_id: str,
    body: StaffUpdate,
    db: AsyncSession = Depends(get_db),
    admin: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """Renombra o da de baja/alta a un miembro del equipo (de su propio centro)."""
    obj = await db.get(UsuarioStaff, staff_id)
    if obj is None or obj.centro_id != admin.centro_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cuenta no encontrada")
    # No puede desactivarse a sí mismo (evita quedarse sin acceso al centro).
    if body.activo is False and obj.id == admin.id:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            "No puedes darte de baja a ti mismo")
    if body.nombre is not None:
        obj.nombre = body.nombre.strip()
    if body.activo is not None:
        obj.activo = body.activo
    await db.commit()
    await db.refresh(obj)
    return obj


@router.post("/{staff_id}/password", status_code=status.HTTP_204_NO_CONTENT)
async def restablecer_password(
    staff_id: str,
    body: StaffPassword,
    db: AsyncSession = Depends(get_db),
    admin: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """El admin del centro restablece la contraseña de un miembro de SU equipo.

    Un equipo no técnico olvida la clave a menudo; sin esto dependía de soporte con
    acceso a la BD. Acotado al propio centro (multi-tenant)."""
    obj = await db.get(UsuarioStaff, staff_id)
    if obj is None or obj.centro_id != admin.centro_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cuenta no encontrada")
    obj.password_hash = hash_password(body.password)
    await db.commit()


@router.post("/{staff_id}/pin", status_code=status.HTTP_204_NO_CONTENT)
async def fijar_pin(
    staff_id: str,
    body: StaffPin,
    db: AsyncSession = Depends(get_db),
    admin: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """El admin fija/cambia el PIN (4 dígitos) de un miembro de SU equipo, para que
    entre rápido en la tablet eligiendo su nombre (sin teclear email)."""
    obj = await db.get(UsuarioStaff, staff_id)
    if obj is None or obj.centro_id != admin.centro_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cuenta no encontrada")
    obj.pin_hash = hash_password(body.pin)
    await db.commit()


@router.delete("/{staff_id}/pin", status_code=status.HTTP_204_NO_CONTENT)
async def quitar_pin(
    staff_id: str,
    db: AsyncSession = Depends(get_db),
    admin: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """Quita el PIN de un miembro (vuelve a solo email+contraseña)."""
    obj = await db.get(UsuarioStaff, staff_id)
    if obj is None or obj.centro_id != admin.centro_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Cuenta no encontrada")
    obj.pin_hash = None
    await db.commit()
