"""La sonda de salud comprueba de verdad la base de datos."""
from __future__ import annotations

import pytest


@pytest.mark.asyncio
async def test_health_ok(client):
    r = await client.get("/health")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "ok"
    assert body["database"] == "up"


@pytest.mark.asyncio
async def test_raiz(client):
    r = await client.get("/")
    assert r.status_code == 200, r.text
    assert r.json()["app"] == "Trazo API"
