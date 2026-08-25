"""Plan de trabajo por paciente y cola de ejercicios resuelta.

El plan (líneas por dominio y/o ejercicio) lo monta el profesional en la web
(ver MODELO-OPERATIVO §2). La cola es lo que la tablet pide para cada persona:
la lista ordenada de ejercicios de HOY, ya resuelta desde el plan.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import (
    Acceso,
    acceso_centro,
    auditar,
    get_current_staff,
    usuario_del_centro_id,
)
from app.models import (
    BLOQUES,
    TIPOS_LINEA_PLAN,
    EjercicioCatalogo,
    PlanPacienteLinea,
    Sesion,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import (
    ColaOut,
    ItemCola,
    NivelLineaIn,
    PlanLineaOut,
    PlanPut,
    SugerenciaNivelOut,
)
from app.services.cola import construir_cola
from app.services.sugerencias import NIVELES, sugerencias_para_usuario

router = APIRouter(tags=["planes"])


async def _get_usuario_del_centro(
    db: AsyncSession, usuario_id: str, staff: UsuarioStaff
) -> UsuarioFinal:
    uf = await db.get(UsuarioFinal, usuario_id)
    if uf is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado")
    if uf.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    return uf


@router.get("/usuarios/{usuario_id}/plan", response_model=list[PlanLineaOut])
async def obtener_plan(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await _get_usuario_del_centro(db, usuario_id, staff)
    lineas = (
        await db.execute(
            select(PlanPacienteLinea)
            .where(PlanPacienteLinea.usuario_final_id == usuario_id)
            .order_by(PlanPacienteLinea.orden, PlanPacienteLinea.id)
        )
    ).scalars().all()
    return lineas


@router.put("/usuarios/{usuario_id}/plan", response_model=list[PlanLineaOut])
async def reemplazar_plan(
    usuario_id: str,
    body: PlanPut,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Reemplaza por completo las líneas del plan de la persona."""
    await _get_usuario_del_centro(db, usuario_id, staff)

    # Validación de cada línea.
    for ln in body.lineas:
        if ln.tipo not in TIPOS_LINEA_PLAN:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                                f"tipo de línea inválido: {ln.tipo}")
        if ln.tipo == "dominio":
            if not ln.bloque:
                raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                                    "línea de dominio requiere 'bloque'")
            if ln.bloque not in BLOQUES:
                raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                                    f"bloque inválido: {ln.bloque}")
        if ln.tipo == "ejercicio":
            if not ln.ejercicio_id:
                raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                                    "línea de ejercicio requiere 'ejercicio_id'")
            ej = await db.get(EjercicioCatalogo, ln.ejercicio_id)
            if ej is None:
                raise HTTPException(status.HTTP_404_NOT_FOUND,
                                    f"ejercicio no encontrado: {ln.ejercicio_id}")

    # Borrar las existentes y crear las nuevas.
    existentes = (
        await db.execute(
            select(PlanPacienteLinea).where(
                PlanPacienteLinea.usuario_final_id == usuario_id
            )
        )
    ).scalars().all()
    for e in existentes:
        await db.delete(e)
    await db.flush()

    nuevas: list[PlanPacienteLinea] = []
    for ln in body.lineas:
        linea = PlanPacienteLinea(
            usuario_final_id=usuario_id,
            tipo=ln.tipo,
            bloque=ln.bloque if ln.tipo == "dominio" else None,
            ejercicio_id=ln.ejercicio_id if ln.tipo == "ejercicio" else None,
            nivel=ln.nivel,
            n_por_sesion=ln.n_por_sesion,
            orden=ln.orden,
            activo=ln.activo,
        )
        db.add(linea)
        nuevas.append(linea)

    await auditar(db, staff, "reemplazar_plan", usuario_final_id=usuario_id,
                  detalle=f"n_lineas={len(nuevas)}")
    await db.commit()

    lineas = (
        await db.execute(
            select(PlanPacienteLinea)
            .where(PlanPacienteLinea.usuario_final_id == usuario_id)
            .order_by(PlanPacienteLinea.orden, PlanPacienteLinea.id)
        )
    ).scalars().all()
    return lineas


@router.get("/usuarios/{usuario_id}/cola", response_model=ColaOut)
async def cola_usuario(
    usuario_id: str,
    sesion_id: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """Cola de ejercicios resuelta para la persona (lo que la tablet pide).

    Accesible por login de staff O por token de dispositivo (kiosco). Si se pasa
    `sesion_id` y la sesión es modo grupo, la cola es el ejercicio compartido (a
    su nivel). En otro caso se resuelve desde su plan individual.
    """
    uf = await usuario_del_centro_id(db, usuario_id, acceso.centro_id)
    if not uf.activo:
        raise HTTPException(status.HTTP_409_CONFLICT, "El usuario está dado de baja")

    sesion: Sesion | None = None
    modo = "individual"
    if sesion_id:
        sesion = await db.get(Sesion, sesion_id)
        if sesion is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesión no encontrada")
        if sesion.centro_id != acceso.centro_id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
        modo = sesion.modo

    items_data = await construir_cola(db, usuario_id, sesion)
    items = [ItemCola(**item.__dict__) for item in items_data]
    return ColaOut(usuario_final_id=usuario_id, sesion_id=sesion_id, modo=modo, items=items)


@router.get("/usuarios/{usuario_id}/propuesta", response_model=list[ItemCola])
async def propuesta_sesion(
    usuario_id: str,
    n: int = Query(default=3, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """La app PROPONE las próximas `n` actividades frescas para la persona.

    Salen de su plan con rotación por FRESCURA (lo menos jugado primero) y sin
    repetir ejercicio. La integradora la revisa y decide en el momento: NUNCA se
    aplica sola (mismo principio que las sugerencias de nivel y que `sin_valorar`).
    Se sirve por login de staff O por token de dispositivo (la tablet la ofrece).
    """
    uf = await usuario_del_centro_id(db, usuario_id, acceso.centro_id)
    if not uf.activo:
        raise HTTPException(status.HTTP_409_CONFLICT, "El usuario está dado de baja")
    items_data = await construir_cola(db, usuario_id, None)
    vistos: set[str] = set()
    salida: list[ItemCola] = []
    for it in items_data:
        if it.ejercicio_id in vistos:
            continue
        vistos.add(it.ejercicio_id)
        salida.append(ItemCola(**it.__dict__))
        if len(salida) >= n:
            break
    return salida


@router.get("/usuarios/{usuario_id}/sugerencias", response_model=list[SugerenciaNivelOut])
async def sugerencias_nivel(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Propuestas de subir/bajar nivel (el profesional las aprueba). Nunca automático."""
    await _get_usuario_del_centro(db, usuario_id, staff)
    sugs = await sugerencias_para_usuario(db, usuario_id)
    return [SugerenciaNivelOut(**s.__dict__) for s in sugs]


@router.patch("/planes/lineas/{linea_id}/nivel", response_model=PlanLineaOut)
async def cambiar_nivel_linea(
    linea_id: str,
    body: NivelLineaIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Aprobar/aplicar un cambio de nivel en una línea del plan."""
    linea = await db.get(PlanPacienteLinea, linea_id)
    if linea is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Línea de plan no encontrada")
    uf = await db.get(UsuarioFinal, linea.usuario_final_id)
    if uf is None or uf.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    if body.nivel not in NIVELES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"nivel inválido: {body.nivel} (usa {NIVELES})")
    linea.nivel = body.nivel
    await auditar(db, staff, "cambiar_nivel_plan",
                  usuario_final_id=linea.usuario_final_id,
                  detalle=f"linea={linea_id} nivel={body.nivel}")
    await db.commit()
    await db.refresh(linea)
    return linea
