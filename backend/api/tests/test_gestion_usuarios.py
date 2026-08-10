"""La integradora gestiona sus plazas: editar y dar de baja usuarios."""
from __future__ import annotations

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client):
    r = await client.post("/auth/login",
                          data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


@pytest.mark.asyncio
async def test_editar_y_dar_de_baja(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]

    r = await client.post("/usuarios", headers=headers,
                          json={"alias_interno": "Nuevo", "nivel_base_json": {}})
    uid = r.json()["id"]

    # Editar alias y nivel.
    r = await client.patch(f"/usuarios/{uid}", headers=headers,
                           json={"alias_interno": "Nuevo Corregido",
                                 "nivel_base_json": {"praxias": "alto"}})
    assert r.status_code == 200, r.text
    assert r.json()["alias_interno"] == "Nuevo Corregido"
    assert r.json()["nivel_base_json"]["praxias"] == "alto"

    # Dar de baja -> desaparece del listado, pero se conserva.
    r = await client.post(f"/usuarios/{uid}/baja", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["activo"] is False
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    assert uid not in {u["id"] for u in r.json()}


@pytest.mark.asyncio
async def test_editar_usuario_ajeno_403(client):
    _, headers = await _login(client)
    r = await client.patch("/usuarios/no-existe", headers=headers,
                           json={"alias_interno": "x"})
    assert r.status_code == 404, r.text
