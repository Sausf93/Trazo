"""Evolución individual y de grupo."""
from __future__ import annotations

import csv
import io
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import auditar, get_current_staff, usuario_del_centro
from app.models import (
    Alerta,
    DatosIdentificativos,
    EjercicioCatalogo,
    Intento,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.schemas import (
    AlertaOut,
    EvolucionOut,
    PersonaInactiva,
    PuntoEvolucion,
    ResumenAreaOut,
    ResumenUsoOut,
)
from app.services.anomalias import rendimiento_resultado

router = APIRouter(tags=["evolucion"])

_RESULTADO_CSV = {
    "logrado": "Lo logró",
    "parcial": "A medias",
    "no_logrado": "No lo logró",
    "sin_valorar": "Sin valorar",
}


_UMBRAL_BAJO = 0.5  # por debajo de este desempeño medio conviene mirar a la persona


@router.get("/centros/{centro_id}/resumen-areas", response_model=list[ResumenAreaOut])
async def resumen_areas(
    centro_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Panorámica del centro por área: desempeño medio y nº de personas por debajo
    del umbral en cada dominio. Da priorización diaria (a qué área/persona mirar)
    incluso sin que haya saltado una alerta. Ordenado de peor a mejor."""
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    filas = (await db.execute(
        select(Intento.usuario_final_id, EjercicioCatalogo.bloque, Intento.resultado)
        .join(UsuarioFinal, UsuarioFinal.id == Intento.usuario_final_id)
        .join(EjercicioCatalogo, EjercicioCatalogo.id == Intento.ejercicio_id)
        .where(UsuarioFinal.centro_id == centro_id,
               UsuarioFinal.activo.is_(True),
               Intento.resultado != "sin_valorar",
               # Los RETOS son un extra de grupo, NO medibles a nivel individual:
               # nunca cuentan en el desempeño/evolución de una persona.
               EjercicioCatalogo.bloque != "retos")
    )).all()

    # bloque -> usuario -> [desempeños]; luego media por persona y agregado por área.
    por_bloque: dict[str, dict[str, list[float]]] = {}
    for uf_id, bloque, resultado in filas:
        por_bloque.setdefault(bloque, {}).setdefault(uf_id, []).append(
            rendimiento_resultado(resultado))

    salida: list[ResumenAreaOut] = []
    for bloque, usuarios in por_bloque.items():
        medias = [sum(v) / len(v) for v in usuarios.values() if v]
        if not medias:
            continue
        salida.append(ResumenAreaOut(
            bloque=bloque,
            n_personas=len(medias),
            desempeno_medio=round(sum(medias) / len(medias), 4),
            n_por_debajo=sum(1 for m in medias if m < _UMBRAL_BAJO),
        ))
    salida.sort(key=lambda r: r.desempeno_medio)  # peor primero (a qué mirar)
    return salida


@router.get("/centros/{centro_id}/uso", response_model=ResumenUsoOut)
async def resumen_uso(
    centro_id: str,
    dias_inactividad: int = 14,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Uso y adherencia del centro (evidencia de valor para dirección): sesiones
    recientes, personas activas y quién lleva días sin participar. Scoped al centro."""
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    ahora = datetime.now(timezone.utc)
    d7, d30 = ahora - timedelta(days=7), ahora - timedelta(days=30)

    async def _count(stmt) -> int:
        return int((await db.execute(stmt)).scalar() or 0)

    sesiones_7d = await _count(
        select(func.count()).select_from(Sesion)
        .where(Sesion.centro_id == centro_id, Sesion.fecha >= d7))
    sesiones_30d = await _count(
        select(func.count()).select_from(Sesion)
        .where(Sesion.centro_id == centro_id, Sesion.fecha >= d30))
    personas_totales = await _count(
        select(func.count()).select_from(UsuarioFinal)
        .where(UsuarioFinal.centro_id == centro_id, UsuarioFinal.activo.is_(True)))
    personas_activas_30d = await _count(
        select(func.count(func.distinct(Intento.usuario_final_id)))
        .join(UsuarioFinal, UsuarioFinal.id == Intento.usuario_final_id)
        .where(UsuarioFinal.centro_id == centro_id, Intento.timestamp_inicio >= d30))

    # Último intento por persona (para detectar desconexión).
    usuarios = (await db.execute(
        select(UsuarioFinal.id, UsuarioFinal.alias_interno)
        .where(UsuarioFinal.centro_id == centro_id, UsuarioFinal.activo.is_(True))
    )).all()
    ultimos = dict((await db.execute(
        select(Intento.usuario_final_id, func.max(Intento.timestamp_inicio))
        .join(UsuarioFinal, UsuarioFinal.id == Intento.usuario_final_id)
        .where(UsuarioFinal.centro_id == centro_id)
        .group_by(Intento.usuario_final_id)
    )).all())

    inactivas: list[PersonaInactiva] = []
    for uid, alias in usuarios:
        ts = ultimos.get(uid)
        if ts is None:
            inactivas.append(PersonaInactiva(usuario_final_id=uid, alias_interno=alias,
                                             dias_sin_actividad=None))
            continue
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        dias = (ahora - ts).days
        if dias >= dias_inactividad:
            inactivas.append(PersonaInactiva(usuario_final_id=uid, alias_interno=alias,
                                             dias_sin_actividad=dias))
    # Nunca-participó primero (None), luego más días sin actividad.
    inactivas.sort(key=lambda p: (p.dias_sin_actividad is not None,
                                  -(p.dias_sin_actividad or 0)))
    return ResumenUsoOut(
        personas_totales=personas_totales,
        personas_activas_30d=personas_activas_30d,
        sesiones_7d=sesiones_7d,
        sesiones_30d=sesiones_30d,
        inactivas=inactivas[:30],
    )


@router.get("/export/intentos.csv")
async def exportar_intentos_csv(
    centro_id: str = Query(...),
    usuario_final_id: str | None = None,
    incluir_nombre: bool = False,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Exporta los intentos del centro a CSV (historia clínica, memorias,
    financiadores). Scoped por centro; opcionalmente por persona. Con
    `incluir_nombre` (solo export individual) añade el nombre real para la historia
    clínica. Auditado (RGPD)."""
    if centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No es tu centro")
    # El nombre real solo tiene sentido (y se permite) en la exportación individual.
    nombre_real = None
    if incluir_nombre and usuario_final_id is not None:
        di = (await db.execute(
            select(DatosIdentificativos.nombre_real)
            .where(DatosIdentificativos.usuario_final_id == usuario_final_id)
        )).scalars().first()
        nombre_real = di
    stmt = (
        select(Intento, UsuarioFinal.alias_interno,
                EjercicioCatalogo.nombre, EjercicioCatalogo.bloque)
        .join(UsuarioFinal, UsuarioFinal.id == Intento.usuario_final_id)
        .join(EjercicioCatalogo, EjercicioCatalogo.id == Intento.ejercicio_id)
        .where(UsuarioFinal.centro_id == centro_id)
        .order_by(Intento.timestamp_inicio)
    )
    if usuario_final_id is not None:
        await usuario_del_centro(db, usuario_final_id, staff)  # anti-IDOR (403)
        stmt = stmt.where(Intento.usuario_final_id == usuario_final_id)

    filas = (await db.execute(stmt)).all()
    buf = io.StringIO()
    w = csv.writer(buf, delimiter=";")  # ';' para que Excel-ES lo abra en columnas
    cols = ["fecha", "persona"]
    if nombre_real:
        cols.append("nombre")
    cols += ["area", "actividad", "resultado", "con_ayuda"]
    w.writerow(cols)
    for (i, alias, nombre, bloque) in filas:
        fila = [i.timestamp_inicio.isoformat(sep=" ", timespec="minutes"), alias]
        if nombre_real:
            fila.append(nombre_real)
        fila += [bloque, nombre, _RESULTADO_CSV.get(i.resultado, i.resultado),
                 "sí" if i.con_ayuda else "no"]
        w.writerow(fila)
    await auditar(db, staff, "exportar_csv",
                  usuario_final_id=usuario_final_id,
                  detalle=f"centro={centro_id} filas={len(filas)}")
    await db.commit()
    # BOM para que Excel reconozca UTF-8 (acentos correctos).
    return Response(
        content="﻿" + buf.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": 'attachment; filename="trazo-datos.csv"'},
    )


def _precision(valores: dict) -> float | None:
    # Los `valores` vienen del cliente (JSON) y pueden traer basura (un string
    # donde se espera un número). float() crudo daría un 500 en la gráfica de
    # evolución; por eso cada conversión va protegida y ante datos raros -> None.
    def _f(v):
        try:
            return float(v)
        except (TypeError, ValueError):
            return None

    if not valores:
        return None
    if valores.get("precision") is not None:
        return _f(valores["precision"])
    if valores.get("correcto") is not None:
        return 1.0 if valores["correcto"] else 0.0
    if "aciertos" in valores:
        a = _f(valores.get("aciertos", 0)); f = _f(valores.get("fallos", 0))
        if a is None or f is None:
            return None
        return a / (a + f) if (a + f) > 0 else None
    return None


@router.get("/usuarios/{usuario_id}/evolucion", response_model=EvolucionOut)
async def evolucion_individual(
    usuario_id: str,
    bloque: str | None = Query(default=None),
    desde: datetime | None = Query(default=None),
    hasta: datetime | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR (datos de salud)
    ev = await _calcular_evolucion(db, usuario_id, bloque, desde, hasta)
    await auditar(db, staff, "ver_evolucion", usuario_final_id=usuario_id,
                  detalle=f"bloque={bloque}")
    await db.commit()
    return ev


async def _calcular_evolucion(
    db: AsyncSession,
    usuario_id: str,
    bloque: str | None,
    desde: datetime | None,
    hasta: datetime | None,
) -> EvolucionOut:
    """Calcula la evolución de una persona (sin auditar ni commitear: lo hace
    quien llama). Reutilizable para individual y para grupo con un solo commit."""
    stmt = (
        select(Intento, EjercicioCatalogo)
        .join(EjercicioCatalogo, Intento.ejercicio_id == EjercicioCatalogo.id)
        .where(Intento.usuario_final_id == usuario_id)
        # Los RETOS (extra de grupo) NUNCA son evidencia individual: fuera de la
        # evolución de una persona, se pida el bloque que se pida.
        .where(EjercicioCatalogo.bloque != "retos")
        .order_by(Intento.timestamp_inicio.asc())
    )
    if bloque:
        stmt = stmt.where(EjercicioCatalogo.bloque == bloque)
    if desde:
        stmt = stmt.where(Intento.timestamp_inicio >= desde)
    if hasta:
        stmt = stmt.where(Intento.timestamp_inicio <= hasta)

    filas = (await db.execute(stmt)).all()

    puntos: list[PuntoEvolucion] = []
    rendimientos: list[float] = []
    n_ayuda = 0
    n_sin_valorar = 0
    for intento, ej in filas:
        # Los intentos sin valorar (no-intento o pendientes de revisión) no son
        # evidencia: se cuentan aparte y NO entran en la evolución ni en la media.
        if intento.resultado == "sin_valorar":
            n_sin_valorar += 1
            continue
        puntos.append(PuntoEvolucion(
            fecha=intento.timestamp_inicio,
            ejercicio_id=intento.ejercicio_id,
            bloque=ej.bloque,
            estado=intento.resultado,  # el resultado autocorregido
            precision=_precision(intento.valores_json),
            valores=intento.valores_json or {},
        ))
        rendimientos.append(rendimiento_resultado(intento.resultado))
        # 'con_ayuda' es la capa SECUNDARIA (la marca la integradora), separada
        # del resultado. Se cuenta como matiz, no dispara nada por sí sola.
        if intento.con_ayuda:
            n_ayuda += 1

    resumen = {
        "n_intentos": len(puntos),
        "n_sin_valorar": n_sin_valorar,
        "rendimiento_medio": round(sum(rendimientos) / len(rendimientos), 4) if rendimientos else None,
        "tasa_ayuda": round(n_ayuda / len(puntos), 4) if puntos else None,
    }
    return EvolucionOut(usuario_final_id=usuario_id, bloque=bloque, puntos=puntos, resumen=resumen)


@router.get("/usuarios/{usuario_id}/alertas", response_model=list[AlertaOut])
async def alertas_usuario(
    usuario_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    await usuario_del_centro(db, usuario_id, staff)  # anti-IDOR (datos de salud)
    alertas = (
        await db.execute(
            select(Alerta).where(Alerta.usuario_final_id == usuario_id)
            .order_by(Alerta.fecha_generada.desc())
        )
    ).scalars().all()
    return alertas


@router.get("/grupos/{sesion_id}/evolucion", response_model=list[EvolucionOut])
async def evolucion_grupo(
    sesion_id: str,
    bloque: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Evolución de cada participante del grupo (una entrada por persona)."""
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

    # Un solo commit para todo el grupo (antes: N consultas + N commits en un GET).
    salida: list[EvolucionOut] = []
    for p in parts:
        salida.append(
            await _calcular_evolucion(db, p.usuario_final_id, bloque, None, None))
    await auditar(db, staff, "ver_evolucion_grupo",
                  detalle=f"sesion={sesion_id} n={len(parts)}")
    await db.commit()
    return salida
