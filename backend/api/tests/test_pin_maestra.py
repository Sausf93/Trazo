"""Login de la maestra en la tablet emparejada: elige su nombre y entra. Por
defecto sin PIN (solo eligiendo nombre); el PIN es un extra OPCIONAL. Se registra
igual que un login (mismo JWT), acota al centro de la tablet y frena la fuerza
bruta cuando hay PIN."""
from __future__ import annotations

import pytest

from app.models import Centro, UsuarioStaff
from app.security import hash_password

ADMIN = ("admin@trazo.local", "trazo1234")
INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client, cred):
    r = await client.post("/auth/login", data={"username": cred[0], "password": cred[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _tablet(client, admin_h):
    dev = (await client.post("/dispositivos", headers=admin_h,
                             json={"nombre": "Tablet 1", "rol": "participante"})).json()
    return {"X-Device-Token": dev["token"]}


@pytest.mark.asyncio
async def test_maestra_entra_eligiendo_nombre(client):
    _, admin_h = await _login(client, ADMIN)
    integ = next(s for s in (await client.get("/staff", headers=admin_h)).json()
                 if s["email"] == INTEGRADORA[0])
    dh = await _tablet(client, admin_h)

    # La tablet lista el equipo (nombre/rol/tiene_pin, sin email).
    equipo = (await client.get("/dispositivos/equipo", headers=dh)).json()
    yo = next(s for s in equipo if s["id"] == integ["id"])
    assert yo["tiene_pin"] is False and "email" not in yo
    # SEGURIDAD: el admin NO aparece en el selector de la tablet.
    assert all(s["rol"] != "admin_centro" for s in equipo)

    # Sin PIN puesto: elige su nombre y entra (mismo JWT que el login normal).
    r = await client.post("/auth/tablet", headers=dh, json={"staff_id": integ["id"]})
    assert r.status_code == 200, r.text
    assert r.json()["nombre"] and r.json()["access_token"]


@pytest.mark.asyncio
async def test_admin_no_entra_por_nombre_en_tablet(client):
    """Una tablet perdida no debe dar acceso de administración: el admin NO entra
    por /auth/tablet (usa email+contraseña)."""
    _, admin_h = await _login(client, ADMIN)
    admin = next(s for s in (await client.get("/staff", headers=admin_h)).json()
                 if s["rol"] == "admin_centro")
    dh = await _tablet(client, admin_h)
    r = await client.post("/auth/tablet", headers=dh, json={"staff_id": admin["id"]})
    assert r.status_code == 403, r.text


@pytest.mark.asyncio
async def test_pin_opcional(client):
    _, admin_h = await _login(client, ADMIN)
    integ = next(s for s in (await client.get("/staff", headers=admin_h)).json()
                 if s["email"] == INTEGRADORA[0])
    dh = await _tablet(client, admin_h)

    # El admin le pone un PIN (opcional).
    assert (await client.post(f"/staff/{integ['id']}/pin", headers=admin_h,
                              json={"pin": "1234"})).status_code == 204

    # Ahora entrar solo con el nombre no basta: pide PIN.
    r = await client.post("/auth/tablet", headers=dh, json={"staff_id": integ["id"]})
    assert r.status_code == 401
    # PIN correcto -> entra.
    r = await client.post("/auth/tablet", headers=dh, json={"staff_id": integ["id"], "pin": "1234"})
    assert r.status_code == 200
    # El admin lo quita -> vuelve a entrar solo con el nombre.
    assert (await client.delete(f"/staff/{integ['id']}/pin", headers=admin_h)).status_code == 204
    r = await client.post("/auth/tablet", headers=dh, json={"staff_id": integ["id"]})
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_tablet_login_no_cruza_centros(client, Session):
    _, admin_h = await _login(client, ADMIN)
    integ = next(s for s in (await client.get("/staff", headers=admin_h)).json()
                 if s["email"] == INTEGRADORA[0])

    async with Session() as db:
        c2 = Centro(nombre="Otro Tablet")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(centro_id=c2.id, nombre="Ajena", rol="integradora",
                            email="ajena_tab@trazo.local", password_hash=hash_password("trazo1234")))
        await db.commit()
    _, h2 = await _login(client, ("ajena_tab@trazo.local", "trazo1234"))
    dh2 = await _tablet(client, h2)

    # La tablet del centro B no ve a la integradora del A, ni la puede loguear.
    equipo = (await client.get("/dispositivos/equipo", headers=dh2)).json()
    assert integ["id"] not in {s["id"] for s in equipo}
    r = await client.post("/auth/tablet", headers=dh2, json={"staff_id": integ["id"]})
    assert r.status_code == 401
