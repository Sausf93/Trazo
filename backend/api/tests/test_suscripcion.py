"""Compuerta de suscripción: el acceso del centro depende de su estado.

- prueba (no caducada) y cortesia -> acceso OK.
- suspendido/cancelada y prueba caducada -> 403.
- checkout: 503 si Stripe no está configurado (dev/tests).
"""
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.models import Centro


async def _login(client, email="integradora@trazo.local", pw="trazo1234"):
    r = await client.post("/auth/login", data={"username": email, "password": pw})
    assert r.status_code == 200, r.text
    return {"Authorization": "Bearer " + r.json()["access_token"]}


async def _fijar_estado(Session, *, estado, fin=None):
    async with Session() as s:
        centro = (await s.execute(select(Centro))).scalars().first()
        centro.estado_suscripcion = estado
        centro.fecha_fin_prueba = fin
        await s.commit()


@pytest.mark.asyncio
async def test_prueba_no_caducada_permite_acceso(client):
    h = await _login(client)
    r = await client.get("/pendientes", headers=h)
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_suspendido_corta_acceso(client, Session):
    h = await _login(client)
    await _fijar_estado(Session, estado="suspendido")
    r = await client.get("/pendientes", headers=h)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_prueba_caducada_corta_acceso(client, Session):
    h = await _login(client)
    ayer = datetime.now(timezone.utc) - timedelta(days=1)
    await _fijar_estado(Session, estado="prueba", fin=ayer)
    r = await client.get("/pendientes", headers=h)
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_cortesia_permite_acceso_aunque_prueba_caducada(client, Session):
    h = await _login(client)
    ayer = datetime.now(timezone.utc) - timedelta(days=1)
    await _fijar_estado(Session, estado="cortesia", fin=ayer)
    r = await client.get("/pendientes", headers=h)
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_checkout_sin_stripe_devuelve_503(client):
    h = await _login(client, "admin@trazo.local", "trazo1234")
    r = await client.post("/facturacion/checkout", headers=h)
    assert r.status_code == 503
