"""Puesta en marcha: estado real de la implantación de un centro, para que el
asistente del panel guíe a los trabajadores paso a paso (sin que Saulo esté).

Devuelve, leyendo el estado REAL, qué pasos están hechos y cuáles faltan:
equipo, tablets, DPA, personas + consentimientos, suscripción y primera sesión.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_staff
from app.models import (
    Centro,
    Consentimiento,
    Dispositivo,
    DocumentoLegal,
    Sesion,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import PuestaEnMarchaOut

router = APIRouter(tags=["onboarding"])

# Roles que pueden operar como maestra en la tablet (el admin no aparece allí).
_ROLES_MAESTRA = ("integradora", "psicologa", "terapeuta_ocupacional", "integradora_social")


@router.get("/puesta-en-marcha", response_model=PuestaEnMarchaOut)
async def puesta_en_marcha(
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    cid = staff.centro_id
    centro = await db.get(Centro, cid)

    async def _count(stmt) -> int:
        return int((await db.execute(stmt)).scalar() or 0)

    n_maestras = await _count(
        select(func.count()).select_from(UsuarioStaff).where(
            UsuarioStaff.centro_id == cid,
            UsuarioStaff.activo.is_(True),
            UsuarioStaff.rol.in_(_ROLES_MAESTRA),
        ))
    n_tablets = await _count(
        select(func.count()).select_from(Dispositivo).where(
            Dispositivo.centro_id == cid, Dispositivo.activo.is_(True)))
    tiene_dpa = (await db.execute(
        select(DocumentoLegal.id).where(
            DocumentoLegal.centro_id == cid, DocumentoLegal.tipo == "dpa").limit(1)
    )).first() is not None
    n_personas = await _count(
        select(func.count()).select_from(UsuarioFinal).where(
            UsuarioFinal.centro_id == cid, UsuarioFinal.activo.is_(True)))
    # Personas activas SIN consentimiento registrado.
    ids_personas = select(UsuarioFinal.id).where(
        UsuarioFinal.centro_id == cid, UsuarioFinal.activo.is_(True))
    con_consent = await _count(
        select(func.count(func.distinct(Consentimiento.usuario_final_id))).where(
            Consentimiento.usuario_final_id.in_(ids_personas)))
    sin_consentimiento = max(0, n_personas - con_consent)
    n_sesiones = await _count(
        select(func.count()).select_from(Sesion).where(Sesion.centro_id == cid))

    estado_sub = getattr(centro, "estado_suscripcion", "cortesia") if centro else "cortesia"
    sub_ok = estado_sub in ("activa", "cortesia", "prueba")

    equipo_ok = n_maestras >= 1
    tablets_ok = n_tablets >= 1
    personas_ok = n_personas >= 1 and sin_consentimiento == 0
    completo = (equipo_ok and tablets_ok and tiene_dpa and personas_ok
                and sub_ok and n_sesiones >= 1)

    return PuestaEnMarchaOut(
        equipo_ok=equipo_ok, n_maestras=n_maestras,
        tablets_ok=tablets_ok, n_tablets=n_tablets,
        dpa_ok=tiene_dpa,
        personas_ok=personas_ok, n_personas=n_personas,
        personas_sin_consentimiento=sin_consentimiento,
        suscripcion_ok=sub_ok, estado_suscripcion=estado_sub,
        primera_sesion_ok=n_sesiones >= 1,
        completo=completo,
    )
