"""Al dar de alta a una persona se le siembra un plan por defecto suave, para que
su tablet NUNCA aparezca vacía (evita el callejón sin salida del mayor)."""
from __future__ import annotations

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client):
    r = await client.post("/auth/login", data={"username": INTEGRADORA[0], "password": INTEGRADORA[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


@pytest.mark.asyncio
async def test_usuario_nuevo_nace_con_plan(client):
    _, headers = await _login(client)
    r = await client.post("/usuarios", headers=headers, json={"alias_interno": "Recién Alta"})
    assert r.status_code == 201, r.text
    uid = r.json()["id"]

    # Tiene plan sembrado (varias áreas base, activas) para una sesión ~20.
    plan = (await client.get(f"/usuarios/{uid}/plan", headers=headers)).json()
    activos = [ln for ln in plan if ln["activo"]]
    assert len(activos) >= 6, plan
    assert all(ln["tipo"] == "dominio" and ln["bloque"] for ln in activos)
    # La suma configurada de la sesión ronda las 20 actividades (en producción,
    # con el catálogo completo, la cola sale ~20; aquí el seed de test es mínimo).
    assert sum(ln["n_por_sesion"] for ln in activos) >= 18, activos

    # Y su cola NO está vacía (la tablet le pediría actividades).
    cola = (await client.get(f"/usuarios/{uid}/cola", headers=headers)).json()
    assert len(cola) >= 1, "la persona nueva debería tener actividades en la cola"
