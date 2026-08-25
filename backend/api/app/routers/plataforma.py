"""Plataforma (nivel 0): alta de CENTROS y su primer admin. Reservado al dueño de
la plataforma (tú), fuera del flujo del panel.

Se protege con un token secreto (`PLATFORM_TOKEN`) enviado en la cabecera
`X-Platform-Token`. Si el token no está configurado, el endpoint queda
DESHABILITADO (responde 404) para no dejar una puerta abierta por descuido.
"""
from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import Integer, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.bootstrap import alta_centro_admin
from app.config import settings
from app.database import get_db
from app.models import Centro, Intento, UsuarioFinal, UsuarioStaff
from app.schemas import (
    CentroEstadoIn,
    CentroInfoOut,
    CentroPlataformaIn,
    CentroPlataformaOut,
    StaffOut,
)

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


@router.get("/centros", response_model=list[CentroInfoOut])
async def listar_centros(
    x_platform_token: str | None = Header(default=None, alias="X-Platform-Token"),
    db: AsyncSession = Depends(get_db),
):
    """Todos los centros con su estado (activo/bloqueado) y nº de cuentas/pacientes."""
    _exigir_token(x_platform_token)
    centros = (await db.execute(
        select(Centro).order_by(Centro.creado_en.asc())
    )).scalars().all()

    # Conteos por centro en 2 consultas (sin N+1).
    staff_tot: dict[str, int] = {}
    staff_act: dict[str, int] = {}
    for cid, tot, act in (await db.execute(
        select(UsuarioStaff.centro_id, func.count(),
               func.sum(cast(UsuarioStaff.activo, Integer)))
        .group_by(UsuarioStaff.centro_id)
    )).all():
        staff_tot[cid] = int(tot or 0)
        staff_act[cid] = int(act or 0)
    pac_tot: dict[str, int] = {}
    for cid, tot in (await db.execute(
        select(UsuarioFinal.centro_id, func.count())
        .where(UsuarioFinal.activo.is_(True))
        .group_by(UsuarioFinal.centro_id)
    )).all():
        pac_tot[cid] = int(tot or 0)

    # Personas ACTIVAS del mes (con al menos 1 intento en 30 días) por centro:
    # es la base del control de plan / facturación por excedente.
    desde = datetime.now(timezone.utc) - timedelta(days=30)
    activas: dict[str, int] = {}
    for cid, n in (await db.execute(
        select(UsuarioFinal.centro_id,
               func.count(func.distinct(Intento.usuario_final_id)))
        .join(Intento, Intento.usuario_final_id == UsuarioFinal.id)
        .where(Intento.timestamp_inicio >= desde)
        .group_by(UsuarioFinal.centro_id)
    )).all():
        activas[cid] = int(n or 0)

    salida = []
    for c in centros:
        act = activas.get(c.id, 0)
        tope = c.tope_personas or 0
        extra = max(0, act - tope) if tope else 0
        salida.append(CentroInfoOut(
            id=c.id, nombre=c.nombre, activo=c.activo, creado_en=c.creado_en,
            n_staff=staff_tot.get(c.id, 0),
            n_staff_activos=staff_act.get(c.id, 0),
            n_pacientes=pac_tot.get(c.id, 0),
            tope_personas=tope,
            personas_activas=act,
            sobre_tope=bool(tope) and act > tope,
            personas_extra=extra,
        ))
    return salida


@router.get("/centros/{centro_id}/staff", response_model=list[StaffOut])
async def staff_de_centro(
    centro_id: str,
    x_platform_token: str | None = Header(default=None, alias="X-Platform-Token"),
    db: AsyncSession = Depends(get_db),
):
    """Cuentas de un centro (para que el super-admin vea quién puede entrar)."""
    _exigir_token(x_platform_token)
    filas = (await db.execute(
        select(UsuarioStaff)
        .where(UsuarioStaff.centro_id == centro_id)
        .order_by(UsuarioStaff.creado_en.asc())
    )).scalars().all()
    return filas


@router.patch("/centros/{centro_id}", response_model=CentroInfoOut)
async def cambiar_estado_centro(
    centro_id: str,
    body: CentroEstadoIn,
    x_platform_token: str | None = Header(default=None, alias="X-Platform-Token"),
    db: AsyncSession = Depends(get_db),
):
    """Bloquea (activo=false) o reactiva (activo=true) un centro. No borra datos.

    Al bloquear, nadie de ese centro puede entrar ni usar la API (el estado se
    comprueba en cada petición). Al reactivar, todo vuelve a funcionar igual."""
    _exigir_token(x_platform_token)
    centro = await db.get(Centro, centro_id)
    if centro is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Centro no encontrado")
    centro.activo = body.activo
    await db.commit()
    await db.refresh(centro)
    return CentroInfoOut(
        id=centro.id, nombre=centro.nombre, activo=centro.activo,
        creado_en=centro.creado_en,
    )
