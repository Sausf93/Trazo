"""Objetivos/metas clínicas por paciente (plan de intervención).

La integradora fija, por ÁREA (bloque), un desempeño objetivo a alcanzar o
mantener; el panel muestra 'objetivo vs situación actual'. Diferenciador frente a
un catálogo de ejercicios: convierte Trazo en un plan de intervención medible.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import auditar, get_current_staff, usuario_del_centro
from app.models import (
    BLOQUES,
    EjercicioCatalogo,
    Intento,
    ObjetivoPaciente,
    UsuarioStaff,
)
from app.schemas import ObjetivoIn, ObjetivoOut, ObjetivoUpdate
from app.services.anomalias import rendimiento_resultado

router = APIRouter(tags=["objetivos"])


async def _situacion(db: AsyncSession, usuario_id: str, bloque: str) -> tuple[float | None, int]:
    """Media de desempeño (0..1) del área para esa persona, y nº de valorados.
    Excluye 'sin_valorar' (aún no cuentan), coherente con evolución/alertas."""
    filas = (await db.execute(
        select(Intento.resultado)
        .join(EjercicioCatalogo, EjercicioCatalogo.id == Intento.ejercicio_id)
        .where(Intento.usuario_final_id == usuario_id,
               EjercicioCatalogo.bloque == bloque,
               Intento.resultado != "sin_valorar")
    )).scalars().all()
    if not filas:
        return None, 0
    media = sum(rendimiento_resultado(r) for r in filas) / len(filas)
    return round(media, 4), len(filas)


async def _to_out(db: AsyncSession, obj: ObjetivoPaciente) -> ObjetivoOut:
    actual, n = await _situacion(db, obj.usuario_final_id, obj.bloque)
    return ObjetivoOut(
        id=obj.id, usuario_final_id=obj.usuario_final_id, bloque=obj.bloque,
        descripcion=obj.descripcion, objetivo_desempeno=obj.objetivo_desempeno,
        activo=obj.activo, creado_en=obj.creado_en,
        situacion_actual=actual, n_valorados=n,
        cumple=(actual >= obj.objetivo_desempeno) if actual is not None else None,
    )


@router.get("/usuarios/{usuario_id}/objetivos", response_model=list[ObjetivoOut])
async def listar_objetivos(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    objs = (await db.execute(
        select(ObjetivoPaciente)
        .where(ObjetivoPaciente.usuario_final_id == usuario_id)
        .order_by(ObjetivoPaciente.creado_en.desc())
    )).scalars().all()
    return [await _to_out(db, o) for o in objs]


@router.post("/usuarios/{usuario_id}/objetivos", response_model=ObjetivoOut,
             status_code=status.HTTP_201_CREATED)
async def crear_objetivo(
    usuario_id: str,
    body: ObjetivoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR
    if body.bloque not in BLOQUES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"área inválida (usa una de {', '.join(BLOQUES)})")
    if not 0.0 <= body.objetivo_desempeno <= 1.0:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            "el objetivo de desempeño debe estar entre 0 y 1")
    # Un solo objetivo ACTIVO por área (la situación actual es del área, no del
    # objetivo: dos metas en la misma área mostrarían el mismo 'va por').
    ya = (await db.execute(
        select(ObjetivoPaciente).where(
            ObjetivoPaciente.usuario_final_id == usuario_id,
            ObjetivoPaciente.bloque == body.bloque,
            ObjetivoPaciente.activo.is_(True),
        )
    )).scalars().first()
    if ya is not None:
        raise HTTPException(status.HTTP_409_CONFLICT,
                            "Ya hay un objetivo activo en esta área; edítalo en vez de crear otro")
    obj = ObjetivoPaciente(
        usuario_final_id=usuario_id, bloque=body.bloque,
        descripcion=(body.descripcion or "").strip() or None,
        objetivo_desempeno=body.objetivo_desempeno, creado_por=staff.id,
    )
    db.add(obj)
    await auditar(db, staff, "crear_objetivo", usuario_final_id=usuario_id,
                  detalle=f"area={body.bloque} objetivo={body.objetivo_desempeno}")
    await db.commit()
    await db.refresh(obj)
    return await _to_out(db, obj)


async def _obj_del_centro(db, objetivo_id, staff) -> ObjetivoPaciente:
    obj = await db.get(ObjetivoPaciente, objetivo_id)
    if obj is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Objetivo no encontrado")
    await usuario_del_centro(db, obj.usuario_final_id, staff)  # anti-IDOR (403)
    return obj


@router.patch("/objetivos/{objetivo_id}", response_model=ObjetivoOut)
async def editar_objetivo(
    objetivo_id: str,
    body: ObjetivoUpdate,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    obj = await _obj_del_centro(db, objetivo_id, staff)
    if body.descripcion is not None:
        obj.descripcion = body.descripcion.strip() or None
    if body.objetivo_desempeno is not None:
        if not 0.0 <= body.objetivo_desempeno <= 1.0:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                                "el objetivo de desempeño debe estar entre 0 y 1")
        obj.objetivo_desempeno = body.objetivo_desempeno
    if body.activo is not None:
        obj.activo = body.activo
    await db.commit()
    await db.refresh(obj)
    return await _to_out(db, obj)


@router.delete("/objetivos/{objetivo_id}", status_code=status.HTTP_204_NO_CONTENT)
async def borrar_objetivo(
    objetivo_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    obj = await _obj_del_centro(db, objetivo_id, staff)
    await db.delete(obj)
    await db.commit()
    return None
