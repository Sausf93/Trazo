"""Construcción de la cola de ejercicios de una persona a partir de su plan.

La cola es la lista ordenada de ejercicios que le tocan HOY a un participante,
resolviendo cada línea de su plan (ver MODELO-OPERATIVO §2):

- Línea de **ejercicio** concreto -> ese ejercicio, `n_por_sesion` veces.
- Línea de **dominio** (bloque) -> el motor elige `n_por_sesion` ejercicios
  ACTIVOS de ese bloque del catálogo (rotación determinista por nombre).

En **modo grupo** (§3) la cola es el `ejercicio_compartido` de la sesión para
todos, pero cada persona a SU nivel (tomado de su plan o de su nivel base).
"""
from __future__ import annotations

from dataclasses import dataclass

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    EjercicioCatalogo,
    Intento,
    PlanPacienteLinea,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
)

# Tope defensivo de actividades por línea: por muy alto que llegue `n` (config de
# sesión, "más" o plan), la cola no crece sin límite (protege memoria/CPU).
_MAX_N = 50


def _clamp_n(valor) -> int:
    try:
        n = int(valor)
    except (TypeError, ValueError):
        n = 1
    return min(_MAX_N, max(1, n))


async def _cola_desde_config(
    db: AsyncSession, config: dict, usuario_final_id: str
) -> list["ItemColaData"]:
    """Cola a partir de la config que fija la maestra para la sesión.

    config = {
      "nivel": "medio",
      "lineas": [{"bloque": "razonamiento", "n": 4}, ...],   # por dominio
      "ejercicios": [{"ejercicio_id": "…", "nivel": "bajo"}, ...],  # concretos
    }
    - `ejercicios` = actividades CONCRETAS que la integradora eligió EN VIVO (o una
      propuesta aceptada); van primero, con su propio nivel si se indica.
    - `lineas` = bloques; el nivel de la config aplica a todas salvo que la línea
      traiga el suyo. Dentro de un bloque se prioriza lo MENOS jugado (frescura).
    """
    nivel = config.get("nivel")
    cola: list[ItemColaData] = []

    # 1) Actividades concretas elegidas en vivo (o propuesta aceptada).
    for it in config.get("ejercicios", []) or []:
        eid = it.get("ejercicio_id") if isinstance(it, dict) else it
        if not eid:
            continue
        ej = await db.get(EjercicioCatalogo, eid)
        if ej is None or not ej.activo:
            continue
        ni = (it.get("nivel") if isinstance(it, dict) else None) or nivel
        cola.append(ItemColaData(
            ejercicio_id=ej.id, nombre=ej.nombre, bloque=ej.bloque,
            plantilla=ej.plantilla_tipo, nivel=ni, origen="en_vivo",
        ))

    # 2) Bloques (dominio) fijados para la sesión.
    dificultad = _NIVEL_DIFICULTAD.get(nivel)
    for linea in config.get("lineas", []):
        bloque = linea.get("bloque")
        n = _clamp_n(linea.get("n", 1))
        if not bloque:
            continue
        candidatos = await _ejercicios_de_bloque(db, bloque, dificultad)
        if not candidatos:
            continue
        candidatos = await _ordenar_por_frescura(db, usuario_final_id, candidatos)
        for i in range(n):
            ej = candidatos[i % len(candidatos)]
            cola.append(ItemColaData(
                ejercicio_id=ej.id, nombre=ej.nombre, bloque=ej.bloque,
                plantilla=ej.plantilla_tipo, nivel=nivel, origen="sesion",
            ))
    return cola


async def _ordenar_por_frescura(
    db: AsyncSession, usuario_final_id: str,
    candidatos: list[EjercicioCatalogo],
) -> list[EjercicioCatalogo]:
    """Ordena los candidatos poniendo delante los que la persona ha jugado MENOS.

    Así la app "propone" actividades frescas cada día (no siempre las mismas) sin
    dejar de ser DETERMINISTA: a igualdad de uso se conserva el orden de entrada
    (por nombre). Con historial vacío el orden es idéntico al de antes."""
    ids = [e.id for e in candidatos]
    if not ids:
        return candidatos
    filas = (
        await db.execute(
            select(Intento.ejercicio_id, func.count())
            .where(
                Intento.usuario_final_id == usuario_final_id,
                Intento.ejercicio_id.in_(ids),
            )
            .group_by(Intento.ejercicio_id)
        )
    ).all()
    uso = {eid: c for eid, c in filas}
    # sorted es estable: los empates (mismo uso) mantienen el orden por nombre.
    return sorted(candidatos, key=lambda e: uso.get(e.id, 0))


@dataclass
class ItemColaData:
    ejercicio_id: str
    nombre: str
    bloque: str
    plantilla: str
    nivel: str | None
    # De dónde nace el ítem: plan por dominio/ejercicio, grupo compartido, config
    # de sesión (bloques que fijó la maestra), o 'en_vivo' (actividad concreta
    # elegida por la integradora en el momento o propuesta aceptada).
    origen: str  # 'dominio' | 'ejercicio' | 'grupo' | 'sesion' | 'en_vivo'
    plan_linea_id: str | None = None


# El nivel de la sesión elige la DIFICULTAD inherente de la actividad, no solo la
# cantidad. Así "nivel alto" trae actividades cognitivamente más exigentes (sumas,
# leer la hora…) y "bajo" las más sencillas (reconocer, tocar la igual).
_NIVEL_DIFICULTAD = {"bajo": "facil", "medio": "media", "alto": "dificil"}


async def _ejercicios_de_bloque(
    db: AsyncSession, bloque: str, dificultad: str | None = None
) -> list[EjercicioCatalogo]:
    """Ejercicios ACTIVOS de un bloque, orden determinista (por nombre, luego id).

    Si se pide una `dificultad`, prioriza las actividades de esa dificultad; si el
    bloque no tiene ninguna de esa dificultad, cae a todas (no deja hueco)."""
    todos = (
        await db.execute(
            select(EjercicioCatalogo)
            .where(
                EjercicioCatalogo.bloque == bloque,
                EjercicioCatalogo.activo.is_(True),
            )
            .order_by(EjercicioCatalogo.nombre, EjercicioCatalogo.id)
        )
    ).scalars().all()
    if dificultad:
        match = [
            e for e in todos
            if (e.parametros_json or {}).get("dificultad") == dificultad
        ]
        if match:
            return match
    return todos


async def _nivel_para_ejercicio(
    db: AsyncSession,
    usuario_final_id: str,
    ejercicio: EjercicioCatalogo,
) -> str | None:
    """Nivel de la persona para un ejercicio concreto.

    Prioridad: línea de plan del ejercicio -> línea de plan del bloque ->
    `nivel_base_json` (por ejercicio o por bloque).
    """
    lineas = (
        await db.execute(
            select(PlanPacienteLinea).where(
                PlanPacienteLinea.usuario_final_id == usuario_final_id,
                PlanPacienteLinea.activo.is_(True),
            )
        )
    ).scalars().all()
    # Ejercicio fijado tiene prioridad sobre dominio.
    for ln in lineas:
        if ln.tipo == "ejercicio" and ln.ejercicio_id == ejercicio.id and ln.nivel:
            return ln.nivel
    for ln in lineas:
        if ln.tipo == "dominio" and ln.bloque == ejercicio.bloque and ln.nivel:
            return ln.nivel
    uf = await db.get(UsuarioFinal, usuario_final_id)
    base = (uf.nivel_base_json or {}) if uf else {}
    val = base.get(ejercicio.id) or base.get(ejercicio.bloque)
    return str(val) if val is not None else None


async def construir_cola(
    db: AsyncSession,
    usuario_final_id: str,
    sesion: Sesion | None = None,
) -> list[ItemColaData]:
    """Construye la cola resuelta de la persona.

    Si `sesion` es modo grupo con ejercicio compartido, la cola es ese único
    ejercicio (a su nivel). En caso contrario, se resuelve desde su plan.
    """
    # --- Modo grupo: actividad compartida, cada uno a su nivel ---
    if sesion is not None and sesion.modo == "grupo" and sesion.ejercicio_compartido_id:
        ej = await db.get(EjercicioCatalogo, sesion.ejercicio_compartido_id)
        if ej is None:
            return []
        nivel = await _nivel_para_ejercicio(db, usuario_final_id, ej)
        return [
            ItemColaData(
                ejercicio_id=ej.id,
                nombre=ej.nombre,
                bloque=ej.bloque,
                plantilla=ej.plantilla_tipo,
                nivel=nivel,
                origen="grupo",
            )
        ]

    # --- Override de la maestra para esta sesión (config por participante) ---
    if sesion is not None:
        sp = (
            await db.execute(
                select(SesionParticipante).where(
                    SesionParticipante.sesion_id == sesion.id,
                    SesionParticipante.usuario_final_id == usuario_final_id,
                )
            )
        ).scalars().first()
        if sp is not None and sp.config_json:
            return await _cola_desde_config(db, sp.config_json, usuario_final_id)

    # --- Modo individual: resolver el plan de la persona ---
    lineas = (
        await db.execute(
            select(PlanPacienteLinea)
            .where(
                PlanPacienteLinea.usuario_final_id == usuario_final_id,
                PlanPacienteLinea.activo.is_(True),
            )
            .order_by(PlanPacienteLinea.orden, PlanPacienteLinea.id)
        )
    ).scalars().all()

    cola: list[ItemColaData] = []
    for ln in lineas:
        n = _clamp_n(ln.n_por_sesion or 1)

        if ln.tipo == "ejercicio":
            if not ln.ejercicio_id:
                continue
            ej = await db.get(EjercicioCatalogo, ln.ejercicio_id)
            if ej is None or not ej.activo:
                continue
            for _ in range(n):
                cola.append(ItemColaData(
                    ejercicio_id=ej.id, nombre=ej.nombre, bloque=ej.bloque,
                    plantilla=ej.plantilla_tipo, nivel=ln.nivel,
                    origen="ejercicio", plan_linea_id=ln.id,
                ))

        elif ln.tipo == "dominio":
            if not ln.bloque:
                continue
            candidatos = await _ejercicios_de_bloque(
                db, ln.bloque, _NIVEL_DIFICULTAD.get(ln.nivel))
            if not candidatos:
                continue
            # Si la dificultad pedida tiene MENOS ejercicios que `n`, se completa
            # con el resto del bloque (otras dificultades) para NO repetir la misma
            # actividad en una sesión (repetir falsea la base de la evolución).
            if len(candidatos) < n:
                vistos_ej = {e.id for e in candidatos}
                for e in await _ejercicios_de_bloque(db, ln.bloque, None):
                    if e.id not in vistos_ej:
                        candidatos.append(e)
                        vistos_ej.add(e.id)
            # Frescura: primero lo MENOS jugado por esta persona (la app propone
            # variedad); determinista, con historial vacío = orden por nombre.
            candidatos = await _ordenar_por_frescura(db, usuario_final_id, candidatos)
            for i in range(n):
                ej = candidatos[i % len(candidatos)]
                cola.append(ItemColaData(
                    ejercicio_id=ej.id, nombre=ej.nombre, bloque=ej.bloque,
                    plantilla=ej.plantilla_tipo, nivel=ln.nivel,
                    origen="dominio", plan_linea_id=ln.id,
                ))

    return cola
