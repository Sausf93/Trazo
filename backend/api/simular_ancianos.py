"""Simulación longitudinal de 3 personas mayores jugando IMPERFECTO a lo largo
de varias sesiones, contra la función REAL de alertas (evaluar_usuario_bloque).
NO toca producción (SQLite en memoria). Valida la promesa clínica que pidió Saulo:

  - Se MIDE el desempeño (aunque no jueguen perfecto) y se ve su EVOLUCIÓN.
  - Un mayor ESTABLE (aunque imperfecto) NO dispara alarma.
  - Un empeoramiento SOSTENIDO (Alzheimer) SÍ dispara alerta de rendimiento.
  - Dejar de participar (demencia, desconexión) SÍ dispara alerta de desconexión.
  - Nunca lenguaje diagnóstico; el intento no tocado nace 'sin_valorar' (no es fallo).

Correr a mano:  ./.venv/Scripts/python.exe simular_ancianos.py
"""
import asyncio
import os
import uuid
from datetime import datetime, timezone, timedelta

os.environ.setdefault("PLATFORM_TOKEN", "sim-token")
os.environ.setdefault("ENTORNO", "prod")
os.environ.setdefault("JWT_SECRET", "sim-secret-sim-secret-sim-secret-xx")

from sqlalchemy import select  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.database import Base  # noqa: E402
from app.models import (  # noqa: E402
    Alerta, Centro, EjercicioCatalogo, Intento, Sesion, UsuarioFinal, UsuarioStaff,
)
from app.services.alertas import evaluar_usuario_bloque  # noqa: E402
from app.services.anomalias import rendimiento_resultado  # noqa: E402
from app.services.seed import sincronizar_catalogo  # noqa: E402

BLOQUE = "atencion_memoria"
oks, fails = [], []


def check(cond, msg):
    (oks if cond else fails).append(msg)
    print(("  OK  " if cond else " FAIL ") + msg)


# Perfiles: por sesión, lista de actividades. Cada actividad es:
#   ("logrado"/"parcial"/"no_logrado", interactuo=True)  o  ("sin_valorar", False)
def acts(*res):
    out = []
    for r in res:
        out.append((r, r != "sin_valorar"))
    return out


# 8 sesiones × 4 actividades.
PERFILES = {
    # Ana: mayor estable, imperfecta pero constante (~0.6). NO debe alertar.
    "Ana (estable)": [
        acts("logrado", "parcial", "parcial", "no_logrado"),   # 0.50
        acts("logrado", "logrado", "parcial", "no_logrado"),   # 0.625
        acts("logrado", "parcial", "logrado", "no_logrado"),   # 0.625
        acts("parcial", "logrado", "parcial", "logrado"),      # 0.75
        acts("logrado", "parcial", "no_logrado", "parcial"),   # 0.50
        acts("logrado", "logrado", "parcial", "parcial"),      # 0.75
        acts("parcial", "logrado", "parcial", "no_logrado"),   # 0.50
        acts("logrado", "parcial", "logrado", "parcial"),      # 0.75
    ],
    # Beatriz: Alzheimer. Estable ~0.7 y luego CAE sostenido las 2 últimas.
    "Beatriz (Alzheimer)": [
        acts("logrado", "logrado", "parcial", "parcial"),      # 0.75
        acts("logrado", "parcial", "logrado", "parcial"),      # 0.75
        acts("logrado", "logrado", "parcial", "no_logrado"),   # 0.625
        acts("logrado", "parcial", "logrado", "parcial"),      # 0.75
        acts("logrado", "logrado", "parcial", "parcial"),      # 0.75
        acts("parcial", "logrado", "parcial", "logrado"),      # 0.75
        acts("no_logrado", "no_logrado", "parcial", "no_logrado"),  # 0.125  <-- caída
        acts("no_logrado", "parcial", "no_logrado", "no_logrado"),  # 0.125  <-- caída
    ],
    # Carmen: demencia. Juega bien un tiempo y luego DEJA DE PARTICIPAR
    # (la mayoría de actividades sin tocar) las últimas sesiones.
    "Carmen (demencia)": [
        acts("logrado", "parcial", "logrado", "parcial"),      # participa
        acts("parcial", "logrado", "parcial", "logrado"),
        acts("logrado", "parcial", "parcial", "no_logrado"),
        acts("logrado", "logrado", "parcial", "parcial"),
        acts("parcial", "logrado", "parcial", "parcial"),
        acts("parcial", "sin_valorar", "sin_valorar", "sin_valorar"),  # se desconecta
        acts("sin_valorar", "sin_valorar", "sin_valorar", "parcial"),
        acts("sin_valorar", "sin_valorar", "sin_valorar", "sin_valorar"),
    ],
}


async def main():
    engine = create_async_engine(
        "sqlite+aiosqlite://", poolclass=StaticPool,
        connect_args={"check_same_thread": False})
    async with engine.begin() as c:
        await c.run_sync(Base.metadata.create_all)
    Session = async_sessionmaker(engine, expire_on_commit=False)
    async with Session() as db:
        await sincronizar_catalogo(db)
        ejs = (await db.execute(
            select(EjercicioCatalogo.id).where(EjercicioCatalogo.bloque == BLOQUE).limit(4)
        )).scalars().all()
        if len(ejs) < 4:
            print("No hay 4 ejercicios en", BLOQUE); return
        centro = Centro(id=str(uuid.uuid4()), nombre="Centro Simulación")
        staff = UsuarioStaff(id=str(uuid.uuid4()), centro_id=centro.id, nombre="Integradora",
                             rol="integradora", email="i@sim.local", password_hash="x")
        db.add_all([centro, staff])
        await db.flush()

        t0 = datetime(2026, 6, 1, tzinfo=timezone.utc)
        resumen = {}
        for nombre, sesiones in PERFILES.items():
            persona = UsuarioFinal(id=str(uuid.uuid4()), centro_id=centro.id, alias_interno=nombre)
            db.add(persona)
            await db.flush()
            serie_sesion = []
            for si, actividades in enumerate(sesiones):
                ses = Sesion(id=str(uuid.uuid4()), centro_id=centro.id, tipo="grupo",
                             staff_id=staff.id, fecha=t0 + timedelta(days=si * 3))
                db.add(ses)
                await db.flush()
                perfs = []
                for ai, (res, interactuo) in enumerate(actividades):
                    ej = ejs[ai % len(ejs)]
                    val = {"aciertos": 2, "fallos": 1, "tiempo_ms": 30000} if interactuo else {}
                    it = Intento(
                        id=str(uuid.uuid4()), usuario_final_id=persona.id, sesion_id=ses.id,
                        ejercicio_id=ej, estado="solo", resultado=res, con_ayuda=False,
                        valores_json=val,
                        cantidad_objetivo_json={"n_figuras": 4, "n_rejilla": 8},
                        timestamp_inicio=t0 + timedelta(days=si * 3, minutes=ai),
                        timestamp_fin=t0 + timedelta(days=si * 3, minutes=ai, seconds=30),
                    )
                    db.add(it)
                    if res != "sin_valorar":
                        perfs.append(rendimiento_resultado(res))
                serie_sesion.append(round(sum(perfs) / len(perfs), 2) if perfs else None)
            await db.commit()

            # La integradora ya revisó -> corre la evaluación real de alertas.
            alerta = await evaluar_usuario_bloque(db, persona.id, BLOQUE)
            await db.commit()
            resumen[nombre] = (serie_sesion, alerta)

    # ---- Informe ----
    print("\n=== EVOLUCIÓN (desempeño medio por sesión, 0..1) ===")
    for nombre, (serie, _) in resumen.items():
        print(f"  {nombre:22} {serie}")

    print("\n=== ALERTAS (comparando a cada persona con SU propia base) ===")
    ana = resumen["Ana (estable)"][1]
    bea = resumen["Beatriz (Alzheimer)"][1]
    car = resumen["Carmen (demencia)"][1]

    check(ana is None, "Ana (estable, imperfecta): NO salta alarma")
    check(bea is not None, "Beatriz (Alzheimer): salta alerta por empeoramiento sostenido")
    if bea is not None:
        senal = (bea.contexto_json or {}).get("senal", "")
        check("rendimiento" in senal, f"Beatriz: la señal es de rendimiento ({senal})")
        check((bea.contexto_json or {}).get("no_diagnostico") is True,
              "Beatriz: la alerta se marca NO diagnóstica")
        print("     texto:", bea.descripcion[:160], "...")
    check(car is not None, "Carmen (demencia): salta alerta por desconexión")
    if car is not None:
        senal = (car.contexto_json or {}).get("senal", "")
        check("desconexion" in senal, f"Carmen: la señal incluye desconexión ({senal})")
        print("     texto:", car.descripcion[:160], "...")

    print(f"\n=== RESULTADO: {len(oks)} OK / {len(fails)} FAIL ===")
    for f in fails:
        print("  FALLA:", f)
    return len(fails) == 0


if __name__ == "__main__":
    ok = asyncio.run(main())
    raise SystemExit(0 if ok else 1)
