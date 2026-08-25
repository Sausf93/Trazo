"""Dependencias compartidas: usuario autenticado, auditoría."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Centro, Dispositivo, RegistroAuditoria, UsuarioFinal, UsuarioStaff
from app.security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login", auto_error=True)

# Mensaje único para un centro suspendido (impago, etc.): se corta el acceso pero
# los datos se conservan. Se comprueba en CADA petición, así el bloqueo del
# super-admin surte efecto al instante, incluso con tokens ya emitidos.
CENTRO_SUSPENDIDO = "Centro suspendido. Contacta con Trazo para reactivarlo."


async def _exigir_centro_activo(db: AsyncSession, centro_id: str) -> None:
    centro = await db.get(Centro, centro_id)
    if centro is None or not centro.activo:
        raise HTTPException(status.HTTP_403_FORBIDDEN, CENTRO_SUSPENDIDO)


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
    # El centro debe seguir activo (no suspendido por la plataforma).
    await _exigir_centro_activo(db, staff.centro_id)
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


@dataclass
class Acceso:
    """Contexto de acceso a un centro: lo abre un staff (login) O una tablet
    emparejada (token de dispositivo). Así los endpoints de kiosco funcionan sin
    login de la integradora, pero siguen aceptando el login (compatibilidad)."""
    centro_id: str
    staff: UsuarioStaff | None = None
    dispositivo: Dispositivo | None = None


async def acceso_centro(
    x_device_token: str | None = Header(default=None, alias="X-Device-Token"),
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> Acceso:
    """Resuelve el centro desde un token de dispositivo (kiosco) o un JWT de staff.

    Prioriza el token de dispositivo si viene; si no, cae al Bearer de staff. Es
    aditivo: el login clásico sigue valiendo igual."""
    cred_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No autenticado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    # 1) Tablet emparejada (token de dispositivo activo).
    if x_device_token:
        disp = (
            await db.execute(
                select(Dispositivo).where(
                    Dispositivo.token == x_device_token,
                    Dispositivo.activo.is_(True),
                )
            )
        ).scalars().first()
        if disp is None:
            raise HTTPException(
                status.HTTP_401_UNAUTHORIZED, "Dispositivo no autorizado o revocado"
            )
        await _exigir_centro_activo(db, disp.centro_id)
        # "Última vez activa" de la tablet (para saber si sigue en uso o se perdió).
        # Con throttle (máx. 1 escritura cada 10 min) para no escribir en cada poll.
        ahora = datetime.now(timezone.utc)
        vp = disp.visto_en
        if vp is not None and vp.tzinfo is None:
            vp = vp.replace(tzinfo=timezone.utc)
        if vp is None or (ahora - vp) > timedelta(minutes=10):
            try:
                disp.visto_en = ahora
                await db.commit()
            except Exception:  # pragma: no cover - no romper la petición por esto
                await db.rollback()
        return Acceso(centro_id=disp.centro_id, dispositivo=disp)
    # 2) Login de staff (Bearer JWT).
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
        try:
            payload = decode_access_token(token)
            staff_id = payload.get("sub")
        except jwt.PyJWTError:
            raise cred_exc
        staff = await db.get(UsuarioStaff, staff_id) if staff_id else None
        if staff is None or not staff.activo:
            raise cred_exc
        await _exigir_centro_activo(db, staff.centro_id)
        return Acceso(centro_id=staff.centro_id, staff=staff)
    raise cred_exc


async def usuario_del_centro_id(
    db: AsyncSession, usuario_id: str, centro_id: str
) -> UsuarioFinal:
    """Como `usuario_del_centro` pero contra un centro_id (para acceso de kiosco)."""
    uf = await db.get(UsuarioFinal, usuario_id)
    if uf is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    if uf.centro_id != centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    return uf


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
    "usuario_del_centro_id",
    "Acceso",
    "acceso_centro",
]
