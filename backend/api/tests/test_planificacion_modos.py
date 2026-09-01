"""Los TRES orígenes de actividad de una sesión (petición de Saulo):

1. PLANIFICADA por la psicóloga con antelación (rol nuevo `psicologa`, pauta el plan).
2. EN VIVO por la integradora (elige una actividad CONCRETA en el momento).
3. PROPUESTA por la app (cola con frescura: propone lo menos jugado; nunca sola).

Todo en local (SQLite en memoria), sin tocar producción.
"""
from __future__ import annotations

import pytest

ADMIN = ("admin@trazo.local", "trazo1234")


async def _login(client, cred):
    r = await client.post("/auth/login", data={"username": cred[0], "password": cred[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _tablet(client, admin_h):
    dev = (await client.post("/dispositivos", headers=admin_h,
                             json={"nombre": "Tablet 1", "rol": "participante"})).json()
    return {"X-Device-Token": dev["token"]}


async def _crear_usuario(client, headers, alias="Persona plan"):
    r = await client.post("/usuarios", headers=headers, json={"alias_interno": alias})
    assert r.status_code == 201, r.text
    uid = r.json()["id"]
    # Consentimiento (compuerta legal RGPD: sin él no se puede abrir sesión real).
    await client.post(f"/usuarios/{uid}/consentimiento", headers=headers,
                      json={"otorgado_por": "titular", "rol_otorgante": "titular"})
    return uid


# --------------------------------------------------------------------------
# MODO 1 — PLANIFICADA por la psicóloga
# --------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_psicologa_existe_planifica_y_entra_en_tablet(client):
    _, admin_h = await _login(client, ADMIN)

    # El admin da de alta a una psicóloga.
    r = await client.post("/staff", headers=admin_h, json={
        "nombre": "Dra. Ruiz", "email": "psico@trazo.local",
        "password": "trazo1234", "rol": "psicologa"})
    assert r.status_code == 201, r.text
    psico = r.json()
    assert psico["rol"] == "psicologa"

    # La psicóloga entra al PANEL con email/contraseña.
    _, psico_h = await _login(client, ("psico@trazo.local", "trazo1234"))

    # Y PLANIFICA: pauta el plan de una persona (queda persistido).
    uid = await _crear_usuario(client, psico_h, "Planificada")
    put = await client.put(f"/usuarios/{uid}/plan", headers=psico_h, json={"lineas": [
        {"tipo": "dominio", "bloque": "razonamiento", "nivel": "medio", "n_por_sesion": 2,
         "orden": 0, "activo": True},
    ]})
    assert put.status_code == 200, put.text
    plan = (await client.get(f"/usuarios/{uid}/plan", headers=psico_h)).json()
    assert any(l["bloque"] == "razonamiento" and l["nivel"] == "medio" for l in plan)

    # La psicóloga también puede FACILITAR en la tablet (aparece en el equipo y
    # entra por su nombre; no es admin).
    dh = await _tablet(client, admin_h)
    equipo = (await client.get("/dispositivos/equipo", headers=dh)).json()
    assert any(s["id"] == psico["id"] for s in equipo)
    r = await client.post("/auth/tablet", headers=dh, json={"staff_id": psico["id"]})
    assert r.status_code == 200, r.text


# --------------------------------------------------------------------------
# MODO 3 — PROPUESTA por la app (frescura: lo menos jugado primero)
# --------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_app_propone_actividades_frescas(client):
    _, admin_h = await _login(client, ADMIN)
    uid = await _crear_usuario(client, admin_h, "Propuesta")
    # Plan: un dominio con muchas actividades disponibles.
    await client.put(f"/usuarios/{uid}/plan", headers=admin_h, json={"lineas": [
        {"tipo": "dominio", "bloque": "razonamiento", "nivel": "medio", "n_por_sesion": 3,
         "orden": 0, "activo": True},
    ]})

    # La app propone 3 actividades CONCRETAS y DISTINTAS.
    prop1 = (await client.get(f"/usuarios/{uid}/propuesta?n=3", headers=admin_h)).json()
    ids1 = [p["ejercicio_id"] for p in prop1]
    assert len(ids1) == 3 and len(set(ids1)) == 3
    assert all(p["nivel"] == "medio" for p in prop1)

    # Se juega la PRIMERA propuesta (queda registrada) -> deja de ser la más fresca.
    ses = (await client.post("/sesiones", headers=admin_h, json={
        "tipo": "individual", "participantes": [uid]})).json()
    jugada = ids1[0]
    r = await client.post(f"/sesiones/{ses['id']}/intentos", headers=admin_h, json={
        "usuario_final_id": uid, "sesion_id": ses["id"], "ejercicio_id": jugada,
        "estado": "solo", "valores_json": {}})
    assert r.status_code == 201, r.text

    # Nueva propuesta: la ya jugada baja (frescura) y no vuelve a salir la primera.
    prop2 = (await client.get(f"/usuarios/{uid}/propuesta?n=3", headers=admin_h)).json()
    ids2 = [p["ejercicio_id"] for p in prop2]
    assert jugada not in ids2, "la actividad recién jugada debería ceder el sitio a otras frescas"
    assert ids2 != ids1, "la propuesta debe cambiar tras jugar (dinámica, no siempre igual)"


# --------------------------------------------------------------------------
# MODO 2 — EN VIVO: la integradora inyecta una actividad CONCRETA
# --------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_integradora_elige_actividad_concreta_en_vivo(client):
    _, admin_h = await _login(client, ADMIN)
    uid = await _crear_usuario(client, admin_h, "EnVivo")
    await client.put(f"/usuarios/{uid}/plan", headers=admin_h, json={"lineas": [
        {"tipo": "dominio", "bloque": "lenguaje", "nivel": "bajo", "n_por_sesion": 1,
         "orden": 0, "activo": True},
    ]})
    # Un ejercicio concreto que la integradora quiere mandar AHORA (de otro bloque).
    concreto = (await client.get(f"/usuarios/{uid}/propuesta?n=1", headers=admin_h)).json()
    # Elige uno de razonamiento (distinto de su plan de lenguaje) para que se note.
    ses = (await client.post("/sesiones", headers=admin_h, json={
        "tipo": "individual", "participantes": [uid]})).json()
    # Propuesta de razonamiento como fuente de un id concreto válido:
    admin_uid2 = await _crear_usuario(client, admin_h, "Fuente")
    await client.put(f"/usuarios/{admin_uid2}/plan", headers=admin_h, json={"lineas": [
        {"tipo": "dominio", "bloque": "razonamiento", "nivel": "medio", "n_por_sesion": 1,
         "orden": 0, "activo": True}]})
    eid = (await client.get(f"/usuarios/{admin_uid2}/propuesta?n=1", headers=admin_h)
           ).json()[0]["ejercicio_id"]

    # La integradora inyecta ESE ejercicio concreto en la sesión en curso.
    r = await client.patch(
        f"/sesiones/{ses['id']}/participantes/{uid}/mas", headers=admin_h,
        json={"nivel": "medio", "ejercicios": [eid]})
    assert r.status_code == 200, r.text

    # La cola de esa persona en esta sesión empieza por la actividad elegida.
    cola = (await client.get(
        f"/usuarios/{uid}/cola?sesion_id={ses['id']}", headers=admin_h)).json()
    assert cola["items"], "la cola no debería quedar vacía"
    primero = cola["items"][0]
    assert primero["ejercicio_id"] == eid
    assert primero["origen"] == "en_vivo"
    assert concreto  # sanity: la propuesta de 1 devolvió algo
