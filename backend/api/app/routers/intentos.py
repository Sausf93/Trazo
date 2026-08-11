"""Registro de intentos (idempotente por UUID) y cambio de estado."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import (
    Acceso,
    acceso_centro,
    auditar,
    get_current_staff,
    usuario_del_centro,
)
from app.models import (
    ESTADOS_INTENTO,
    EjercicioCatalogo,
    Intento,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import AyudaIntentoIn, IntentoIn, IntentoOut, ResultadoIntentoIn
from app.services.alertas import evaluar_usuario_bloque
from app.services.correccion import corregir

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
    acceso: Acceso = Depends(acceso_centro),
):
    """Registra un intento (idempotente por id). Accesible por login de staff O
    por token de dispositivo (la tablet del kiosco registra sus mediciones)."""
    if body.estado not in ESTADOS_INTENTO:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"estado inválido: {body.estado}")

    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    # RGPD/seguridad: la sesión y la persona deben ser del mismo centro.
    if ses.centro_id != acceso.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    uf = await db.get(UsuarioFinal, body.usuario_final_id)
    if uf is None or uf.centro_id != acceso.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Usuario no pertenece a tu centro")
    if not uf.activo:
        raise HTTPException(status.HTTP_409_CONFLICT, "El usuario está dado de baja")
    if ses.cerrada:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            "La sesión está cerrada: no admite más intentos")

    # La persona debe ser participante de ESTA sesión: si no, se estarían
    # inyectando intentos en el histórico de otro paciente (falsearía alertas).
    es_participante = (await db.execute(
        select(SesionParticipante.id).where(
            SesionParticipante.sesion_id == sesion_id,
            SesionParticipante.usuario_final_id == body.usuario_final_id,
        )
    )).first()
    if es_participante is None:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "La persona no participa en esta sesión")

    # Idempotencia: si el cliente reenvía el mismo UUID, no duplicar. Pero el id
    # debe corresponder al MISMO usuario y sesión: si no, es un id ajeno (no se
    # devuelve el intento de otra persona/centro -> anti-IDOR).
    if body.id:
        existente = await db.get(Intento, body.id)
        if existente is not None:
            if (existente.usuario_final_id != body.usuario_final_id
                    or existente.sesion_id != sesion_id):
                raise HTTPException(
                    status.HTTP_409_CONFLICT, "El id del intento ya está en uso")
            return existente

    ej = await db.get(EjercicioCatalogo, body.ejercicio_id)
    if ej is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ejercicio no encontrado")

    # Autocorrección del RESULTADO a partir de lo que la persona hizo de verdad
    # (métricas del widget + respuesta correcta en cantidad_objetivo). Señal
    # primaria, independiente de la integradora.
    resultado = corregir(ej.plantilla_tipo, body.valores_json, body.cantidad_objetivo_json)

    intento = Intento(
        id=body.id or None,
        usuario_final_id=body.usuario_final_id,
        sesion_id=sesion_id,
        ejercicio_id=body.ejercicio_id,
        estado=body.estado,
        resultado=resultado,
        con_ayuda=False,
        timestamp_inicio=body.timestamp_inicio or datetime.now(timezone.utc),
        timestamp_fin=body.timestamp_fin,
        valores_json=body.valores_json,
        cantidad_objetivo_json=body.cantidad_objetivo_json,
    )
    # id=None -> deja que el default genere el UUID.
    if body.id:
        intento.id = body.id
    db.add(intento)

    try:
        await db.flush()
        # Reevaluar alertas del bloque para esta persona (contra su histórico).
        await evaluar_usuario_bloque(db, body.usuario_final_id, ej.bloque)
        await db.commit()
    except IntegrityError:
        # Carrera: dos reenvíos concurrentes del mismo id offline. El otro ganó;
        # tratamos este como reenvío idempotente en vez de devolver un 500.
        await db.rollback()
        if body.id:
            ya = await db.get(Intento, body.id)
            if ya is not None and ya.usuario_final_id == body.usuario_final_id:
                return ya
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Conflicto al registrar el intento")

    await db.refresh(intento)
    return intento


@router.patch("/intentos/{intento_id}/ayuda", response_model=IntentoOut)
async def marcar_ayuda(
    intento_id: str,
    body: AyudaIntentoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """La integradora marca/desmarca que AYUDÓ en esta actividad concreta.

    Capa secundaria: NO cambia el resultado autocorregido; solo anota que hubo
    ayuda (se cuelga de la actividad, no de la persona entera)."""
    intento = await db.get(Intento, intento_id)
    if intento is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Intento no encontrado")
    await usuario_del_centro(db, intento.usuario_final_id, staff)
    intento.con_ayuda = bool(body.con_ayuda)
    await auditar(db, staff, "marcar_ayuda", usuario_final_id=intento.usuario_final_id,
                  detalle=f"intento={intento_id} con_ayuda={intento.con_ayuda}")
    await db.commit()
    await db.refresh(intento)
    return intento


@router.patch("/intentos/{intento_id}/resultado", response_model=IntentoOut)
async def marcar_resultado(
    intento_id: str,
    body: ResultadoIntentoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Cola de revisión: la integradora fija el resultado de una actividad que la
    app no supo juzgar (sin_valorar) — p. ej. una respuesta oral o un trazo
    dudoso. Reevalúa alertas del bloque tras el cambio."""
    if body.resultado not in ("logrado", "parcial", "no_logrado"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"resultado inválido: {body.resultado}")
    intento = await db.get(Intento, intento_id)
    if intento is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Intento no encontrado")
    await usuario_del_centro(db, intento.usuario_final_id, staff)
    intento.resultado = body.resultado
    await auditar(db, staff, "marcar_resultado", usuario_final_id=intento.usuario_final_id,
                  detalle=f"intento={intento_id} resultado={body.resultado}")
    ej = await db.get(EjercicioCatalogo, intento.ejercicio_id)
    if ej is not None:
        await evaluar_usuario_bloque(db, intento.usuario_final_id, ej.bloque)
    await db.commit()
    await db.refresh(intento)
    return intento
