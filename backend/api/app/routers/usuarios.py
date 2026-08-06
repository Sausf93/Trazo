"""Gestión de usuarios finales (personas mayores, pseudonimizados)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import auditar, get_current_staff
from app.models import DatosIdentificativos, UsuarioFinal, UsuarioStaff
from app.schemas import UsuarioFinalIn, UsuarioFinalOut

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
