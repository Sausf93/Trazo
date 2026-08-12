"""Autenticación: login por email/contraseña -> JWT."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import UsuarioStaff
from app.schemas import TokenOut
from app.security import create_access_token, verify_password
from app.services.rate_limit import limitador_login

router = APIRouter(prefix="/auth", tags=["auth"])


def _clave_limite(request: Request, email: str) -> str:
    """Clave del rate-limit: IP del cliente + email (en minúsculas)."""
    ip = request.client.host if request.client else "desconocida"
    return f"{ip}:{email.strip().lower()}"


@router.post("/login", response_model=TokenOut)
async def login(
    request: Request,
    form: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    """`username` = email del staff. Devuelve un JWT Bearer.

    Protegido con rate-limit: tras varios fallos seguidos desde la misma IP y
    email se bloquea temporalmente (429) para frenar la fuerza bruta.
    """
    clave = _clave_limite(request, form.username)
    espera = limitador_login.segundos_bloqueo(clave)
    if espera > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiados intentos. Espera unos minutos e inténtalo de nuevo.",
            headers={"Retry-After": str(espera)},
        )

    staff = (
        await db.execute(select(UsuarioStaff).where(UsuarioStaff.email == form.username))
    ).scalars().first()

    if staff is None or not verify_password(form.password, staff.password_hash) or not staff.activo:
        limitador_login.registrar_fallo(clave)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
        )

    # Login correcto: se olvida el historial de fallos de esa IP+email.
    limitador_login.limpiar(clave)

    token = create_access_token(
        subject=staff.id,
        extra={"rol": staff.rol, "centro_id": staff.centro_id},
    )
    return TokenOut(
        access_token=token,
        id=staff.id,
        rol=staff.rol,
        nombre=staff.nombre,
        centro_id=staff.centro_id,
    )
