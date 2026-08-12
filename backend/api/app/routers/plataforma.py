"""Plataforma (nivel 0): alta de CENTROS y su primer admin. Reservado al dueño de
la plataforma (tú), fuera del flujo del panel.

Se protege con un token secreto (`PLATFORM_TOKEN`) enviado en la cabecera
`X-Platform-Token`. Si el token no está configurado, el endpoint queda
DESHABILITADO (responde 404) para no dejar una puerta abierta por descuido.
"""
from __future__ import annotations

import secrets

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.bootstrap import alta_centro_admin
from app.config import settings
from app.database import get_db
from app.schemas import CentroPlataformaIn, CentroPlataformaOut

router = APIRouter(prefix="/plataforma", tags=["plataforma"])


def _exigir_token(x_platform_token: str | None) -> None:
    esperado = settings.platform_token or ""
    if not esperado:
        # Sin token configurado, el alta de centros no existe (puerta cerrada).
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No disponible")
    if not x_platform_token or not secrets.compare_digest(x_platform_token, esperado):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token de plataforma inválido")


@router.post("/centros", response_model=CentroPlataformaOut)
async def crear_centro(
    body: CentroPlataformaIn,
    x_platform_token: str | None = Header(default=None, alias="X-Platform-Token"),
    db: AsyncSession = Depends(get_db),
):
    """Crea (idempotente) un centro y su cuenta admin. Requiere X-Platform-Token."""
    _exigir_token(x_platform_token)
    mensaje, creado = await alta_centro_admin(
        db, body.centro, body.email, body.password, body.nombre)
    return CentroPlataformaOut(mensaje=mensaje, creado=creado)
