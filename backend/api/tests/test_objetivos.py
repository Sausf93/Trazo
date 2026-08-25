"""Objetivos/metas por paciente: CRUD, situación actual vs objetivo, y aislamiento."""
from __future__ import annotations

import uuid

import pytest

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


async def _login(client, cred=INTEGRADORA):
    r = await client.post("/auth/login", data={"username": cred[0], "password": cred[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    return {u["alias_interno"]: u for u in r.json()}


@pytest.mark.asyncio
async def test_objetivo_crud_y_situacion(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    paco = (await _usuarios(client, headers, centro_id))["Paco"]

    # Crear objetivo en un área.
    r = await client.post(f"/usuarios/{paco['id']}/objetivos", headers=headers,
                          json={"bloque": "razonamiento", "descripcion": "mantener el cálculo",
                                "objetivo_desempeno": 0.7})
    assert r.status_code == 201, r.text
    obj = r.json()
    assert obj["bloque"] == "razonamiento" and obj["objetivo_desempeno"] == 0.7
    # 'cumple' y 'situacion_actual' pueden ser null si no hay valorados en esa área.
    assert "situacion_actual" in obj and "cumple" in obj

    # Aparece en el listado.
    r = await client.get(f"/usuarios/{paco['id']}/objetivos", headers=headers)
    assert any(o["id"] == obj["id"] for o in r.json())

    # Editar objetivo.
    r = await client.patch(f"/objetivos/{obj['id']}", headers=headers,
                           json={"objetivo_desempeno": 0.5, "descripcion": "recuperar participación"})
    assert r.status_code == 200 and r.json()["objetivo_desempeno"] == 0.5

    # Un segundo objetivo ACTIVO en la MISMA área -> 409 (editar el existente).
    r = await client.post(f"/usuarios/{paco['id']}/objetivos", headers=headers,
                          json={"bloque": "razonamiento", "objetivo_desempeno": 0.8})
    assert r.status_code == 409, r.text

    # Área inválida -> 422; objetivo fuera de [0,1] -> 422.
    r = await client.post(f"/usuarios/{paco['id']}/objetivos", headers=headers,
                          json={"bloque": "inventada", "objetivo_desempeno": 0.5})
    assert r.status_code == 422
    r = await client.post(f"/usuarios/{paco['id']}/objetivos", headers=headers,
                          json={"bloque": "razonamiento", "objetivo_desempeno": 1.5})
    assert r.status_code == 422

    # Borrar.
    r = await client.delete(f"/objetivos/{obj['id']}", headers=headers)
    assert r.status_code == 204
    r = await client.get(f"/usuarios/{paco['id']}/objetivos", headers=headers)
    assert all(o["id"] != obj["id"] for o in r.json())


@pytest.mark.asyncio
async def test_objetivo_situacion_refleja_desempeno(client):
    """Tras registrar intentos logrados en un área, la situación actual sube."""
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    paco = (await _usuarios(client, headers, centro_id))["Paco"]
    ejs = (await client.get("/ejercicios?bloque=praxias&activo=true", headers=headers)).json()
    ej = ejs[0]

    r = await client.post(f"/usuarios/{paco['id']}/objetivos", headers=headers,
                          json={"bloque": "praxias", "objetivo_desempeno": 0.5})
    obj_id = r.json()["id"]

    # Registrar un intento y marcarlo logrado (cuenta como desempeño 1.0).
    r = await client.post("/sesiones", headers=headers,
                          json={"tipo": "individual", "participantes": [paco["id"]]})
    sesion_id = r.json()["id"]
    intento_id = str(uuid.uuid4())
    await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers,
                      json={"id": intento_id, "usuario_final_id": paco["id"], "sesion_id": sesion_id,
                            "ejercicio_id": ej["id"], "estado": "sin_valorar",
                            "valores_json": {}, "cantidad_objetivo_json": {}})
    await client.patch(f"/intentos/{intento_id}/resultado", headers=headers,
                       json={"resultado": "logrado"})

    r = await client.get(f"/usuarios/{paco['id']}/objetivos", headers=headers)
    o = next(x for x in r.json() if x["id"] == obj_id)
    assert o["situacion_actual"] is not None and o["n_valorados"] >= 1


@pytest.mark.asyncio
async def test_objetivo_aislado_por_centro(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    paco = (await _usuarios(client, headers, centro_id))["Paco"]
    r = await client.post(f"/usuarios/{paco['id']}/objetivos", headers=headers,
                          json={"bloque": "razonamiento", "objetivo_desempeno": 0.6})
    obj_id = r.json()["id"]

    from app.models import Centro, UsuarioStaff
    from app.security import hash_password
    async with Session() as db:
        c2 = Centro(nombre="Otro C")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(centro_id=c2.id, nombre="Ajeno", rol="integradora",
                            email="ajeno3@trazo.local", password_hash=hash_password("trazo1234")))
        await db.commit()
    _, h2 = await _login(client, ("ajeno3@trazo.local", "trazo1234"))
    # No puede ver ni tocar objetivos de otra persona/centro.
    r = await client.get(f"/usuarios/{paco['id']}/objetivos", headers=h2)
    assert r.status_code == 403
    r = await client.delete(f"/objetivos/{obj_id}", headers=h2)
    assert r.status_code == 403
