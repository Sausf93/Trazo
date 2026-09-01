"""Sesiones (individual/grupo) y vista en vivo para la facilitadora."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import Acceso, acceso_centro, get_current_staff, usuario_del_centro
from app.models import (
    Consentimiento,
    DocumentoLegal,
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
    IntentoRevisionOut,
    LineaConfig,
    LiveOut,
    NotaSesionIn,
    ParticipanteEstadoOut,
    ParticipanteMasIn,
    ParticipanteProgramadoOut,
    ParticipanteSesion,
    ResumenParticipante,
    ResumenSesionOut,
    SalaActiva,
    SesionActivaOut,
    SesionConfigPut,
    SesionIn,
    SesionOut,
    SesionProgramadaOut,
    SesionResumenOut,
)

router = APIRouter(prefix="/sesiones", tags=["sesiones"])

# Umbral de "atascado" (desde que empezó la actividad EN CURSO). 30s era muy
# poco para el público objetivo: leer un reloj, componer un importe moneda a
# moneda o memorizar (memoria tiene 60s de memorización) lleva su tiempo.
SEGUNDOS_ATASCADO = 90.0
# Una sala abierta más antigua que esto se considera "zombi" y ya no se sirve a
# los kioscos (la maestra no la cerró; evita actividades sin supervisión).
_HORAS_SALA_VIVA = 12


def _config_json(
    nivel: str | None,
    lineas: list[LineaConfig],
    ejercicios: list[str] | None = None,
) -> dict | None:
    """Normaliza la config por participante ({nivel, lineas, ejercicios}) o None.

    - `lineas` = bloques (dominio) para la sesión.
    - `ejercicios` = actividades CONCRETAS elegidas en vivo por la integradora (o
      una propuesta de la app aceptada); van primero en la cola.

    Requiere al menos una línea O un ejercicio concreto: una config con SOLO nivel
    dejaría la cola vacía (la rama de config no cae al plan), así que en ese caso
    devolvemos None para que el participante use su plan permanente.
    """
    ejercicios = [e for e in (ejercicios or []) if e]
    if not lineas and not ejercicios:
        return None
    cfg: dict = {
        "nivel": nivel,
        "lineas": [{"bloque": ln.bloque, "n": ln.n} for ln in lineas],
    }
    if ejercicios:
        cfg["ejercicios"] = [{"ejercicio_id": e, "nivel": nivel} for e in ejercicios]
    return cfg


@router.get("/activa", response_model=SesionActivaOut)
async def sesion_activa(
    centro_id: str,
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """Salas abiertas del centro (puede haber varias) + sus participantes.

    Es lo que consulta la tablet participante (kiosco): si hay una sola sala va
    directa a "¿quién eres?"; si hay varias (2 maestras, 2 grupos) muestra las
    salas para que cada persona sepa a qué actividad unirse. Accesible por login
    de staff O por token de dispositivo. `salas` vacío si no hay ninguna.
    """
    if centro_id != acceso.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    # Solo salas RECIENTES: una sala que quedó "abierta" de un día anterior (la
    # maestra no la cerró) no debe seguir sirviendo actividades sin supervisión.
    limite = datetime.now(timezone.utc) - timedelta(hours=_HORAS_SALA_VIVA)
    sesiones = (
        await db.execute(
            select(Sesion)
            .where(
                Sesion.centro_id == centro_id,
                Sesion.cerrada.is_(False),
                Sesion.abierta.is_(True),
                Sesion.fecha >= limite,
            )
            .order_by(Sesion.fecha.desc())
        )
    ).scalars().all()
    if not sesiones:
        return SesionActivaOut()

    # Participantes + alias de TODAS las salas en UNA consulta (sin N+1): el
    # kiosco hace polling, así que evitar el bucle de gets importa.
    ids = [s.id for s in sesiones]
    filas = (await db.execute(
        select(SesionParticipante.sesion_id,
               SesionParticipante.usuario_final_id, UsuarioFinal.alias_interno)
        .join(UsuarioFinal, UsuarioFinal.id == SesionParticipante.usuario_final_id)
        .where(SesionParticipante.sesion_id.in_(ids))
    )).all()
    por_sala: dict[str, list[ParticipanteSesion]] = {i: [] for i in ids}
    for sid, uid, alias in filas:
        por_sala[sid].append(
            ParticipanteSesion(usuario_final_id=uid, alias_interno=alias))
    # Nombre de la responsable (maestra) de cada sala, para distinguir salas con
    # el mismo texto cuando hay varias abiertas. Una sola consulta.
    staff_ids = {s.staff_id for s in sesiones}
    responsables = dict((await db.execute(
        select(UsuarioStaff.id, UsuarioStaff.nombre)
        .where(UsuarioStaff.id.in_(staff_ids))
    )).all())
    salas = [
        SalaActiva(
            sesion_id=s.id, nombre=s.nombre, modo=s.modo, iniciada=s.iniciada,
            responsable=responsables.get(s.staff_id),
            ejercicio_compartido_id=s.ejercicio_compartido_id,
            participantes=por_sala.get(s.id, []),
        )
        for s in sesiones
    ]
    primera = salas[0]
    return SesionActivaOut(
        sesion_id=primera.sesion_id, nombre=primera.nombre, modo=primera.modo,
        iniciada=primera.iniciada,
        ejercicio_compartido_id=primera.ejercicio_compartido_id,
        participantes=primera.participantes,
        salas=salas,
    )


@router.get("/mia-abierta", response_model=SesionActivaOut)
async def mi_sala_abierta(
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """La sala abierta reciente que abrió ESTA maestra (no la de otra compañera).

    La usa la pantalla de la maestra al refrescar/reabrir para recuperar SU
    monitor: con varias salas por centro, no vale coger 'la más reciente' porque
    podría ser la de otra facilitadora."""
    limite = datetime.now(timezone.utc) - timedelta(hours=_HORAS_SALA_VIVA)
    ses = (
        await db.execute(
            select(Sesion)
            .where(
                Sesion.centro_id == staff.centro_id,
                Sesion.staff_id == staff.id,
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
    return SesionActivaOut(
        sesion_id=ses.id, nombre=ses.nombre, modo=ses.modo,
        iniciada=ses.iniciada,
        ejercicio_compartido_id=ses.ejercicio_compartido_id,
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
    """Cómo fue la sesión: por participante, cuántas actividades y el desglose por
    RESULTADO (logrado/parcial/no_logrado/sin_valorar) + cuántas con ayuda. Para
    el cierre con resumen y el historial."""
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
    # Desglose por RESULTADO autocorregido por participante (sin N+1).
    filas = (await db.execute(
        select(Intento.usuario_final_id, Intento.resultado, func.count())
        .where(Intento.sesion_id == sesion_id)
        .group_by(Intento.usuario_final_id, Intento.resultado)
    )).all()
    por_usuario: dict[str, dict[str, int]] = {}
    for uf_id, resultado, n in filas:
        por_usuario.setdefault(uf_id, {})[resultado] = n
    # Cuántas actividades fueron CON AYUDA por participante (capa secundaria).
    filas_ayuda = (await db.execute(
        select(Intento.usuario_final_id, func.count())
        .where(Intento.sesion_id == sesion_id, Intento.con_ayuda.is_(True))
        .group_by(Intento.usuario_final_id)
    )).all()
    ayuda_por_usuario = {uf_id: n for uf_id, n in filas_ayuda}

    fichas: list[ResumenParticipante] = []
    for p in parts:
        est = por_usuario.get(p.usuario_final_id, {})
        logrado = est.get("logrado", 0)
        parcial = est.get("parcial", 0)
        no_logrado = est.get("no_logrado", 0)
        sin_valorar = est.get("sin_valorar", 0)
        fichas.append(ResumenParticipante(
            usuario_final_id=p.usuario_final_id,
            alias_interno=alias.get(p.usuario_final_id, "?"),
            n_intentos=logrado + parcial + no_logrado,
            logrado=logrado,
            parcial=parcial,
            no_logrado=no_logrado,
            sin_valorar=sin_valorar,
            con_ayuda=ayuda_por_usuario.get(p.usuario_final_id, 0),
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
    # Se DEDUPLICA (preservando orden): si el cliente manda la misma persona dos
    # veces (doble selección), un segundo INSERT violaría uq_sesion_usuario y
    # daría un 500 crudo justo al abrir la sala delante de la maestra.
    participantes = list(dict.fromkeys(body.participantes))
    await _validar_participantes(db, participantes, staff)
    # Compuerta legal (RGPD): datos de salud. No se abre una sesión real sin el
    # contrato de encargo (DPA) del centro y el consentimiento de cada persona.
    await _exigir_consentimiento_y_dpa(db, staff.centro_id, participantes)
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
    # Un centro puede tener VARIAS salas en vivo a la vez (p.ej. 2 maestras, 2
    # grupos). Lo único que no vale es que una misma persona esté en dos salas
    # abiertas: en el kiosco aparecería en dos sitios y su medición se bifurcaría.
    if ses.abierta:
        await _rechazar_si_en_otra_sala(db, staff.centro_id, participantes)
    db.add(ses)
    await db.flush()
    # Config por participante (la maestra fija nivel/categorías/nº para la sesión).
    configs = {c.usuario_final_id: c for c in body.configs}
    for uf_id in participantes:
        cfg = configs.get(uf_id)
        config_json = _config_json(cfg.nivel, cfg.lineas) if cfg is not None else None
        db.add(SesionParticipante(
            sesion_id=ses.id, usuario_final_id=uf_id, config_json=config_json,
        ))
    await db.commit()
    await db.refresh(ses)
    return ses


async def _rechazar_si_en_otra_sala(
    db: AsyncSession, centro_id: str, participantes: list[str],
    excepto_id: str | None = None,
) -> None:
    """Una persona no puede estar en dos salas abiertas del mismo centro a la vez.

    Antes había un invariante de 'una sola sala por centro' que cerraba las demás;
    ahora se permiten varias salas simultáneas (2 maestras, 2 grupos) y el kiosco
    muestra todas. El único conflicto real es que la MISMA persona aparezca en dos
    salas: se rechaza con 409 indicando en cuál está ya."""
    if not participantes:
        return
    # Solo salas VIVAS (misma ventana de frescura que el kiosco): una sala zombi
    # de un día anterior no debe bloquear abrir una nueva hoy con esa persona.
    limite = datetime.now(timezone.utc) - timedelta(hours=_HORAS_SALA_VIVA)
    stmt = (
        select(UsuarioFinal.alias_interno, Sesion.nombre)
        .join(SesionParticipante,
              SesionParticipante.usuario_final_id == UsuarioFinal.id)
        .join(Sesion, Sesion.id == SesionParticipante.sesion_id)
        .where(
            Sesion.centro_id == centro_id,
            Sesion.cerrada.is_(False),
            Sesion.abierta.is_(True),
            Sesion.fecha >= limite,
            SesionParticipante.usuario_final_id.in_(participantes),
        )
    )
    if excepto_id is not None:
        stmt = stmt.where(Sesion.id != excepto_id)
    fila = (await db.execute(stmt)).first()
    if fila is not None:
        alias, sala = fila
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"{alias} ya está en otra sala abierta ({sala or 'sin nombre'}). "
            f"Ciérrala o quítalo de allí antes de ponerlo en esta.",
        )


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
        if not uf.activo:
            raise HTTPException(status.HTTP_409_CONFLICT,
                                f"El participante {uf.alias_interno} está dado de baja")


async def _exigir_consentimiento_y_dpa(
    db: AsyncSession, centro_id: str, participantes: list[str]
) -> None:
    """Compuerta legal (RGPD, datos de salud): una persona no entra en una sesión
    REAL hasta que su tratamiento está legitimado. Exige DOS cosas:

    1. Que el CENTRO tenga su **contrato de encargo (DPA)** firmado y archivado
       (art. 28 RGPD): sin él, Trazo no puede tratar datos por cuenta del centro.
    2. Que CADA participante tenga su **consentimiento** registrado: una persona
       "está de alta de verdad" cuando consta su consentimiento (o el de su
       representante), no solo cuando se teclea su alias.

    El demo/vitrina NO pasa por aquí (usa `GaleriaScreen`, sin sesiones de
    backend). El mensaje dirige a la maestra a dónde subir cada documento."""
    # (1) Contrato de encargo (DPA) del centro.
    tiene_dpa = (await db.execute(
        select(DocumentoLegal.id).where(
            DocumentoLegal.centro_id == centro_id,
            DocumentoLegal.tipo == "dpa",
        ).limit(1)
    )).first()
    if tiene_dpa is None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "El centro todavía no tiene el contrato de encargo (DPA) firmado. "
            "Súbelo en «Cumplimiento» antes de abrir sesiones con personas reales.",
        )
    # (2) Consentimiento de cada participante.
    if not participantes:
        return
    con_consent = set((await db.execute(
        select(Consentimiento.usuario_final_id)
        .where(Consentimiento.usuario_final_id.in_(participantes))
    )).scalars().all())
    faltan = [p for p in participantes if p not in con_consent]
    if faltan:
        filas = (await db.execute(
            select(UsuarioFinal.alias_interno).where(UsuarioFinal.id.in_(faltan))
        )).scalars().all()
        nombres = ", ".join(filas) if filas else "algún participante"
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Falta registrar el consentimiento de: {nombres}. "
            "Regístralo en la ficha de cada persona antes de ponerla en una sesión.",
        )


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
    # Varias salas por centro conviven; solo se impide que una misma persona
    # quede en dos salas abiertas a la vez.
    parts = (await db.execute(
        select(SesionParticipante.usuario_final_id)
        .where(SesionParticipante.sesion_id == ses.id)
    )).scalars().all()
    await _rechazar_si_en_otra_sala(db, ses.centro_id, list(parts), excepto_id=ses.id)
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
    participantes = list(dict.fromkeys(body.participantes))
    await _validar_participantes(db, participantes, staff)
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
    for uf_id in participantes:
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
    sp.actividad_actual_en = None
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
    # Marca el inicio de la actividad SOLO cuando cambia (un re-reporte de la
    # misma no debe reiniciar el reloj de "atascado").
    if sp.actividad_actual != body.actividad or sp.actividad_actual_en is None:
        sp.actividad_actual_en = datetime.now(timezone.utc)
    sp.actividad_actual = body.actividad
    sp.pos_actual = body.pos
    sp.total_actual = body.total
    await db.commit()


@router.get("/{sesion_id}/participantes/{usuario_id}/intentos",
            response_model=list[IntentoRevisionOut])
async def ultimos_intentos_participante(
    sesion_id: str,
    usuario_id: str,
    limit: int = 4,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Los últimos intentos de una persona en la sesión, para que la integradora
    marque la ayuda o resuelva la revisión de VARIAS de golpe (no solo la última)."""
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    filas = (await db.execute(
        select(Intento, EjercicioCatalogo.nombre)
        .join(EjercicioCatalogo, EjercicioCatalogo.id == Intento.ejercicio_id)
        .where(Intento.sesion_id == sesion_id,
               Intento.usuario_final_id == usuario_id)
        .order_by(Intento.timestamp_inicio.desc())
        .limit(max(1, min(limit, 10)))
    )).all()
    return [
        IntentoRevisionOut(
            id=i.id, ejercicio=nombre, resultado=i.resultado,
            con_ayuda=i.con_ayuda, cuando=i.timestamp_inicio,
        )
        for i, nombre in filas
    ]


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
    if body is not None and (body.lineas or body.ejercicios):
        sp.config_json = _config_json(body.nivel, body.lineas, body.ejercicios)
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
        ultimo_con_ayuda = False
        segundos = None
        atascado = False
        ref = None
        if ultimo is not None:
            ejercicio_actual = nombres_ej.get(ultimo.ejercicio_id)
            ultimo_estado = ultimo.resultado  # resultado autocorregido
            ultimo_con_ayuda = ultimo.con_ayuda
            ref = ultimo.timestamp_fin or ultimo.timestamp_inicio
            if ref is not None and ref.tzinfo is None:
                ref = ref.replace(tzinfo=timezone.utc)

        # En curso: si el kiosco reportó la actividad actual y no ha terminado,
        # eso es lo que la maestra debe ver (no el último intento enviado).
        en_curso = (not p.terminado) and p.actividad_actual is not None

        # "Atascado" se mide desde el inicio de la actividad EN CURSO (no desde el
        # último intento enviado, que daba falsas alarmas en actividades largas).
        inicio_actual = p.actividad_actual_en if en_curso else None
        if inicio_actual is not None and inicio_actual.tzinfo is None:
            inicio_actual = inicio_actual.replace(tzinfo=timezone.utc)
        ref_atascado = inicio_actual or ref
        if ref_atascado is not None:
            segundos = (ahora - ref_atascado).total_seconds()
            # Quien ya TERMINÓ su tanda y espera al grupo NO está atascado (si no,
            # el panel lo pintaba en rojo a los 90s de acabar).
            atascado = (
                (not ses.cerrada)
                and (not p.terminado)
                and segundos >= SEGUNDOS_ATASCADO
            )
        fichas.append(FichaViva(
            usuario_final_id=p.usuario_final_id,
            alias_interno=alias.get(p.usuario_final_id, "?"),
            ejercicio_actual=p.actividad_actual if en_curso else ejercicio_actual,
            ultimo_estado=ultimo_estado,
            ultimo_con_ayuda=ultimo_con_ayuda,
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
