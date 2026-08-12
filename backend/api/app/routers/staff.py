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
from app.schemas import StaffIn, StaffOut, StaffUpdate
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
