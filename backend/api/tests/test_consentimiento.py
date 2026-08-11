"""Registro de consentimiento (RGPD): titular o representante legal."""
from __future__ import annotations

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client):
    r = await client.post("/auth/login",
                          data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


@pytest.mark.asyncio
async def test_registrar_y_listar_consentimiento(client):
    _, headers = await _login(client)
    r = await client.post("/usuarios", headers=headers,
                          json={"alias_interno": "Persona con tutor"})
    uid = r.json()["id"]

    r = await client.post(f"/usuarios/{uid}/consentimiento", headers=headers,
                          json={"tipo": "uso_y_seguimiento",
                                "otorgado_por": "María (hija, tutora)",
                                "rol_otorgante": "tutor",
                                "documento_ref": "archivador-2026-014"})
    assert r.status_code == 201, r.text
    assert r.json()["rol_otorgante"] == "tutor"

    r = await client.get(f"/usuarios/{uid}/consentimiento", headers=headers)
    assert r.status_code == 200, r.text
    assert len(r.json()) == 1

    # Rol inválido -> 422.
    r = await client.post(f"/usuarios/{uid}/consentimiento", headers=headers,
                          json={"otorgado_por": "x", "rol_otorgante": "vecino"})
    assert r.status_code == 422, r.text
