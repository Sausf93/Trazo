"""Registro de intentos (idempotente por UUID) y cambio de estado."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_staff
from app.models import (
    ESTADOS_INTENTO,
    EjercicioCatalogo,
    Intento,
    Sesion,
    UsuarioStaff,
)
from app.schemas import EstadoIntentoIn, IntentoIn, IntentoOut
from app.services.alertas import evaluar_usuario_bloque

router = APIRouter(tags=["intentos"])


@router.post(
    "/sesiones/{sesion_id}/intentos",
    response_model=IntentoOut,
    status_code=status.HTTP_201_CREATED,
)
async def registrar_intento(
    sesion_id: str,
    body: IntentoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    if body.estado not in ESTADOS_INTENTO:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"estado inválido: {body.estado}")

    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")

    # Idempotencia: si el cliente reenvía el mismo UUID, no duplicar.
    if body.id:
        existente = await db.get(Intento, body.id)
        if existente is not None:
            return existente

    ej = await db.get(EjercicioCatalogo, body.ejercicio_id)
    if ej is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ejercicio no encontrado")

    intento = Intento(
        id=body.id or None,
        usuario_final_id=body.usuario_final_id,
        sesion_id=sesion_id,
        ejercicio_id=body.ejercicio_id,
        estado=body.estado,
        timestamp_inicio=body.timestamp_inicio or datetime.now(timezone.utc),
        timestamp_fin=body.timestamp_fin,
        valores_json=body.valores_json,
        cantidad_objetivo_json=body.cantidad_objetivo_json,
    )
    # id=None -> deja que el default genere el UUID.
    if body.id:
        intento.id = body.id
    db.add(intento)
    await db.flush()

    # Reevaluar alertas del bloque para esta persona (siempre contra su histórico).
    await evaluar_usuario_bloque(db, body.usuario_final_id, ej.bloque)

    await db.commit()
    await db.refresh(intento)
    return intento


@router.patch("/intentos/{intento_id}/estado", response_model=IntentoOut)
async def cambiar_estado(
    intento_id: str,
    body: EstadoIntentoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Marcar 'con_ayuda' / 'no_completado' desde el control de la facilitadora."""
    if body.estado not in ESTADOS_INTENTO:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"estado inválido: {body.estado}")
    intento = await db.get(Intento, intento_id)
    if intento is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Intento no encontrado")
    intento.estado = body.estado
    await db.commit()
    await db.refresh(intento)
    return intento
