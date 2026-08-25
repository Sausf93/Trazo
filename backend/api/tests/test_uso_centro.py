"""Uso/adherencia del centro (evidencia para dirección): cuenta sesiones y
personas activas, detecta a quién lleva días sin participar, y aísla por centro."""
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
async def test_uso_centro_cuenta_y_detecta_inactivos(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]
    # Persona nueva que NO participa (para el caso "nunca ha jugado").
    nunca = (await client.post("/usuarios", headers=headers,
                               json={"alias_interno": "NuncaJuega"})).json()
    ej = (await client.get("/ejercicios?bloque=praxias&activo=true", headers=headers)).json()[0]

    # Paco hace una actividad hoy (sesión + intento).
    r = await client.post("/sesiones", headers=headers,
                          json={"tipo": "individual", "participantes": [paco["id"]]})
    sesion_id = r.json()["id"]
    await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                      json={"id": str(uuid.uuid4()), "usuario_final_id": paco["id"],
                            "sesion_id": sesion_id, "ejercicio_id": ej["id"],
                            "estado": "sin_valorar", "valores_json": {}, "cantidad_objetivo_json": {}})

    r = await client.get(f"/centros/{centro_id}/uso", headers=headers)
    assert r.status_code == 200, r.text
    uso = r.json()
    assert uso["personas_totales"] >= 1
    assert uso["personas_activas_30d"] >= 1          # Paco cuenta
    assert uso["sesiones_7d"] >= 1 and uso["sesiones_30d"] >= 1
    # Paco NO debe salir como inactivo (acaba de participar).
    assert paco["id"] not in {p["usuario_final_id"] for p in uso["inactivas"]}
    # La persona nueva que nunca ha jugado SÍ sale, con dias=None (nunca).
    m = next((p for p in uso["inactivas"] if p["usuario_final_id"] == nunca["id"]), None)
    assert m is not None and m["dias_sin_actividad"] is None


@pytest.mark.asyncio
async def test_uso_centro_aislado(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    from app.models import Centro, UsuarioStaff
    from app.security import hash_password
    async with Session() as db:
        c2 = Centro(nombre="Otro USO")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(centro_id=c2.id, nombre="Ajeno", rol="integradora",
                            email="ajeno_uso@trazo.local", password_hash=hash_password("trazo1234")))
        await db.commit()
    _, h2 = await _login(client, ("ajeno_uso@trazo.local", "trazo1234"))
    r = await client.get(f"/centros/{centro_id}/uso", headers=h2)
    assert r.status_code == 403, r.text
