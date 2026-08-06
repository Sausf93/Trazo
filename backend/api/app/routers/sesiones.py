"""Sesiones (individual/grupo) y vista en vivo para la facilitadora."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_staff
from app.models import (
    EjercicioCatalogo,
    Intento,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import (
    FichaViva,
    LiveOut,
    ParticipanteEstadoOut,
    ParticipanteMasIn,
    ParticipanteSesion,
    SesionActivaOut,
    SesionIn,
    SesionOut,
)

router = APIRouter(prefix="/sesiones", tags=["sesiones"])

SEGUNDOS_ATASCADO = 30.0


@router.get("/activa", response_model=SesionActivaOut)
async def sesion_activa(
    centro_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Sesión abierta más reciente del centro + sus participantes.

    Es lo que consulta la tablet participante (kiosco) para mostrar la lista de
    "¿quién eres?" y repartir por toque. Devuelve sesion_id=None si no hay ninguna.
    """
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    ses = (
        await db.execute(
            select(Sesion)
            .where(Sesion.centro_id == centro_id, Sesion.cerrada.is_(False))
            .order_by(Sesion.fecha.desc())
            .limit(1)
        )
    ).scalars().first()
    if ses is None:
        return SesionActivaOut()

    parts = (
        await db.execute(
            select(SesionParticipante).where(SesionParticipante.sesion_id == ses.id)
        )
    ).scalars().all()
    participantes: list[ParticipanteSesion] = []
    for p in parts:
        uf = await db.get(UsuarioFinal, p.usuario_final_id)
        participantes.append(ParticipanteSesion(
            usuario_final_id=p.usuario_final_id,
            alias_interno=uf.alias_interno if uf else "?",
        ))
    return SesionActivaOut(
        sesion_id=ses.id, nombre=ses.nombre, modo=ses.modo,
        iniciada=ses.iniciada,
        ejercicio_compartido_id=ses.ejercicio_compartido_id,
        participantes=participantes,
    )


@router.post("", response_model=SesionOut, status_code=status.HTTP_201_CREATED)
async def crear_sesion(
    body: SesionIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    if body.tipo not in ("individual", "grupo"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "tipo inválido")
    modo = body.modo or body.tipo
    if modo not in ("individual", "grupo"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "modo inválido")
    if body.ejercicio_compartido_id is not None:
        ej = await db.get(EjercicioCatalogo, body.ejercicio_compartido_id)
        if ej is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Ejercicio compartido no encontrado")
    ses = Sesion(
        centro_id=staff.centro_id,
        tipo=body.tipo,
        modo=modo,
        nombre=body.nombre,
        ejercicio_compartido_id=body.ejercicio_compartido_id,
        staff_id=staff.id,
    )
    db.add(ses)
    await db.flush()
    # Config por participante (la maestra fija nivel/categorías/nº para la sesión).
    configs = {c.usuario_final_id: c for c in body.configs}
    for uf_id in body.participantes:
        cfg = configs.get(uf_id)
        config_json = None
        if cfg is not None and (cfg.lineas or cfg.nivel):
            config_json = {
                "nivel": cfg.nivel,
                "lineas": [{"bloque": ln.bloque, "n": ln.n} for ln in cfg.lineas],
            }
        db.add(SesionParticipante(
            sesion_id=ses.id, usuario_final_id=uf_id, config_json=config_json,
        ))
    await db.commit()
    await db.refresh(ses)
    return ses


async def _get_participante(
    db: AsyncSession, sesion_id: str, usuario_id: str, staff: UsuarioStaff
) -> SesionParticipante:
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    sp = (
        await db.execute(
            select(SesionParticipante).where(
                SesionParticipante.sesion_id == sesion_id,
                SesionParticipante.usuario_final_id == usuario_id,
            )
        )
    ).scalars().first()
    if sp is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Participante no está en la sesión")
    return sp


@router.get("/{sesion_id}/participantes/{usuario_id}/estado",
            response_model=ParticipanteEstadoOut)
async def estado_participante(
    sesion_id: str,
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Lo consulta la tablet del participante (polling): si empezó, su ronda y si
    ya terminó. Cuando la ronda sube (la maestra envió más), pide cola de nuevo."""
    ses = await db.get(Sesion, sesion_id)
    sp = await _get_participante(db, sesion_id, usuario_id, staff)
    return ParticipanteEstadoOut(
        iniciada=bool(ses and ses.iniciada), ronda=sp.ronda, terminado=sp.terminado
    )


@router.post("/{sesion_id}/participantes/{usuario_id}/terminado",
             response_model=ParticipanteEstadoOut)
async def marcar_terminado(
    sesion_id: str,
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """La tablet del participante avisa de que terminó su tanda."""
    sp = await _get_participante(db, sesion_id, usuario_id, staff)
    sp.terminado = True
    await db.commit()
    ses = await db.get(Sesion, sesion_id)
    return ParticipanteEstadoOut(
        iniciada=bool(ses and ses.iniciada), ronda=sp.ronda, terminado=True
    )


@router.patch("/{sesion_id}/participantes/{usuario_id}/mas",
              response_model=ParticipanteEstadoOut)
async def enviar_mas(
    sesion_id: str,
    usuario_id: str,
    body: ParticipanteMasIn | None = None,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """La maestra manda OTRA tanda a alguien que terminó (sin que espere a los demás).

    Sube la ronda y reinicia `terminado`. Si viene config nueva, la aplica; si no,
    repite la que tuviera (o su plan).
    """
    sp = await _get_participante(db, sesion_id, usuario_id, staff)
    if body is not None and (body.lineas or body.nivel):
        sp.config_json = {
            "nivel": body.nivel,
            "lineas": [{"bloque": ln.bloque, "n": ln.n} for ln in body.lineas],
        }
    sp.ronda += 1
    sp.terminado = False
    await db.commit()
    ses = await db.get(Sesion, sesion_id)
    return ParticipanteEstadoOut(
        iniciada=bool(ses and ses.iniciada), ronda=sp.ronda, terminado=False
    )


@router.patch("/{sesion_id}/iniciar", response_model=SesionOut)
async def iniciar_sesion(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """La maestra pulsa 'Iniciar actividad': arrancan los ejercicios para todos."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    ses.iniciada = True
    await db.commit()
    await db.refresh(ses)
    return ses


@router.patch("/{sesion_id}/cerrar", response_model=SesionOut)
async def cerrar_sesion(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """La maestra cierra la sala: las tablets vuelven a 'elegir rol'."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    ses.cerrada = True
    await db.commit()
    await db.refresh(ses)
    return ses


@router.get("/{sesion_id}/live", response_model=LiveOut)
async def sesion_live(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Estado en vivo para la vista facilitadora (pensado para polling 3-5s)."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")

    parts = (
        await db.execute(
            select(SesionParticipante).where(SesionParticipante.sesion_id == sesion_id)
        )
    ).scalars().all()

    ahora = datetime.now(timezone.utc)
    fichas: list[FichaViva] = []
    for p in parts:
        uf = await db.get(UsuarioFinal, p.usuario_final_id)
        ultimo = (
            await db.execute(
                select(Intento)
                .where(
                    Intento.sesion_id == sesion_id,
                    Intento.usuario_final_id == p.usuario_final_id,
                )
                .order_by(Intento.timestamp_inicio.desc())
                .limit(1)
            )
        ).scalars().first()

        ejercicio_actual = None
        ultimo_estado = None
        segundos = None
        atascado = False
        if ultimo is not None:
            ej = await db.get(EjercicioCatalogo, ultimo.ejercicio_id)
            ejercicio_actual = ej.nombre if ej else None
            ultimo_estado = ultimo.estado
            ref = ultimo.timestamp_fin or ultimo.timestamp_inicio
            if ref is not None:
                if ref.tzinfo is None:
                    ref = ref.replace(tzinfo=timezone.utc)
                segundos = (ahora - ref).total_seconds()
                atascado = (not ses.cerrada) and segundos >= SEGUNDOS_ATASCADO

        fichas.append(FichaViva(
            usuario_final_id=p.usuario_final_id,
            alias_interno=uf.alias_interno if uf else "?",
            ejercicio_actual=ejercicio_actual,
            ultimo_estado=ultimo_estado,
            ultimo_intento_id=ultimo.id if ultimo is not None else None,
            segundos_desde_ultimo_intento=segundos,
            atascado=atascado,
            terminado=p.terminado,
            ronda=p.ronda,
        ))

    return LiveOut(sesion_id=sesion_id, tipo=ses.tipo, fichas=fichas)
