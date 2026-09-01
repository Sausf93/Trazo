"""Vigilancia de "dejar de participar" (missingness).

Guarda del neuropsicólogo: si una persona empieza a NO intentar las actividades
(se queda mirando, no toca), eso no puede caer en el olvido — debe generar aviso
propio, aunque su rendimiento en lo que sí hace parezca estable.
"""
from __future__ import annotations

import uuid

import pytest

from app.services.anomalias import detectar_missingness

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


def test_detector_unitario():
    # Baseline participa (0 sin intentar), luego deja de intentar -> desconexión.
    serie = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0]
    r = detectar_missingness(serie)
    assert r is not None and r.hay_desconexion
    # Siempre participó -> no dispara.
    assert not detectar_missingness([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]).hay_desconexion
    # Un único pico reciente (no sostenido) -> no dispara.
    assert not detectar_missingness([0.0, 0.0, 0.0, 0.0, 0.0, 1.0]).hay_desconexion


async def _login(client):
    r = await client.post("/auth/login",
                          data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


@pytest.mark.asyncio
async def test_dejar_de_participar_genera_alerta(client):
    login, headers = await _login(client)

    r = await client.post("/usuarios", headers=headers,
                          json={"alias_interno": "TestDesconexion", "nivel_base_json": {}})
    uf = r.json()
    # Consentimiento (compuerta legal RGPD: sin él no se puede abrir sesión real).
    await client.post(f"/usuarios/{uf['id']}/consentimiento", headers=headers,
                      json={"otorgado_por": "titular", "rol_otorgante": "titular"})
    ej = (await client.get("/ejercicios?bloque=praxias&activo=true", headers=headers)).json()[0]

    async def _sesion_con(puntos):
        r = await client.post("/sesiones", headers=headers,
                              json={"tipo": "individual", "participantes": [uf["id"]]})
        sid = r.json()["id"]
        await client.post(f"/sesiones/{sid}/intentos", headers=headers,
                          json={"id": str(uuid.uuid4()), "usuario_final_id": uf["id"],
                                "sesion_id": sid, "ejercicio_id": ej["id"],
                                "estado": "sin_valorar",
                                "valores_json": {"precision": 0.9, "puntos_capturados": puntos}})
        # Cerrar la sala antes de la siguiente: una persona no puede estar en dos
        # salas abiertas a la vez (aquí simulamos sesiones de días distintos).
        await client.patch(f"/sesiones/{sid}/cerrar", headers=headers)

    # 4 sesiones participando (trazo amplio) + 2 en las que no toca nada.
    for _ in range(4):
        await _sesion_con(20)
    for _ in range(2):
        await _sesion_con(0)  # puntos_capturados 0 -> no intentó

    r = await client.get(f"/usuarios/{uf['id']}/alertas", headers=headers)
    assert r.status_code == 200, r.text
    alertas = r.json()
    assert alertas, "dejar de participar debería generar una alerta"
    assert any("desconexion" in (a.get("contexto_json", {}).get("senal", ""))
               for a in alertas), "la alerta debe señalar la desconexión"
