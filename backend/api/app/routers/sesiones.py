"""Sesiones (individual/grupo) y vista en vivo para la facilitadora."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import Acceso, acceso_centro, get_current_staff
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
    LineaConfig,
    LiveOut,
    ParticipanteEstadoOut,
    ParticipanteMasIn,
    ParticipanteProgramadoOut,
    ParticipanteSesion,
    ResumenParticipante,
    ResumenSesionOut,
    SesionActivaOut,
    SesionConfigPut,
    SesionIn,
    SesionOut,
    SesionProgramadaOut,
    SesionResumenOut,
)

router = APIRouter(prefix="/sesiones", tags=["sesiones"])

SEGUNDOS_ATASCADO = 30.0


def _config_json(nivel: str | None, lineas: list[LineaConfig]) -> dict | None:
    """Normaliza la config por participante ({nivel, lineas}) o None.

    Requiere al menos una línea: una config con SOLO nivel dejaría la cola vacía
    (la rama de config no cae al plan), así que en ese caso devolvemos None para
    que el participante use su plan permanente.
    """
    if not lineas:
        return None
    return {
        "nivel": nivel,
        "lineas": [{"bloque": ln.bloque, "n": ln.n} for ln in lineas],
    }


@router.get("/activa", response_model=SesionActivaOut)
async def sesion_activa(
    centro_id: str,
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """Sesión abierta más reciente del centro + sus participantes.

    Es lo que consulta la tablet participante (kiosco) para mostrar la lista de
    "¿quién eres?" y repartir por toque. Accesible por login de staff O por token
    de dispositivo. Devuelve sesion_id=None si no hay ninguna.
    """
    if centro_id != acceso.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    ses = (
        await db.execute(
            select(Sesion)
            .where(
                Sesion.centro_id == centro_id,
                Sesion.cerrada.is_(False),
                Sesion.abierta.is_(True),
            )
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


@router.get("", response_model=list[SesionResumenOut])
async def listar_sesiones(
    centro_id: str,
    estado: str | None = None,  # abierta | cerrada | programada | (todas)
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Historial de sesiones del centro (para el dashboard de la maestra y el panel).

    `estado`: abierta (en vivo), cerrada (pasadas), programada, o sin filtro."""
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    stmt = select(Sesion).where(Sesion.centro_id == centro_id)
    if estado == "abierta":
        stmt = stmt.where(Sesion.abierta.is_(True), Sesion.cerrada.is_(False))
    elif estado == "cerrada":
        stmt = stmt.where(Sesion.cerrada.is_(True))
    elif estado == "programada":
        stmt = stmt.where(Sesion.abierta.is_(False), Sesion.cerrada.is_(False))
    stmt = stmt.order_by(Sesion.fecha.desc()).limit(max(1, min(limit, 100)))
    sesiones = (await db.execute(stmt)).scalars().all()

    salida: list[SesionResumenOut] = []
    for ses in sesiones:
        n = (
            await db.execute(
                select(func.count()).select_from(SesionParticipante).where(
                    SesionParticipante.sesion_id == ses.id)
            )
        ).scalar() or 0
        salida.append(SesionResumenOut(
            id=ses.id, nombre=ses.nombre, fecha=ses.fecha, modo=ses.modo,
            abierta=ses.abierta, iniciada=ses.iniciada, cerrada=ses.cerrada,
            n_participantes=n,
        ))
    return salida


@router.get("/{sesion_id}/resumen", response_model=ResumenSesionOut)
async def resumen_sesion(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Cómo fue la sesión: por participante, cuántas actividades y el desglose
    solo/con_ayuda/no_completado. Para el cierre con resumen y el historial."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")

    parts = (
        await db.execute(
            select(SesionParticipante).where(
                SesionParticipante.sesion_id == sesion_id)
        )
    ).scalars().all()

    fichas: list[ResumenParticipante] = []
    for p in parts:
        uf = await db.get(UsuarioFinal, p.usuario_final_id)
        intentos = (
            await db.execute(
                select(Intento.estado).where(
                    Intento.sesion_id == sesion_id,
                    Intento.usuario_final_id == p.usuario_final_id,
                )
            )
        ).scalars().all()
        fichas.append(ResumenParticipante(
            usuario_final_id=p.usuario_final_id,
            alias_interno=uf.alias_interno if uf else "?",
            n_intentos=len(intentos),
            solo=sum(1 for e in intentos if e == "solo"),
            con_ayuda=sum(1 for e in intentos if e == "con_ayuda"),
            no_completado=sum(1 for e in intentos if e == "no_completado"),
        ))
    return ResumenSesionOut(sesion_id=sesion_id, nombre=ses.nombre, fichas=fichas)


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
    # Verifica que los participantes son del centro (evita colar ids ajenos).
    await _validar_participantes(db, body.participantes, staff)
    ses = Sesion(
        centro_id=staff.centro_id,
        tipo=body.tipo,
        modo=modo,
        nombre=body.nombre,
        ejercicio_compartido_id=body.ejercicio_compartido_id,
        staff_id=staff.id,
        # Programada = borrador para otro día: no se abre hasta que la maestra la abra.
        abierta=not body.programar,
        programada_para=body.programada_para,
    )
    db.add(ses)
    await db.flush()
    # Config por participante (la maestra fija nivel/categorías/nº para la sesión).
    configs = {c.usuario_final_id: c for c in body.configs}
    for uf_id in body.participantes:
        cfg = configs.get(uf_id)
        config_json = _config_json(cfg.nivel, cfg.lineas) if cfg is not None else None
        db.add(SesionParticipante(
            sesion_id=ses.id, usuario_final_id=uf_id, config_json=config_json,
        ))
    await db.commit()
    await db.refresh(ses)
    return ses


async def _validar_participantes(
    db: AsyncSession, participantes: list[str], staff: UsuarioStaff
) -> None:
    """Todos los ids deben ser usuarios finales del centro del staff (anti-IDOR)."""
    for uf_id in participantes:
        uf = await db.get(UsuarioFinal, uf_id)
        if uf is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, f"Participante {uf_id} no existe")
        if uf.centro_id != staff.centro_id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Participante de otro centro")


@router.get("/programadas", response_model=list[SesionProgramadaOut])
async def sesiones_programadas(
    centro_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Salas dejadas PREPARADAS (programadas, aún sin abrir) del centro.

    La maestra las repasa y abre la que toque el día señalado. Devuelve cada una
    con sus participantes y la config fijada, ordenadas por día previsto."""
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    sesiones = (
        await db.execute(
            select(Sesion)
            .where(
                Sesion.centro_id == centro_id,
                Sesion.abierta.is_(False),
                Sesion.cerrada.is_(False),
            )
            .order_by(Sesion.programada_para.asc().nulls_last(), Sesion.fecha.asc())
        )
    ).scalars().all()

    salida: list[SesionProgramadaOut] = []
    for ses in sesiones:
        parts = (
            await db.execute(
                select(SesionParticipante).where(
                    SesionParticipante.sesion_id == ses.id
                )
            )
        ).scalars().all()
        participantes: list[ParticipanteProgramadoOut] = []
        for p in parts:
            uf = await db.get(UsuarioFinal, p.usuario_final_id)
            cfg = p.config_json or {}
            lineas = [
                LineaConfig(bloque=ln.get("bloque"), n=ln.get("n", 1))
                for ln in (cfg.get("lineas") or [])
            ]
            participantes.append(ParticipanteProgramadoOut(
                usuario_final_id=p.usuario_final_id,
                alias_interno=uf.alias_interno if uf else "?",
                nivel=cfg.get("nivel"),
                lineas=lineas,
            ))
        salida.append(SesionProgramadaOut(
            id=ses.id, nombre=ses.nombre, modo=ses.modo,
            programada_para=ses.programada_para, fecha=ses.fecha,
            participantes=participantes,
        ))
    return salida


@router.patch("/{sesion_id}/abrir", response_model=SesionOut)
async def abrir_sesion(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Abre una sesión PROGRAMADA: pasa a estar 'en vivo' para los kioscos.

    Reactualiza su `fecha` a ahora para que sea la sesión activa del centro. Tras
    esto la maestra reparte tablets y luego pulsa 'Iniciar actividad'."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    if ses.cerrada:
        raise HTTPException(status.HTTP_409_CONFLICT, "La sesión está cerrada")
    ses.abierta = True
    ses.fecha = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(ses)
    return ses


@router.put("/{sesion_id}/config", response_model=SesionOut)
async def editar_sesion_programada(
    sesion_id: str,
    body: SesionConfigPut,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Reemplaza participantes/config de una sesión PROGRAMADA (edición previa al día).

    Solo permitido mientras la sesión no se haya abierto ni cerrado."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    if ses.abierta or ses.cerrada:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Solo se editan sesiones programadas sin abrir"
        )
    await _validar_participantes(db, body.participantes, staff)
    if body.nombre is not None:
        ses.nombre = body.nombre
    if body.modo is not None:
        if body.modo not in ("individual", "grupo"):
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "modo inválido")
        ses.modo = body.modo
        ses.tipo = body.modo
    ses.programada_para = body.programada_para
    # Reemplaza el conjunto de participantes por completo.
    prev = (
        await db.execute(
            select(SesionParticipante).where(SesionParticipante.sesion_id == ses.id)
        )
    ).scalars().all()
    for p in prev:
        await db.delete(p)
    await db.flush()
    configs = {c.usuario_final_id: c for c in body.configs}
    for uf_id in body.participantes:
        cfg = configs.get(uf_id)
        config_json = _config_json(cfg.nivel, cfg.lineas) if cfg is not None else None
        db.add(SesionParticipante(
            sesion_id=ses.id, usuario_final_id=uf_id, config_json=config_json,
        ))
    await db.commit()
    await db.refresh(ses)
    return ses


@router.delete("/{sesion_id}", status_code=status.HTTP_204_NO_CONTENT)
async def descartar_sesion_programada(
    sesion_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Descarta una sesión PROGRAMADA que aún no se abrió (no borra sesiones en vivo
    ni con historial). Para limpiar una planificación que ya no se va a usar."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    if ses.abierta or ses.iniciada:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Solo se descartan sesiones programadas sin abrir"
        )
    await db.delete(ses)
    await db.commit()


async def _get_participante(
    db: AsyncSession, sesion_id: str, usuario_id: str, centro_id: str
) -> SesionParticipante:
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != centro_id:
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
    acceso: Acceso = Depends(acceso_centro),
):
    """Lo consulta la tablet del participante (polling): si empezó, su ronda y si
    ya terminó. Cuando la ronda sube (la maestra envió más), pide cola de nuevo.
    Accesible por login de staff O por token de dispositivo."""
    ses = await db.get(Sesion, sesion_id)
    sp = await _get_participante(db, sesion_id, usuario_id, acceso.centro_id)
    return ParticipanteEstadoOut(
        iniciada=bool(ses and ses.iniciada), ronda=sp.ronda, terminado=sp.terminado
    )


@router.post("/{sesion_id}/participantes/{usuario_id}/terminado",
             response_model=ParticipanteEstadoOut)
async def marcar_terminado(
    sesion_id: str,
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """La tablet del participante avisa de que terminó su tanda. Accesible por
    login de staff O por token de dispositivo."""
    sp = await _get_participante(db, sesion_id, usuario_id, acceso.centro_id)
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
    sp = await _get_participante(db, sesion_id, usuario_id, staff.centro_id)
    if body is not None and body.lineas:
        sp.config_json = _config_json(body.nivel, body.lineas)
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
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")

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
