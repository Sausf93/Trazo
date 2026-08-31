"""Catálogo de ejercicios (data-driven) y generación de instancias."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import (
    Acceso,
    acceso_centro,
    require_roles,
    usuario_del_centro_id,
)
from app.models import BLOQUES, EjercicioCatalogo, UsuarioFinal, UsuarioStaff
from app.schemas import EjercicioIn, EjercicioOut, InstanciaOut
from app.templates import get_plantilla, plantilla_existe

router = APIRouter(prefix="/ejercicios", tags=["ejercicios"])


@router.get("", response_model=list[EjercicioOut])
async def listar_ejercicios(
    bloque: str | None = Query(default=None),
    activo: bool | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
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
    nivel: str | None = Query(default=None, description="bajo/medio/alto (banda de cantidad)"),
    db: AsyncSession = Depends(get_db),
    acceso: Acceso = Depends(acceso_centro),
):
    """Genera una tirada concreta del ejercicio (cantidades cambiantes).

    `nivel` (bajo/medio/alto) fija la banda de CANTIDAD de imágenes/objetos
    (básico ~3 · intermedio ~6-8 · alto ~10-12) — es lo que manda la cola de la
    tablet según el plan del paciente. Si no se pasa, se usa el nivel base del
    usuario si hay `usuario_final_id`.
    """
    ej = await db.get(EjercicioCatalogo, ejercicio_id)
    if ej is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ejercicio no encontrado")

    # Prioridad: nivel de dificultad explícito (texto) > nivel base del usuario.
    nivel_efectivo: object | None = nivel if nivel else None
    if usuario_final_id:
        # anti-IDOR: si se pide para un usuario, debe ser del mismo centro.
        uf = await usuario_del_centro_id(db, usuario_final_id, acceso.centro_id)
        if nivel_efectivo is None and uf is not None:
            # nivel específico del ejercicio, o del bloque, si existe.
            nivel_efectivo = (uf.nivel_base_json or {}).get(ejercicio_id) \
                or (uf.nivel_base_json or {}).get(ej.bloque)

    plantilla = get_plantilla(ej.plantilla_tipo)
    try:
        instancia = plantilla.generar(ej.parametros_json or {}, nivel=nivel_efectivo)
    except ValueError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(e))
    except Exception:
        # Parámetros nulos o mal tipados en el catálogo no deben dar un 500 crudo:
        # la actividad está mal formada -> 422 legible (la integradora la revisa).
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Esta actividad no se puede preparar ahora mismo.")

    # El nivel viaja en cantidad_objetivo para que la firma de dificultad segmente
    # por nivel (reinicia el baseline al subir/bajar y evita el falso positivo de
    # declive en plantillas cuyo cantidad_objetivo no lleva un descriptor numérico
    # del nivel, p. ej. conteo_comparacion).
    if nivel_efectivo not in (None, ""):
        instancia.cantidad_objetivo["nivel"] = str(nivel_efectivo)

    return InstanciaOut(
        ejercicio_id=ej.id,
        nombre=ej.nombre,
        bloque=ej.bloque,
        plantilla=instancia.plantilla,
        render=instancia.render,
        cantidad_objetivo=instancia.cantidad_objetivo,
        metricas=instancia.metricas,
    )
