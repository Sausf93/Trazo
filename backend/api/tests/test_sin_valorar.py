"""Un intento 'sin_valorar' no cuenta como acierto: se excluye del rendimiento
y de la evolución, y se contabiliza aparte en el resumen.

Cierra el sesgo de medición señalado por tres revisores (psicólogo, terapeuta
ocupacional e integradora): antes el intento nacía como 'solo' (=1.0) y la
media se inflaba si la integradora no marcaba a tiempo.
"""
from __future__ import annotations

import uuid

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client):
    r = await client.post("/auth/login",
                          data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    return {u["alias_interno"]: u for u in r.json()}


@pytest.mark.asyncio
async def test_sin_valorar_no_infla_ni_alerta(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]["id"]
    ej = (await client.get("/ejercicios?activo=true", headers=headers)).json()[0]

    r = await client.post("/sesiones", headers=headers,
                          json={"tipo": "individual", "nombre": "S",
                                "participantes": [paco]})
    sesion_id = r.json()["id"]

    # Estado de evolución ANTES (Paco trae histórico de demo).
    antes = (await client.get(f"/usuarios/{paco}/evolucion", headers=headers)).json()["resumen"]

    # Intento SIN VALORAR (como lo manda el kiosco por defecto).
    r = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                          json={"id": str(uuid.uuid4()), "usuario_final_id": paco,
                                "sesion_id": sesion_id, "ejercicio_id": ej["id"],
                                "estado": "sin_valorar", "valores_json": {},
                                "cantidad_objetivo_json": {}})
    assert r.status_code == 201, r.text

    # Evolución: el sin_valorar NO cambia el rendimiento; solo suma en su contador.
    despues = (await client.get(f"/usuarios/{paco}/evolucion", headers=headers)).json()["resumen"]
    assert despues["n_intentos"] == antes["n_intentos"]  # no entra como acierto
    assert despues["rendimiento_medio"] == antes["rendimiento_medio"]  # media intacta
    assert despues["n_sin_valorar"] == antes.get("n_sin_valorar", 0) + 1

    # Resumen de sesión: aparece como sin_valorar, no como acierto.
    r = await client.get(f"/sesiones/{sesion_id}/resumen", headers=headers)
    ficha = next(f for f in r.json()["fichas"] if f["usuario_final_id"] == paco)
    assert ficha["sin_valorar"] == 1
    assert ficha["solo"] == 0
    assert ficha["n_intentos"] == 0
