"""Tests de la autenticación por TOKEN DE DISPOSITIVO (kiosco emparejado).

La tablet del participante no hace login: se empareja al centro una vez y usa su
token en la cabecera `X-Device-Token`. Debe poder operar los endpoints de kiosco
(sesión activa, cola, instancia, registrar intento, estado/terminado) sin JWT de
staff, y respetando el aislamiento por centro (RGPD). El login de staff sigue
funcionando igual (aditivo).
"""
from __future__ import annotations

import uuid

import pytest

from app.models import Centro, UsuarioStaff
from app.security import hash_password

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client, email=INTEGRADORA[0], password=INTEGRADORA[1]):
    r = await client.post("/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200, r.text
    body = r.json()
    return body, {"Authorization": f"Bearer {body['access_token']}"}


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    return {u["alias_interno"]: u for u in r.json()}


async def _crear_dispositivo(client, headers, nombre="Tablet 1"):
    r = await client.post("/dispositivos", headers=headers,
                          json={"nombre": nombre, "rol": "participante"})
    assert r.status_code == 201, r.text
    return r.json()  # incluye token


@pytest.mark.asyncio
async def test_kiosco_opera_con_token_de_dispositivo(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    disp = await _crear_dispositivo(client, headers)
    dev = {"X-Device-Token": disp["token"]}  # SIN Authorization

    # La tablet valida su token y descubre su centro.
    r = await client.get("/dispositivos/yo", headers=dev)
    assert r.status_code == 200, r.text
    assert r.json()["centro_id"] == centro_id
    assert r.json()["rol"] == "participante"

    # Sesión creada por la maestra (con login), iniciada.
    r = await client.post("/sesiones", headers=headers,
                          json={"tipo": "individual", "participantes": [paco["id"]]})
    sesion_id = r.json()["id"]
    await client.patch(f"/sesiones/{sesion_id}/iniciar", headers=headers)

    # La tablet (solo token de dispositivo) descubre la sala activa.
    r = await client.get(f"/sesiones/activa?centro_id={centro_id}", headers=dev)
    assert r.status_code == 200, r.text
    assert r.json()["sesion_id"] == sesion_id

    # Pide la cola y una instancia sin login de staff.
    r = await client.get(f"/usuarios/{paco['id']}/cola?sesion_id={sesion_id}", headers=dev)
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    assert items
    r = await client.get(f"/ejercicios/{items[0]['ejercicio_id']}/instancia", headers=dev)
    assert r.status_code == 200, r.text

    # Registra un intento (medición) con el token de dispositivo.
    r = await client.post(f"/sesiones/{sesion_id}/intentos", headers=dev,
                          json={"id": str(uuid.uuid4()), "usuario_final_id": paco["id"],
                                "sesion_id": sesion_id, "ejercicio_id": items[0]["ejercicio_id"],
                                "estado": "solo", "valores_json": {"precision": 0.9}})
    assert r.status_code in (200, 201), r.text

    # Marca terminado y consulta estado con el token.
    r = await client.post(f"/sesiones/{sesion_id}/participantes/{paco['id']}/terminado", headers=dev)
    assert r.status_code == 200, r.text
    r = await client.get(f"/sesiones/{sesion_id}/participantes/{paco['id']}/estado", headers=dev)
    assert r.json()["terminado"] is True


@pytest.mark.asyncio
async def test_token_invalido_o_revocado_401(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]

    # Token inexistente.
    r = await client.get("/dispositivos/yo", headers={"X-Device-Token": "no-existe"})
    assert r.status_code == 401, r.text
    r = await client.get(f"/sesiones/activa?centro_id={centro_id}",
                         headers={"X-Device-Token": "no-existe"})
    assert r.status_code == 401, r.text

    # Token válido pero revocado -> 401.
    disp = await _crear_dispositivo(client, headers)
    r = await client.patch(f"/dispositivos/{disp['id']}/revocar", headers=headers)
    assert r.status_code == 200, r.text
    r = await client.get("/dispositivos/yo", headers={"X-Device-Token": disp["token"]})
    assert r.status_code == 401, r.text


@pytest.mark.asyncio
async def test_dispositivo_no_cruza_centros_403(client, Session):
    # Centro demo + su dispositivo.
    login, headers = await _login(client)
    centro_demo = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_demo)
    paco = usuarios["Paco"]

    # Segundo centro con su propio dispositivo.
    async with Session() as db:
        c2 = Centro(nombre="Otro Centro")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(centro_id=c2.id, nombre="Ajeno", rol="integradora",
                            email="otro@trazo.local", password_hash=hash_password("trazo1234")))
        await db.commit()
    _, headers2 = await _login(client, email="otro@trazo.local", password="trazo1234")
    disp2 = await _crear_dispositivo(client, headers2, nombre="Tablet centro 2")
    dev2 = {"X-Device-Token": disp2["token"]}

    # La tablet del centro 2 NO puede leer la cola de Paco (centro demo).
    r = await client.get(f"/usuarios/{paco['id']}/cola", headers=dev2)
    assert r.status_code == 403, r.text
    # Ni la sesión activa del centro demo.
    r = await client.get(f"/sesiones/activa?centro_id={centro_demo}", headers=dev2)
    assert r.status_code == 403, r.text
