"""Siembra de datos de demo (idempotente).

Crea un centro, staff con login, participantes pseudonimizados, un ejercicio por
cada uno de los 8 bloques (sobre el motor de plantillas) y algunos intentos de
ejemplo — incluyendo una tendencia a la baja que dispara una alerta, para que el
panel se vea con vida desde el primer arranque.

Credenciales de demo:
    admin@trazo.local        / trazo1234   (admin_centro)
    integradora@trazo.local  / trazo1234   (integradora)
"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Centro,
    DatosIdentificativos,
    Dispositivo,
    EjercicioCatalogo,
    Intento,
    PlanPacienteLinea,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.security import hash_password
from app.services.alertas import evaluar_usuario_bloque

PASSWORD_DEMO = "trazo1234"

# El catálogo vive como DATOS (no como código): añadir una actividad nueva es
# añadir un objeto a este JSON, sin tocar la lógica de siembra ni las plantillas.
_CATALOGO_PATH = Path(__file__).resolve().parent.parent / "data" / "catalogo.json"


def _ejercicios_semilla() -> list[dict]:
    """Carga TODO el catálogo de ejercicios desde `app/data/catalogo.json`.

    Data-driven: para dar de alta una actividad basta con añadir una fila al
    JSON con su `bloque`, `plantilla_tipo`, `nombre`, `descripcion` y el
    `parametros_json` que consuma su plantilla (ver `templates/tipos.py`).
    """
    with _CATALOGO_PATH.open(encoding="utf-8") as f:
        return json.load(f)


async def sembrar(db: AsyncSession) -> None:
    existe = (await db.execute(select(Centro).limit(1))).scalars().first()
    if existe is not None:
        return  # ya sembrado

    ahora = datetime.now(timezone.utc)

    centro = Centro(nombre="Centro de Día Demo")
    db.add(centro)
    await db.flush()

    db.add_all([
        UsuarioStaff(centro_id=centro.id, nombre="Marta (dirección)", rol="admin_centro",
                     email="admin@trazo.local", password_hash=hash_password(PASSWORD_DEMO)),
        UsuarioStaff(centro_id=centro.id, nombre="Laura", rol="integradora",
                     email="integradora@trazo.local", password_hash=hash_password(PASSWORD_DEMO)),
    ])
    staff_integradora = None
    await db.flush()
    staff_integradora = (
        await db.execute(select(UsuarioStaff).where(UsuarioStaff.rol == "integradora"))
    ).scalars().first()

    # Participantes: el alias es el nombre de pila (lo que ve el equipo para
    # reconocer a la persona); el nombre COMPLETO va en la tabla separada
    # restringida. Los dos primeros llevan historial (para el panel); el resto
    # son solo altas, para que el desplegable de reparto se vea realista.
    roster = [
        ("Paco", "Francisco Gómez Ruiz"),
        ("Marisa", "María Luisa Herrero Díaz"),
        ("Carmen", "Carmen Ortiz Vidal"),
        ("Juan", "Juan López Serrano"),
        ("Lola", "Dolores Martín Cano"),
        ("Pepe", "José Antonio Ramírez"),
        ("Rosa", "Rosa Fernández Gil"),
        ("Antonio", "Antonio Navarro Peña"),
    ]
    participantes: list[UsuarioFinal] = []
    for alias, nombre_real in roster:
        uf = UsuarioFinal(centro_id=centro.id, alias_interno=alias, nivel_base_json={})
        db.add(uf)
        await db.flush()
        db.add(DatosIdentificativos(usuario_final_id=uf.id, nombre_real=nombre_real))
        participantes.append(uf)

    # Ejercicios (catálogo completo, cargado del JSON data-driven).
    por_nombre: dict[str, EjercicioCatalogo] = {}
    for cfg in _ejercicios_semilla():
        ej = EjercicioCatalogo(**cfg)
        db.add(ej)
        await db.flush()
        por_nombre[cfg["nombre"]] = ej

    await db.flush()

    # --- Intentos de demo para dar vida al panel ---
    # Paquito: praxias con tendencia clara a la baja -> debe disparar alerta.
    # Marisa: praxias estable/al alza -> sin alerta.
    # Se usa el trazo "Sigue la línea" (grafomotricidad) como ejercicio de praxias.
    ej_praxias = por_nombre["Sigue la línea"]

    def _crear_sesion_e_intento(uf, ej, dias_atras, precision, estado="solo"):
        fecha = ahora - timedelta(days=dias_atras)
        ses = Sesion(centro_id=centro.id, fecha=fecha, tipo="individual",
                     staff_id=staff_integradora.id, cerrada=True)
        db.add(ses)
        return ses, fecha

    # Series de precisión (de más antiguo a más reciente).
    serie_paquito = [0.86, 0.88, 0.90, 0.89, 0.91, 0.90, 0.62, 0.55]  # cae al final
    serie_marisa = [0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.85]   # mejora

    for uf, serie in [(participantes[0], serie_paquito), (participantes[1], serie_marisa)]:
        n = len(serie)
        for idx, prec in enumerate(serie):
            dias = (n - idx) * 5  # una sesión cada ~5 días
            fecha = ahora - timedelta(days=dias)
            ses = Sesion(centro_id=centro.id, fecha=fecha, tipo="individual",
                         staff_id=staff_integradora.id, cerrada=True)
            db.add(ses)
            await db.flush()
            db.add(SesionParticipante(sesion_id=ses.id, usuario_final_id=uf.id))
            db.add(Intento(
                usuario_final_id=uf.id, sesion_id=ses.id, ejercicio_id=ej_praxias.id,
                timestamp_inicio=fecha, timestamp_fin=fecha + timedelta(minutes=2),
                estado="solo",
                valores_json={"precision": prec, "tiempo_ms": 90000},
                cantidad_objetivo_json={"figura_id": "onda", "tolerancia_px": 24},
            ))

    await db.flush()

    # --- Planes de trabajo de demo (formato mixto por dominio) ---
    # Paco: praxias (bajo) + atención/memoria (medio). Marisa: lenguaje.
    paco, marisa = participantes[0], participantes[1]
    db.add_all([
        PlanPacienteLinea(usuario_final_id=paco.id, tipo="dominio",
                          bloque="praxias", nivel="bajo", n_por_sesion=2, orden=0),
        PlanPacienteLinea(usuario_final_id=paco.id, tipo="dominio",
                          bloque="atencion_memoria", nivel="medio", n_por_sesion=1, orden=1),
        PlanPacienteLinea(usuario_final_id=marisa.id, tipo="dominio",
                          bloque="lenguaje", nivel="medio", n_por_sesion=2, orden=0),
    ])

    # --- Dispositivos emparejados de demo (1 maestra + 2 participantes) ---
    db.add_all([
        Dispositivo(centro_id=centro.id, nombre="Tablet maestra (Laura)", rol="maestra"),
        Dispositivo(centro_id=centro.id, nombre="Tablet participante 1", rol="participante"),
        Dispositivo(centro_id=centro.id, nombre="Tablet participante 2", rol="participante"),
    ])

    await db.flush()

    # Evaluar alertas sobre los datos sembrados.
    for uf in participantes:
        await evaluar_usuario_bloque(db, uf.id, "praxias")

    await db.commit()
