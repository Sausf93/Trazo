"""Equipo del centro (nivel 1) y alta de centros por plataforma (nivel 0)."""
from __future__ import annotations

import pytest

from app.config import settings

ADMIN = ("admin@trazo.local", "trazo1234")
INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client, cred):
    r = await client.post("/auth/login",
                          data={"username": cred[0], "password": cred[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


@pytest.mark.asyncio
async def test_admin_da_de_alta_integradora_y_esta_puede_entrar(client):
    _, admin_h = await _login(client, ADMIN)

    # Alta de una maestra nueva.
    r = await client.post("/staff", headers=admin_h, json={
        "nombre": "Nuria", "email": "nuria@trazo.local", "password": "clave1234",
    })
    assert r.status_code == 201, r.text
    creada = r.json()
    assert creada["rol"] == "integradora"
    assert creada["activo"] is True

    # Aparece en el listado del equipo.
    r = await client.get("/staff", headers=admin_h)
    assert r.status_code == 200
    emails = {s["email"] for s in r.json()}
    assert "nuria@trazo.local" in emails

    # Y puede iniciar sesión.
    _, nuria_h = await _login(client, ("nuria@trazo.local", "clave1234"))
    assert nuria_h["Authorization"].startswith("Bearer ")


@pytest.mark.asyncio
async def test_email_duplicado_da_409(client):
    _, admin_h = await _login(client, ADMIN)
    r = await client.post("/staff", headers=admin_h, json={
        "nombre": "Otra", "email": "integradora@trazo.local", "password": "clave1234",
    })
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_integradora_no_puede_gestionar_equipo(client):
    _, integ_h = await _login(client, INTEGRADORA)
    r = await client.get("/staff", headers=integ_h)
    assert r.status_code == 403
    r = await client.post("/staff", headers=integ_h, json={
        "nombre": "X", "email": "x@trazo.local", "password": "clave1234",
    })
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_admin_no_puede_darse_de_baja_a_si_mismo(client):
    _, admin_h = await _login(client, ADMIN)
    # id del propio admin: lo sacamos del listado por email.
    r = await client.get("/staff", headers=admin_h)
    admin_id = next(s["id"] for s in r.json() if s["email"] == ADMIN[0])
    r = await client.patch(f"/staff/{admin_id}", headers=admin_h, json={"activo": False})
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_baja_de_integradora(client):
    _, admin_h = await _login(client, ADMIN)
    r = await client.get("/staff", headers=admin_h)
    integ_id = next(s["id"] for s in r.json() if s["email"] == INTEGRADORA[0])
    r = await client.patch(f"/staff/{integ_id}", headers=admin_h, json={"activo": False})
    assert r.status_code == 200
    assert r.json()["activo"] is False
    # Dada de baja, ya no puede entrar.
    r = await client.post("/auth/login",
                          data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    assert r.status_code == 401


# ---- Plataforma (nivel 0) ----

@pytest.mark.asyncio
async def test_plataforma_deshabilitada_sin_token(client):
    # Por defecto no hay PLATFORM_TOKEN -> el endpoint no existe (404).
    r = await client.post("/plataforma/centros", json={
        "centro": "Centro Nuevo", "email": "a@b.com", "password": "clave1234",
    })
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_plataforma_crea_centro_con_token(client, monkeypatch):
    monkeypatch.setattr(settings, "platform_token", "secreto-plataforma")
    # Sin cabecera -> 401.
    r = await client.post("/plataforma/centros", json={
        "centro": "Centro Nuevo", "email": "jefe@nuevo.local", "password": "clave1234",
    })
    assert r.status_code == 401
    # Con cabecera correcta -> crea centro + admin.
    r = await client.post("/plataforma/centros",
                          headers={"X-Platform-Token": "secreto-plataforma"},
                          json={"centro": "Centro Nuevo", "email": "jefe@nuevo.local",
                                "password": "clave1234", "nombre": "Jefe"})
    assert r.status_code == 200, r.text
    assert r.json()["creado"] is True
    # El nuevo admin puede iniciar sesión.
    _, _ = await _login(client, ("jefe@nuevo.local", "clave1234"))
