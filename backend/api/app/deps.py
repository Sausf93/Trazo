"""Dependencias compartidas: usuario autenticado, auditoría."""
from __future__ import annotations

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import RegistroAuditoria, UsuarioFinal, UsuarioStaff
from app.security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login", auto_error=True)


async def get_current_staff(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> UsuarioStaff:
    cred_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciales inválidas",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_access_token(token)
        staff_id = payload.get("sub")
        if not staff_id:
            raise cred_exc
    except jwt.PyJWTError:
        raise cred_exc

    staff = await db.get(UsuarioStaff, staff_id)
    if staff is None or not staff.activo:
        raise cred_exc
    return staff


def require_roles(*roles: str):
    """Dependencia factory: exige que el staff tenga uno de los roles dados."""

    async def _checker(staff: UsuarioStaff = Depends(get_current_staff)) -> UsuarioStaff:
        if staff.rol not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requiere rol: {', '.join(roles)}",
            )
        return staff

    return _checker


async def usuario_del_centro(
    db: AsyncSession, usuario_id: str, staff: UsuarioStaff
) -> UsuarioFinal:
    """Carga un usuario final y EXIGE que sea del centro del staff (anti-IDOR).

    Datos de salud = categoría especial RGPD: ningún staff puede tocar datos de un
    usuario de otro centro. Se usa en todo endpoint que reciba un usuario_id.
    """
    uf = await db.get(UsuarioFinal, usuario_id)
    if uf is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    if uf.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    return uf


async def auditar(
    db: AsyncSession,
    staff: UsuarioStaff,
    accion: str,
    usuario_final_id: str | None = None,
    detalle: str | None = None,
) -> None:
    """Deja rastro de acceso a datos de usuario final (RGPD)."""
    db.add(
        RegistroAuditoria(
            staff_id=staff.id,
            usuario_final_id=usuario_final_id,
            accion=accion,
            detalle=detalle,
        )
    )
    # El commit lo hace el endpoint que orquesta la operación.


__all__ = [
    "get_current_staff",
    "require_roles",
    "auditar",
    "usuario_del_centro",
]
