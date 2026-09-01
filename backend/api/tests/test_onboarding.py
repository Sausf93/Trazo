"""Asistente de puesta en marcha: refleja el estado real del centro."""
import pytest


async def _login(client, email="admin@trazo.local", pw="trazo1234"):
    r = await client.post("/auth/login", data={"username": email, "password": pw})
    assert r.status_code == 200, r.text
    return {"Authorization": "Bearer " + r.json()["access_token"]}


@pytest.mark.asyncio
async def test_puesta_en_marcha_centro_demo(client):
    h = await _login(client)
    r = await client.get("/puesta-en-marcha", headers=h)
    assert r.status_code == 200, r.text
    d = r.json()
    # El seed deja el centro demo bien montado:
    assert d["equipo_ok"] is True          # hay integradora
    assert d["tablets_ok"] is True         # 3 tablets emparejadas
    assert d["dpa_ok"] is True             # DPA sembrado
    assert d["n_personas"] >= 1
    assert d["personas_sin_consentimiento"] == 0  # todos con consentimiento
    assert d["suscripcion_ok"] is True     # prueba/cortesia
    assert d["primera_sesion_ok"] is True  # el seed crea sesiones


@pytest.mark.asyncio
async def test_puesta_en_marcha_detecta_falta_consentimiento(client):
    h = await _login(client)
    # Persona nueva SIN consentimiento -> debe contarla como pendiente.
    r = await client.post("/usuarios", headers=h, json={"alias_interno": "Sin consent"})
    assert r.status_code == 201
    d = (await client.get("/puesta-en-marcha", headers=h)).json()
    assert d["personas_sin_consentimiento"] >= 1
    assert d["personas_ok"] is False
