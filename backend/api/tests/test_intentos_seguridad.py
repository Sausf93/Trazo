"""Seguridad de POST /sesiones/{id}/intentos: idempotencia, IDOR y participación.

Cubre los huecos detectados en auditoría:
- Reenviar el MISMO id (reenvío offline) devuelve el mismo intento (idempotente).
- Reenviar un id que pertenece a OTRO usuario/sesión no filtra ese intento (409).
- No se pueden registrar intentos para alguien que no participa en la sesión.
"""
from __future__ import annotations

import uuid

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


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    assert r.status_code == 200, r.text
    return {u["alias_interno"]: u for u in r.json()}


async def _un_ejercicio(client, headers):
    r = await client.get("/ejercicios?activo=true", headers=headers)
    assert r.status_code == 200, r.text
    ejercicios = r.json()
    assert ejercicios
    return ejercicios[0]


async def _crear_sesion(client, headers, participantes):
    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "nombre": "Sesión test",
              "participantes": participantes},
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _intento_body(intento_id, uf_id, sesion_id, ej_id):
    return {
        "id": intento_id,
        "usuario_final_id": uf_id,
        "sesion_id": sesion_id,
        "ejercicio_id": ej_id,
        "estado": "solo",
        "valores_json": {},
        "cantidad_objetivo_json": {},
    }


@pytest.mark.asyncio
async def test_reenvio_mismo_id_es_idempotente(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]["id"]
    ej = await _un_ejercicio(client, headers)
    sesion_id = await _crear_sesion(client, headers, [paco])

    iid = str(uuid.uuid4())
    body = _intento_body(iid, paco, sesion_id, ej["id"])
    r1 = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers, json=body)
    assert r1.status_code == 201, r1.text
    # Reenvío del MISMO id -> mismo intento, sin duplicar.
    r2 = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers, json=body)
    assert r2.status_code in (200, 201), r2.text
    assert r2.json()["id"] == iid


@pytest.mark.asyncio
async def test_id_ajeno_no_se_filtra(client):
    """Reutilizar el id de un intento de OTRO usuario no devuelve ese intento."""
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco, marisa = usuarios["Paco"]["id"], usuarios["Marisa"]["id"]
    ej = await _un_ejercicio(client, headers)
    sesion_id = await _crear_sesion(client, headers, [paco, marisa])

    iid = str(uuid.uuid4())
    # Intento legítimo de Paco.
    r1 = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                           json=_intento_body(iid, paco, sesion_id, ej["id"]))
    assert r1.status_code == 201, r1.text
    # Marisa intenta reusar el mismo id -> 409, NO se le devuelve el de Paco.
    r2 = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                           json=_intento_body(iid, marisa, sesion_id, ej["id"]))
    assert r2.status_code == 409, r2.text
    assert paco not in r2.text  # no filtra datos del otro usuario


@pytest.mark.asyncio
async def test_no_participante_rechazado(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco, marisa = usuarios["Paco"]["id"], usuarios["Marisa"]["id"]
    ej = await _un_ejercicio(client, headers)
    # Sesión SOLO con Paco.
    sesion_id = await _crear_sesion(client, headers, [paco])
    # Registrar un intento de Marisa (no participa) -> 403.
    r = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                          json=_intento_body(str(uuid.uuid4()), marisa, sesion_id, ej["id"]))
    assert r.status_code == 403, r.text
