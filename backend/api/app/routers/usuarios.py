"""Gestión de usuarios finales (personas mayores, pseudonimizados)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import auditar, get_current_staff, usuario_del_centro
from app.models import DatosIdentificativos, UsuarioFinal, UsuarioStaff
from app.schemas import UsuarioFinalIn, UsuarioFinalOut, UsuarioFinalUpdate

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
        uf.alias_interno = body.alias_interno
    if body.nivel_base_json is not None:
        uf.nivel_base_json = body.nivel_base_json
    await auditar(db, staff, "editar_usuario", usuario_final_id=uf.id)
    await db.commit()
    await db.refresh(uf)
    return uf


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
    await auditar(db, staff, "baja_usuario", usuario_final_id=uf.id)
    await db.commit()
    await db.refresh(uf)
    return uf
