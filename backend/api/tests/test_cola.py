"""Tests de la construcción de la cola desde el plan (con BD SQLite en memoria).

Cubre lo que importa del motor de cola (MODELO-OPERATIVO §2 y §3):
  - una línea de dominio se resuelve a ejercicios activos del bloque,
  - `n_por_sesion` controla cuántos entran (ciclando si hacen falta),
  - una línea de ejercicio fijo entra tal cual, N veces,
  - las líneas inactivas se ignoran,
  - en modo grupo la cola es el ejercicio compartido, cada uno a su nivel.
"""
from __future__ import annotations

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import Base
from app.models import (
    Centro,
    EjercicioCatalogo,
    PlanPacienteLinea,
    Sesion,
    UsuarioFinal,
    UsuarioStaff,
)
from app.services.cola import construir_cola


@pytest_asyncio.fixture
async def db():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    Session = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    async with Session() as s:
        yield s
    await engine.dispose()


async def _setup_basico(db: AsyncSession):
    centro = Centro(nombre="C")
    db.add(centro)
    await db.flush()
    staff = UsuarioStaff(centro_id=centro.id, nombre="S", rol="integradora",
                         email="s@x.com", password_hash="x")
    uf = UsuarioFinal(centro_id=centro.id, alias_interno="Paco", nivel_base_json={})
    db.add_all([staff, uf])
    await db.flush()
    # Dos ejercicios de praxias (para probar rotación) + uno de lenguaje.
    p1 = EjercicioCatalogo(bloque="praxias", plantilla_tipo="trazo", nombre="A-linea")
    p2 = EjercicioCatalogo(bloque="praxias", plantilla_tipo="trazo", nombre="B-arco")
    l1 = EjercicioCatalogo(bloque="lenguaje", plantilla_tipo="seleccion_multiple", nombre="Palabras")
    db.add_all([p1, p2, l1])
    await db.flush()
    return centro, staff, uf, p1, p2, l1


@pytest.mark.asyncio
async def test_dominio_resuelve_n_por_sesion_con_rotacion(db):
    _, staff, uf, p1, p2, l1 = await _setup_basico(db)
    db.add(PlanPacienteLinea(usuario_final_id=uf.id, tipo="dominio",
                             bloque="praxias", nivel="bajo", n_por_sesion=3, orden=0))
    await db.flush()
    cola = await construir_cola(db, uf.id)
    # 3 items del bloque praxias; con 2 ejercicios disponibles cicla A,B,A.
    assert len(cola) == 3
    assert all(i.bloque == "praxias" and i.nivel == "bajo" for i in cola)
    nombres = [i.nombre for i in cola]
    assert nombres == ["A-linea", "B-arco", "A-linea"]


@pytest.mark.asyncio
async def test_ejercicio_fijo_entra_n_veces(db):
    _, staff, uf, p1, p2, l1 = await _setup_basico(db)
    db.add(PlanPacienteLinea(usuario_final_id=uf.id, tipo="ejercicio",
                             ejercicio_id=l1.id, nivel="medio", n_por_sesion=2, orden=0))
    await db.flush()
    cola = await construir_cola(db, uf.id)
    assert len(cola) == 2
    assert all(i.ejercicio_id == l1.id and i.origen == "ejercicio" for i in cola)


@pytest.mark.asyncio
async def test_linea_inactiva_se_ignora(db):
    _, staff, uf, p1, p2, l1 = await _setup_basico(db)
    db.add(PlanPacienteLinea(usuario_final_id=uf.id, tipo="dominio",
                             bloque="praxias", n_por_sesion=1, orden=0, activo=False))
    await db.flush()
    cola = await construir_cola(db, uf.id)
    assert cola == []


@pytest.mark.asyncio
async def test_orden_de_lineas_se_respeta(db):
    _, staff, uf, p1, p2, l1 = await _setup_basico(db)
    db.add_all([
        PlanPacienteLinea(usuario_final_id=uf.id, tipo="dominio",
                          bloque="lenguaje", n_por_sesion=1, orden=1),
        PlanPacienteLinea(usuario_final_id=uf.id, tipo="dominio",
                          bloque="praxias", n_por_sesion=1, orden=0),
    ])
    await db.flush()
    cola = await construir_cola(db, uf.id)
    assert [i.bloque for i in cola] == ["praxias", "lenguaje"]


@pytest.mark.asyncio
async def test_modo_grupo_usa_ejercicio_compartido_a_su_nivel(db):
    centro, staff, uf, p1, p2, l1 = await _setup_basico(db)
    # Su plan da nivel 'bajo' en praxias; el compartido es un ejercicio de praxias.
    db.add(PlanPacienteLinea(usuario_final_id=uf.id, tipo="dominio",
                             bloque="praxias", nivel="bajo", n_por_sesion=5, orden=0))
    ses = Sesion(centro_id=centro.id, tipo="grupo", modo="grupo",
                 ejercicio_compartido_id=p1.id, staff_id=staff.id)
    db.add(ses)
    await db.flush()
    cola = await construir_cola(db, uf.id, ses)
    # En grupo: un único item, el compartido, resuelto a su nivel de praxias.
    assert len(cola) == 1
    assert cola[0].ejercicio_id == p1.id
    assert cola[0].origen == "grupo"
    assert cola[0].nivel == "bajo"
