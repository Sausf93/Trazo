"""Panorámica del centro por área: agrega desempeño por bloque y aísla por centro."""
from __future__ import annotations

import uuid

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client, cred=INTEGRADORA):
    r = await client.post("/auth/login", data={"username": cred[0], "password": cred[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    return {u["alias_interno"]: u for u in r.json()}


@pytest.mark.asyncio
async def test_resumen_areas_agrega_y_aisla(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    paco = (await _usuarios(client, headers, centro_id))["Paco"]
    ej = (await client.get("/ejercicios?bloque=praxias&activo=true", headers=headers)).json()[0]

    # Un intento logrado en 'praxias'.
    r = await client.post("/sesiones", headers=headers,
                          json={"tipo": "individual", "participantes": [paco["id"]]})
    sesion_id = r.json()["id"]
    iid = str(uuid.uuid4())
    await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                      json={"id": iid, "usuario_final_id": paco["id"], "sesion_id": sesion_id,
                            "ejercicio_id": ej["id"], "estado": "sin_valorar",
                            "valores_json": {}, "cantidad_objetivo_json": {}})
    await client.patch(f"/intentos/{iid}/resultado", headers=headers, json={"resultado": "logrado"})

    r = await client.get(f"/centros/{centro_id}/resumen-areas", headers=headers)
    assert r.status_code == 200, r.text
    praxias = next((a for a in r.json() if a["bloque"] == "praxias"), None)
    assert praxias is not None and praxias["n_personas"] >= 1
    assert 0.0 <= praxias["desempeno_medio"] <= 1.0

    # Aislamiento: otro centro no ve este resumen.
    from app.models import Centro, UsuarioStaff
    from app.security import hash_password
    async with Session() as db:
        c2 = Centro(nombre="Otro RA")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(centro_id=c2.id, nombre="Ajeno", rol="integradora",
                            email="ajeno_ra@trazo.local", password_hash=hash_password("trazo1234")))
        await db.commit()
    _, h2 = await _login(client, ("ajeno_ra@trazo.local", "trazo1234"))
    r = await client.get(f"/centros/{centro_id}/resumen-areas", headers=h2)
    assert r.status_code == 403, r.text
