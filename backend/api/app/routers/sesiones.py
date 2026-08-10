"""Sesiones (individual/grupo) y vista en vivo para la facilitadora."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

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
    ActividadActualIn,
    FichaViva,
    LineaConfig,
    LiveOut,
    NotaSesionIn,
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
# Una sala abierta más antigua que esto se considera "zombi" y ya no se sirve a
# los kioscos (la maestra no la cerró; evita actividades sin supervisión).
_HORAS_SALA_VIVA = 12


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
    # Solo salas RECIENTES: una sala que quedó "abierta" de un día anterior (la
    # maestra no la cerró) no debe seguir sirviendo actividades sin supervisión.
    limite = datetime.now(timezone.utc) - timedelta(hours=_HORAS_SALA_VIVA)
    ses = (
        await db.execute(
            select(Sesion)
            .where(
                Sesion.centro_id == centro_id,
                Sesion.cerrada.is_(False),
                Sesion.abierta.is_(True),
                Sesion.fecha >= limite,
            )
            .order_by(Sesion.fecha.desc())
            .limit(1)
        )
    ).scalars().first()
    if ses is None:
        return SesionActivaOut()

    # Participantes + alias en UNA consulta (sin N+1): la consulta el kiosco por
    # polling, así que evitar el bucle de gets importa.
    filas = (await db.execute(
        select(SesionParticipante.usuario_final_id, UsuarioFinal.alias_interno)
        .join(UsuarioFinal, UsuarioFinal.id == SesionParticipante.usuario_final_id)
        .where(SesionParticipante.sesion_id == ses.id)
    )).all()
    participantes = [
        ParticipanteSesion(usuario_final_id=uid, alias_interno=alias)
        for uid, alias in filas
    ]
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
        # Solo salas EN VIVO reales: abiertas, sin cerrar y no "zombi" (viejas).
        corte = datetime.now(timezone.utc) - timedelta(hours=_HORAS_SALA_VIVA)
        stmt = stmt.where(
            Sesion.abierta.is_(True),
            Sesion.cerrada.is_(False),
            Sesion.fecha >= corte,
        )
    elif estado == "cerrada":
        stmt = stmt.where(Sesion.cerrada.is_(True))
    elif estado == "programada":
        stmt = stmt.where(Sesion.abierta.is_(False), Sesion.cerrada.is_(False))
    stmt = stmt.order_by(Sesion.fecha.desc()).limit(max(1, min(limit, 100)))
    sesiones = (await db.execute(stmt)).scalars().all()
    if not sesiones:
        return []

    ids = [s.id for s in sesiones]
    # Conteo de participantes de TODAS las sesiones en una sola consulta (sin N+1).
    filas = (await db.execute(
        select(SesionParticipante.sesion_id, func.count())
        .where(SesionParticipante.sesion_id.in_(ids))
        .group_by(SesionParticipante.sesion_id)
    )).all()
    conteo = {sid: n for sid, n in filas}
    # Nombre del staff que abrió cada sesión (una consulta para todos).
    staff_ids = {s.staff_id for s in sesiones if s.staff_id}
    nombres: dict[str, str] = {}
    if staff_ids:
        nombres = dict((await db.execute(
            select(UsuarioStaff.id, UsuarioStaff.nombre)
            .where(UsuarioStaff.id.in_(staff_ids))
        )).all())

    return [
        SesionResumenOut(
            id=ses.id, nombre=ses.nombre, fecha=ses.fecha, modo=ses.modo,
            abierta=ses.abierta, iniciada=ses.iniciada, cerrada=ses.cerrada,
            n_participantes=conteo.get(ses.id, 0),
            staff_id=ses.staff_id,
            staff_nombre=nombres.get(ses.staff_id),
        )
        for ses in sesiones
    ]


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
    if not parts:
        return ResumenSesionOut(
            sesion_id=sesion_id, nombre=ses.nombre, notas=ses.notas, fichas=[])

    uf_ids = [p.usuario_final_id for p in parts]
    # Alias de todos los participantes en una consulta (sin N+1).
    alias = dict((await db.execute(
        select(UsuarioFinal.id, UsuarioFinal.alias_interno)
        .where(UsuarioFinal.id.in_(uf_ids))
    )).all())
    # Desglose de estados por participante, agregado en SQL (sin N+1).
    filas = (await db.execute(
        select(Intento.usuario_final_id, Intento.estado, func.count())
        .where(Intento.sesion_id == sesion_id)
        .group_by(Intento.usuario_final_id, Intento.estado)
    )).all()
    por_usuario: dict[str, dict[str, int]] = {}
    for uf_id, estado, n in filas:
        por_usuario.setdefault(uf_id, {})[estado] = n

    fichas: list[ResumenParticipante] = []
    for p in parts:
        est = por_usuario.get(p.usuario_final_id, {})
        solo = est.get("solo", 0)
        con_ayuda = est.get("con_ayuda", 0)
        no_completado = est.get("no_completado", 0)
        sin_valorar = est.get("sin_valorar", 0)
        fichas.append(ResumenParticipante(
            usuario_final_id=p.usuario_final_id,
            alias_interno=alias.get(p.usuario_final_id, "?"),
            n_intentos=solo + con_ayuda + no_completado,
            solo=solo,
            con_ayuda=con_ayuda,
            no_completado=no_completado,
            sin_valorar=sin_valorar,
        ))
    return ResumenSesionOut(
        sesion_id=sesion_id, nombre=ses.nombre, notas=ses.notas, fichas=fichas)


@router.patch("/{sesion_id}/notas", response_model=ResumenSesionOut)
async def guardar_notas(
    sesion_id: str,
    body: NotaSesionIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Guarda las observaciones libres de la facilitadora sobre la sesión."""
    ses = await db.get(Sesion, sesion_id)
    if ses is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
    if ses.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    nota = body.nota.strip()
    ses.notas = nota or None
    await db.commit()
    return await resumen_sesion(sesion_id, db=db, staff=staff)


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

    if not sesiones:
        return []
    # Participantes + alias de TODAS las sesiones en una consulta (sin N+1).
    ids = [s.id for s in sesiones]
    filas = (await db.execute(
        select(
            SesionParticipante.sesion_id,
            SesionParticipante.usuario_final_id,
            SesionParticipante.config_json,
            UsuarioFinal.alias_interno,
        )
        .join(UsuarioFinal, UsuarioFinal.id == SesionParticipante.usuario_final_id)
        .where(SesionParticipante.sesion_id.in_(ids))
    )).all()
    por_sesion: dict[str, list[ParticipanteProgramadoOut]] = {}
    for sid, uf_id, config_json, alias in filas:
        cfg = config_json or {}
        lineas = [
            LineaConfig(bloque=ln.get("bloque"), n=ln.get("n", 1))
            for ln in (cfg.get("lineas") or [])
        ]
        por_sesion.setdefault(sid, []).append(ParticipanteProgramadoOut(
            usuario_final_id=uf_id,
            alias_interno=alias,
            nivel=cfg.get("nivel"),
            lineas=lineas,
        ))
    return [
        SesionProgramadaOut(
            id=ses.id, nombre=ses.nombre, modo=ses.modo,
            programada_para=ses.programada_para, fecha=ses.fecha,
            participantes=por_sesion.get(ses.id, []),
        )
        for ses in sesiones
    ]


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
    sp.actividad_actual = None  # ya no está en ninguna actividad
    await db.commit()
    ses = await db.get(Sesion, sesion_id)
    return ParticipanteEstadoOut(
        iniciada=bool(ses and ses.iniciada), ronda=sp.ronda, terminado=True
    )


@router.patch("/{sesion_id}/participantes/{usuario_id}/actual",
              status_code=status.HTTP_204_NO_CONTENT)
async def reportar_actividad_actual(
    sesion_id: str,
    usuario_id: str,
    body: ActividadActualIn,
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """El kiosco reporta en qué actividad va AHORA la persona, para que el monitor
    de la maestra lo muestre en vivo (no solo el último intento enviado)."""
    sp = await _get_participante(db, sesion_id, usuario_id, acceso.centro_id)
    sp.actividad_actual = body.actividad
    sp.pos_actual = body.pos
    sp.total_actual = body.total
    await db.commit()


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
    # Precarga en bloque (sin N+1): alias, último intento por persona y nombres.
    uf_ids = [p.usuario_final_id for p in parts]
    alias = dict((await db.execute(
        select(UsuarioFinal.id, UsuarioFinal.alias_interno)
        .where(UsuarioFinal.id.in_(uf_ids))
    )).all()) if uf_ids else {}
    # Todos los intentos de la sesión, del más reciente al más antiguo: el
    # primero que veo de cada persona es su último intento.
    intentos = (await db.execute(
        select(Intento).where(Intento.sesion_id == sesion_id)
        .order_by(Intento.timestamp_inicio.desc())
    )).scalars().all()
    ultimo_por_uf: dict[str, Intento] = {}
    for it in intentos:
        ultimo_por_uf.setdefault(it.usuario_final_id, it)
    ej_ids = {it.ejercicio_id for it in ultimo_por_uf.values()}
    nombres_ej = dict((await db.execute(
        select(EjercicioCatalogo.id, EjercicioCatalogo.nombre)
        .where(EjercicioCatalogo.id.in_(ej_ids))
    )).all()) if ej_ids else {}

    fichas: list[FichaViva] = []
    for p in parts:
        ultimo = ultimo_por_uf.get(p.usuario_final_id)

        ejercicio_actual = None
        ultimo_estado = None
        segundos = None
        atascado = False
        if ultimo is not None:
            ejercicio_actual = nombres_ej.get(ultimo.ejercicio_id)
            ultimo_estado = ultimo.estado
            ref = ultimo.timestamp_fin or ultimo.timestamp_inicio
            if ref is not None:
                if ref.tzinfo is None:
                    ref = ref.replace(tzinfo=timezone.utc)
                segundos = (ahora - ref).total_seconds()
                atascado = (not ses.cerrada) and segundos >= SEGUNDOS_ATASCADO

        # En curso: si el kiosco reportó la actividad actual y no ha terminado,
        # eso es lo que la maestra debe ver (no el último intento enviado).
        en_curso = (not p.terminado) and p.actividad_actual is not None
        fichas.append(FichaViva(
            usuario_final_id=p.usuario_final_id,
            alias_interno=alias.get(p.usuario_final_id, "?"),
            ejercicio_actual=p.actividad_actual if en_curso else ejercicio_actual,
            ultimo_estado=ultimo_estado,
            ultimo_intento_id=ultimo.id if ultimo is not None else None,
            segundos_desde_ultimo_intento=segundos,
            atascado=atascado,
            terminado=p.terminado,
            ronda=p.ronda,
            actividad_actual=p.actividad_actual,
            pos_actual=p.pos_actual,
            total_actual=p.total_actual,
        ))

    return LiveOut(sesion_id=sesion_id, tipo=ses.tipo, fichas=fichas)
