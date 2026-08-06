"""Orquestación de alertas: lee intentos de BD y aplica el motor de anomalías."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Alerta, EjercicioCatalogo, Intento
from app.services.anomalias import detectar_desviacion, rendimiento_intento


async def evaluar_usuario_bloque(
    db: AsyncSession,
    usuario_final_id: str,
    bloque: str,
) -> Alerta | None:
    """Evalúa el histórico de una persona en un bloque y crea alerta si procede.

    Devuelve la Alerta creada (aún sin commit) o None. El commit lo hace quien
    llama, para poder agrupar varias evaluaciones en una transacción.
    """
    # Intentos de esa persona en ese bloque, de más antiguo a más reciente.
    stmt = (
        select(Intento)
        .join(EjercicioCatalogo, Intento.ejercicio_id == EjercicioCatalogo.id)
        .where(
            Intento.usuario_final_id == usuario_final_id,
            EjercicioCatalogo.bloque == bloque,
        )
        .order_by(Intento.timestamp_inicio.asc())
    )
    intentos = (await db.execute(stmt)).scalars().all()
    if not intentos:
        return None

    serie = [rendimiento_intento(i.estado, i.valores_json) for i in intentos]
    resultado = detectar_desviacion(serie)
    if resultado is None or not resultado.hay_desviacion:
        return None

    # Evitar duplicar: ¿ya hay una alerta abierta de este bloque?
    abierta = (
        await db.execute(
            select(Alerta).where(
                Alerta.usuario_final_id == usuario_final_id,
                Alerta.bloque_afectado == bloque,
                Alerta.fecha_revision.is_(None),
            )
        )
    ).scalars().first()
    if abierta is not None:
        return None

    alerta = Alerta(
        usuario_final_id=usuario_final_id,
        tipo="individual",
        bloque_afectado=bloque,
        descripcion=(
            f"Cambio sostenido en '{bloque}': las últimas {resultado.n_reciente} "
            f"sesiones (media {resultado.reciente_media}) se salen del patrón "
            f"habitual de esta persona (media {resultado.baseline_media}, "
            f"umbral {resultado.umbral_inferior}). Puede merecer una revisión."
        ),
        contexto_json={
            "baseline_media": resultado.baseline_media,
            "baseline_std": resultado.baseline_std,
            "reciente_media": resultado.reciente_media,
            "umbral_inferior": resultado.umbral_inferior,
            "n_baseline": resultado.n_baseline,
            "n_reciente": resultado.n_reciente,
            "caida": resultado.caida,
        },
    )
    db.add(alerta)
    return alerta
