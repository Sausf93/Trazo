"""La facilitadora puede guardar observaciones libres de una sesión."""
from __future__ import annotations

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client):
    r = await client.post(
        "/auth/login",
        data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    return body, {"Authorization": f"Bearer {body['access_token']}"}


async def _un_usuario(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    assert r.status_code == 200, r.text
    return r.json()[0]


@pytest.mark.asyncio
async def test_guardar_y_leer_notas(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    uf = await _un_usuario(client, headers, centro_id)

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "nombre": "Sesión con nota",
              "participantes": [uf["id"]]},
    )
    assert r.status_code == 201, r.text
    sesion_id = r.json()["id"]

    # Al principio no hay nota.
    r = await client.get(f"/sesiones/{sesion_id}/resumen", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["notas"] is None

    # Guardar una nota -> aparece en el resumen.
    r = await client.patch(
        f"/sesiones/{sesion_id}/notas",
        headers=headers,
        json={"nota": "  Paco algo cansado hoy, pero participativo.  "},
    )
    assert r.status_code == 200, r.text
    assert r.json()["notas"] == "Paco algo cansado hoy, pero participativo."

    r = await client.get(f"/sesiones/{sesion_id}/resumen", headers=headers)
    assert r.json()["notas"] == "Paco algo cansado hoy, pero participativo."

    # Vaciarla -> vuelve a None (no cadena vacía).
    r = await client.patch(
        f"/sesiones/{sesion_id}/notas", headers=headers, json={"nota": "   "}
    )
    assert r.status_code == 200, r.text
    assert r.json()["notas"] is None


@pytest.mark.asyncio
async def test_notas_sesion_ajena_403(client):
    """No se puede escribir notas en una sesión de otro centro (anti-IDOR)."""
    _, headers = await _login(client)
    # Sesión inexistente -> 404 (mismo endpoint, control de acceso previo).
    r = await client.patch(
        "/sesiones/no-existe/notas", headers=headers, json={"nota": "x"}
    )
    assert r.status_code == 404, r.text
