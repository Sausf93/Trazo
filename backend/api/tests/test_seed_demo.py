"""El escenario de DEMO cobra vida: los datos sembrados alimentan la medición.

Regresión detectada en verificación (Ronda 2): el seed creaba los intentos por la
ruta vieja (estado='solo') sin fijar `resultado`, así que quedaban 'sin_valorar' y
la alerta estrella de declive nunca se disparaba y la evolución salía vacía.
"""
from __future__ import annotations

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client):
    r = await client.post("/auth/login",
                          data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    return {u["alias_interno"]: u for u in r.json()}


@pytest.mark.asyncio
async def test_demo_alerta_y_evolucion_vivas(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]["id"]

    # La serie descendente sembrada de Paco genera una alerta de praxias.
    r = await client.get(f"/usuarios/{paco}/alertas", headers=headers)
    assert r.status_code == 200, r.text
    alertas = r.json()
    assert any(a["bloque_afectado"] == "praxias" for a in alertas), \
        "el declive sembrado de Paco debería disparar una alerta de praxias"

    # Y su evolución NO está vacía (los intentos cuentan como resultado).
    r = await client.get(f"/usuarios/{paco}/evolucion?bloque=praxias", headers=headers)
    resumen = r.json()["resumen"]
    assert resumen["n_intentos"] > 0
    assert resumen["rendimiento_medio"] is not None
