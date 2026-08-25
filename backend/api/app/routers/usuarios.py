"""Gestión de usuarios finales (personas mayores, pseudonimizados)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import auditar, get_current_staff, usuario_del_centro
from app.models import (
    ROLES_OTORGANTE,
    Consentimiento,
    DatosIdentificativos,
    PlanPacienteLinea,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)

# Plan por defecto al dar de alta a una persona: una sesión ~20 actividades
# repartidas por 7 áreas (una sesión de mayores dura ~30 min, con la maestra
# guiando cada una). Incluye praxias (el TRAZO, que da nombre a la app). Nivel
# bajo de arranque (suave y digno); la responsable lo ajusta en el planificador.
# Total = 3×6 + 2 = 20. n por área ≤ actividades disponibles (no repite).
# Así su tablet NUNCA aparece vacía (evita el callejón sin salida del mayor).
_PLAN_POR_DEFECTO = (
    ("atencion_memoria", 3),
    ("lenguaje", 3),
    ("razonamiento", 3),
    ("calculo", 3),
    ("funcion_ejecutiva", 3),
    ("vida_cotidiana", 3),
    ("praxias", 2),
)
from app.schemas import (
    ConsentimientoIn,
    ConsentimientoOut,
    UsuarioFinalIn,
    UsuarioFinalOut,
    UsuarioFinalUpdate,
)

router = APIRouter(tags=["usuarios"])


@router.get("/centros/{centro_id}/usuarios", response_model=list[UsuarioFinalOut])
async def listar_usuarios_centro(
    centro_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    if staff.centro_id != centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    usuarios = (
        await db.execute(
            select(UsuarioFinal).where(
                UsuarioFinal.centro_id == centro_id, UsuarioFinal.activo.is_(True)
            )
        )
    ).scalars().all()
    await auditar(db, staff, "listar_usuarios", detalle=f"centro={centro_id}")
    await db.commit()
    return usuarios


@router.post("/usuarios", response_model=UsuarioFinalOut, status_code=status.HTTP_201_CREATED)
async def crear_usuario(
    body: UsuarioFinalIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    uf = UsuarioFinal(
        centro_id=staff.centro_id,
        alias_interno=body.alias_interno,
        nivel_base_json=body.nivel_base_json,
    )
    db.add(uf)
    await db.flush()

    # Plan por defecto (suave) para que la tablet no aparezca vacía si aún no se ha
    # planificado. La responsable lo ajusta en el planificador cuando quiera.
    for orden, (bloque, n) in enumerate(_PLAN_POR_DEFECTO):
        db.add(PlanPacienteLinea(
            usuario_final_id=uf.id, tipo="dominio", bloque=bloque,
            nivel="bajo", n_por_sesion=n, orden=orden, activo=True))

    # El nombre real, si viene, va a la tabla separada de acceso restringido.
    if body.nombre_real:
        db.add(DatosIdentificativos(usuario_final_id=uf.id, nombre_real=body.nombre_real))

    await auditar(db, staff, "crear_usuario", usuario_final_id=uf.id)
    await db.commit()
    await db.refresh(uf)
    return uf


@router.patch("/usuarios/{usuario_id}", response_model=UsuarioFinalOut)
async def editar_usuario(
    usuario_id: str,
    body: UsuarioFinalUpdate,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Edita el alias y/o el nivel base de un usuario del centro (autonomía de la
    integradora: corregir un nombre mal puesto, ajustar el nivel de partida)."""
    uf = await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    if body.alias_interno is not None:
        alias = body.alias_interno.strip()
        if not alias:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                                "El alias no puede quedar vacío")
        uf.alias_interno = alias
    if body.nivel_base_json is not None:
        uf.nivel_base_json = body.nivel_base_json
    # RGPD art. 16: rectificar/vaciar el nombre real en su tabla separada.
    if body.nombre_real is not None:
        di = (await db.execute(
            select(DatosIdentificativos)
            .where(DatosIdentificativos.usuario_final_id == uf.id)
        )).scalars().first()
        nombre = body.nombre_real.strip()
        if nombre:
            if di is None:
                db.add(DatosIdentificativos(usuario_final_id=uf.id, nombre_real=nombre))
            else:
                di.nombre_real = nombre
        elif di is not None:
            await db.delete(di)  # vaciar = borrar el dato identificativo
    await auditar(db, staff, "editar_usuario", usuario_final_id=uf.id)
    await db.commit()
    await db.refresh(uf)
    return uf


@router.delete("/usuarios/{usuario_id}", status_code=status.HTTP_204_NO_CONTENT)
async def suprimir_usuario(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """RGPD art. 17 (derecho de supresión): ANONIMIZA a la persona. Borra sus datos
    identificativos (nombre real) y consentimientos, la saca de las salas y
    pseudonimiza su alias. El histórico de intentos se conserva ya SIN vínculo con
    su identidad (interés legítimo: estadística clínica), y queda traza de la
    supresión en auditoría. Solo el admin del centro puede hacerlo."""
    if staff.rol != "admin_centro":
        raise HTTPException(status.HTTP_403_FORBIDDEN,
                            "Solo la administración del centro puede suprimir una persona")
    uf = await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR

    # 1) Borrar el nombre real (único dato identificativo directo).
    for di in (await db.execute(
        select(DatosIdentificativos)
        .where(DatosIdentificativos.usuario_final_id == uf.id)
    )).scalars().all():
        await db.delete(di)
    # 2) Borrar los consentimientos (contienen nombre del otorgante).
    for cons in (await db.execute(
        select(Consentimiento).where(Consentimiento.usuario_final_id == uf.id)
    )).scalars().all():
        await db.delete(cons)
    # 3) Sacarla de cualquier sala y pseudonimizar el alias.
    for pid in (await db.execute(
        select(SesionParticipante.id)
        .where(SesionParticipante.usuario_final_id == uf.id)
    )).scalars().all():
        obj = await db.get(SesionParticipante, pid)
        if obj is not None and obj.sesion_id:
            ses = await db.get(Sesion, obj.sesion_id)
            if ses is not None and not ses.iniciada:
                await db.delete(obj)  # de salas no iniciadas se saca por completo
    uf.alias_interno = "Persona suprimida"
    uf.activo = False
    await auditar(db, staff, "supresion_rgpd", usuario_final_id=uf.id,
                  detalle="anonimizada: borrados datos identificativos y consentimientos")
    await db.commit()
    return None


@router.post("/usuarios/{usuario_id}/baja", response_model=UsuarioFinalOut)
async def dar_de_baja_usuario(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Da de baja a un usuario (activo=False): desaparece del listado y de las
    salas, pero se conserva su histórico. La integradora gestiona sus plazas."""
    uf = await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    uf.activo = False
    # Sacarlo solo de las salas AÚN NO INICIADAS (programadas o recién abiertas):
    # no debe aparecer para trabajar. Las sesiones ya iniciadas o cerradas se
    # conservan intactas para no perder el trabajo ya hecho de ese día.
    part_ids = (await db.execute(
        select(SesionParticipante.id)
        .join(Sesion, Sesion.id == SesionParticipante.sesion_id)
        .where(SesionParticipante.usuario_final_id == uf.id,
               Sesion.iniciada.is_(False),
               Sesion.cerrada.is_(False))
    )).scalars().all()
    for pid in part_ids:
        obj = await db.get(SesionParticipante, pid)
        if obj is not None:
            await db.delete(obj)
    await auditar(db, staff, "baja_usuario", usuario_final_id=uf.id,
                  detalle=f"salas_limpiadas={len(part_ids)}")
    await db.commit()
    await db.refresh(uf)
    return uf


@router.post("/usuarios/{usuario_id}/consentimiento", response_model=ConsentimientoOut,
             status_code=status.HTTP_201_CREATED)
async def registrar_consentimiento(
    usuario_id: str,
    body: ConsentimientoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Deja constancia de que hay consentimiento firmado para esta persona (RGPD).

    `rol_otorgante` distingue si lo otorga la propia persona o su representante/
    tutor (imprescindible con capacidad modificada). `documento_ref` apunta al
    documento físico/escaneado archivado; la app NO guarda el documento."""
    uf = await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    if body.rol_otorgante not in ROLES_OTORGANTE:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"rol_otorgante inválido (usa {', '.join(ROLES_OTORGANTE)})")
    cons = Consentimiento(
        usuario_final_id=uf.id,
        tipo=body.tipo,
        otorgado_por=body.otorgado_por,
        rol_otorgante=body.rol_otorgante,
        documento_ref=body.documento_ref,
    )
    db.add(cons)
    await auditar(db, staff, "registrar_consentimiento", usuario_final_id=uf.id,
                  detalle=f"tipo={body.tipo} rol={body.rol_otorgante}")
    await db.commit()
    await db.refresh(cons)
    return cons


@router.get("/usuarios/{usuario_id}/consentimiento", response_model=list[ConsentimientoOut])
async def listar_consentimientos(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Consentimientos registrados de una persona (para saber si está en regla)."""
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    cons = (await db.execute(
        select(Consentimiento)
        .where(Consentimiento.usuario_final_id == usuario_id)
        .order_by(Consentimiento.fecha.desc())
    )).scalars().all()
    return cons
