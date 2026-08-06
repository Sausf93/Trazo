"""Autenticación: login por email/contraseña -> JWT."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import UsuarioStaff
from app.schemas import TokenOut
from app.security import create_access_token, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenOut)
async def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """`username` = email del staff. Devuelve un JWT Bearer."""
    staff = (
        await db.execute(select(UsuarioStaff).where(UsuarioStaff.email == form.username))
    ).scalars().first()

    if staff is None or not verify_password(form.password, staff.password_hash) or not staff.activo:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
        )

    token = create_access_token(
        subject=staff.id,
        extra={"rol": staff.rol, "centro_id": staff.centro_id},
    )
    return TokenOut(
        access_token=token,
        rol=staff.rol,
        nombre=staff.nombre,
        centro_id=staff.centro_id,
    )
