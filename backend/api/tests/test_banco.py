"""Banco de pruebas: guardar/listar veredictos con token compartido."""
import pytest

TOK = {"X-Lab-Token": "trazo-lab-2026"}


@pytest.mark.asyncio
async def test_token_obligatorio(client):
    # Sin token -> 401.
    assert (await client.get("/banco/veredictos")).status_code == 401
    assert (await client.post("/banco/veredictos", json={"actividad": "X", "estado": "revisar"})).status_code == 401


@pytest.mark.asyncio
async def test_guardar_listar_upsert(client):
    r = await client.post("/banco/veredictos", headers=TOK, json={
        "actividad": "Memoria de figuras", "estado": "revisar",
        "nota": "el sol es dibujo", "marcado_por": "Saulo"})
    assert r.status_code == 201, r.text

    # Otra persona marca la misma actividad -> entrada separada.
    await client.post("/banco/veredictos", headers=TOK, json={
        "actividad": "Memoria de figuras", "estado": "otro_grupo",
        "nota": "iría a percepción", "marcado_por": "Laura"})

    lst = (await client.get("/banco/veredictos", headers=TOK)).json()
    assert len(lst) == 2
    assert {x["marcado_por"] for x in lst} == {"Saulo", "Laura"}

    # Upsert: Saulo re-marca -> sigue habiendo 2 (no duplica).
    await client.post("/banco/veredictos", headers=TOK, json={
        "actividad": "Memoria de figuras", "estado": "revisar",
        "nota": "actualizado", "marcado_por": "Saulo"})
    lst2 = (await client.get("/banco/veredictos", headers=TOK)).json()
    assert len(lst2) == 2
    saulo = [x for x in lst2 if x["marcado_por"] == "Saulo"][0]
    assert saulo["nota"] == "actualizado"
