"""Catálogo de ejercicios (data-driven) y generación de instancias."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_staff, require_roles
from app.models import BLOQUES, EjercicioCatalogo, UsuarioFinal, UsuarioStaff
from app.schemas import EjercicioIn, EjercicioOut, InstanciaOut
from app.templates import get_plantilla, plantilla_existe

router = APIRouter(prefix="/ejercicios", tags=["ejercicios"])


@router.get("", response_model=list[EjercicioOut])
async def listar_ejercicios(
    bloque: str | None = Query(default=None),
    activo: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    stmt = select(EjercicioCatalogo)
    if bloque:
        stmt = stmt.where(EjercicioCatalogo.bloque == bloque)
    if activo is not None:
        stmt = stmt.where(EjercicioCatalogo.activo.is_(activo))
    return (await db.execute(stmt.order_by(EjercicioCatalogo.bloque))).scalars().all()


@router.post("", response_model=EjercicioOut, status_code=status.HTTP_201_CREATED)
async def crear_ejercicio(
    body: EjercicioIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    if body.bloque not in BLOQUES:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, f"Bloque inválido: {body.bloque}")
    if not plantilla_existe(body.plantilla_tipo):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"Plantilla inválida: {body.plantilla_tipo}")
    ej = EjercicioCatalogo(**body.model_dump())
    db.add(ej)
    await db.commit()
    await db.refresh(ej)
    return ej


@router.get("/{ejercicio_id}/instancia", response_model=InstanciaOut)
async def generar_instancia(
    ejercicio_id: str,
    usuario_final_id: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Genera una tirada concreta del ejercicio (cantidades cambiantes).

    Si se pasa `usuario_final_id`, ajusta la dificultad a su nivel base.
    """
    ej = await db.get(EjercicioCatalogo, ejercicio_id)
    if ej is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ejercicio no encontrado")

    nivel = None
    if usuario_final_id:
        uf = await db.get(UsuarioFinal, usuario_final_id)
        if uf is not None:
            # nivel específico del ejercicio, o del bloque, si existe.
            nivel = (uf.nivel_base_json or {}).get(ejercicio_id) \
                or (uf.nivel_base_json or {}).get(ej.bloque)

    plantilla = get_plantilla(ej.plantilla_tipo)
    try:
        instancia = plantilla.generar(ej.parametros_json or {}, nivel=nivel)
    except ValueError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(e))

    return InstanciaOut(
        ejercicio_id=ej.id,
        nombre=ej.nombre,
        bloque=ej.bloque,
        plantilla=instancia.plantilla,
        render=instancia.render,
        cantidad_objetivo=instancia.cantidad_objetivo,
        metricas=instancia.metricas,
    )
