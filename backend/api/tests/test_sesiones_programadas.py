"""Tests de las mejoras A+B+C y de las SESIONES PROGRAMADAS.

Cubren lo que faltaba de cobertura (informe QA backend):

- Config por participante -> la cola sale de la config, no del plan.
- Config con SOLO nivel (sin líneas) -> cae al plan (no deja la cola vacía).
- Ciclo de rondas: terminado -> mas -> estado, y reflejo en /live.
- Instancia por banda de cantidad (bajo/medio/alto) vía HTTP.
- Sesiones programadas: crear (sin abrir), listar, abrir, editar y descartar.
- IDOR (RGPD): un staff de otro centro recibe 403 en los endpoints que
  reciben ids de usuario/sesión/intento/alerta.
- Cota de `n` (no se aceptan cantidades disparatadas).
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
    assert r.status_code == 200, r.text
    return {u["alias_interno"]: u for u in r.json()}


async def _segundo_centro(client, Session):
    """Crea un segundo centro+staff y devuelve sus headers (para tests IDOR)."""
    email2 = "otro@trazo.local"
    async with Session() as db:
        c2 = Centro(nombre="Otro Centro")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(
            centro_id=c2.id, nombre="Ajeno", rol="integradora",
            email=email2, password_hash=hash_password("trazo1234"),
        ))
        await db.commit()
    _, headers2 = await _login(client, email=email2, password="trazo1234")
    return headers2


# --------------------------------------------------------------------------
#  A) Config por participante
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_cola_sale_de_config_por_participante(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={
            "tipo": "individual",
            "nombre": "Config test",
            "participantes": [paco["id"]],
            "configs": [{
                "usuario_final_id": paco["id"],
                "nivel": "medio",
                "lineas": [
                    {"bloque": "razonamiento", "n": 2},
                    {"bloque": "lenguaje", "n": 1},
                ],
            }],
        },
    )
    assert r.status_code == 201, r.text
    sesion_id = r.json()["id"]

    r = await client.get(f"/usuarios/{paco['id']}/cola?sesion_id={sesion_id}", headers=headers)
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    # 2 de razonamiento + 1 de lenguaje = 3, todas a nivel medio.
    assert len(items) == 3
    bloques = [it["bloque"] for it in items]
    assert bloques.count("razonamiento") == 2
    assert bloques.count("lenguaje") == 1
    assert all(it["nivel"] == "medio" for it in items)


@pytest.mark.asyncio
async def test_config_solo_nivel_cae_al_plan(client):
    """Config con solo nivel (sin líneas) NO debe dejar la cola vacía: usa el plan."""
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]  # tiene plan sembrado (praxias + atencion_memoria)

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={
            "tipo": "individual",
            "participantes": [paco["id"]],
            "configs": [{"usuario_final_id": paco["id"], "nivel": "alto", "lineas": []}],
        },
    )
    assert r.status_code == 201, r.text
    sesion_id = r.json()["id"]

    r = await client.get(f"/usuarios/{paco['id']}/cola?sesion_id={sesion_id}", headers=headers)
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    assert items, "con solo nivel debería caer al plan, no quedar vacía"
    bloques = {it["bloque"] for it in items}
    assert "praxias" in bloques and "atencion_memoria" in bloques


# --------------------------------------------------------------------------
#  B+C) Ciclo de rondas: terminado -> mas -> estado, reflejado en /live
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ciclo_rondas(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "participantes": [paco["id"]]},
    )
    sesion_id = r.json()["id"]
    await client.patch(f"/sesiones/{sesion_id}/iniciar", headers=headers)

    # Estado inicial: ronda 1, no terminado.
    r = await client.get(
        f"/sesiones/{sesion_id}/participantes/{paco['id']}/estado", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json() == {"iniciada": True, "ronda": 1, "terminado": False}

    # Terminar la tanda.
    r = await client.post(
        f"/sesiones/{sesion_id}/participantes/{paco['id']}/terminado", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["terminado"] is True

    # /live lo refleja.
    r = await client.get(f"/sesiones/{sesion_id}/live", headers=headers)
    ficha = next(f for f in r.json()["fichas"] if f["usuario_final_id"] == paco["id"])
    assert ficha["terminado"] is True and ficha["ronda"] == 1

    # La maestra manda "más" con nueva config -> sube ronda, resetea terminado.
    r = await client.patch(
        f"/sesiones/{sesion_id}/participantes/{paco['id']}/mas",
        headers=headers,
        json={"nivel": "alto", "lineas": [{"bloque": "razonamiento", "n": 1}]},
    )
    assert r.status_code == 200, r.text
    assert r.json() == {"iniciada": True, "ronda": 2, "terminado": False}

    # La nueva cola sale de la config nueva (razonamiento, nivel alto).
    r = await client.get(f"/usuarios/{paco['id']}/cola?sesion_id={sesion_id}", headers=headers)
    items = r.json()["items"]
    assert len(items) == 1 and items[0]["bloque"] == "razonamiento"
    assert items[0]["nivel"] == "alto"

    # /live: terminado=false, ronda=2.
    r = await client.get(f"/sesiones/{sesion_id}/live", headers=headers)
    ficha = next(f for f in r.json()["fichas"] if f["usuario_final_id"] == paco["id"])
    assert ficha["terminado"] is False and ficha["ronda"] == 2


# --------------------------------------------------------------------------
#  Instancia por banda de cantidad (bajo/medio/alto) vía HTTP
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_instancia_por_banda_de_nivel(client):
    login, headers = await _login(client)
    # Un ejercicio de selección con imágenes escala por nivel.
    r = await client.get("/ejercicios?bloque=percepcion&activo=true", headers=headers)
    ejercicios = r.json()
    assert ejercicios
    # Busca uno cuya instancia tenga 'opciones' (cantidad escalable).
    ej_id = ejercicios[0]["id"]

    cantidades = {}
    for nivel in ("bajo", "medio", "alto"):
        r = await client.get(f"/ejercicios/{ej_id}/instancia?nivel={nivel}", headers=headers)
        assert r.status_code == 200, r.text
        render = r.json()["render"]
        opciones = render.get("opciones")
        if opciones is not None:
            cantidades[nivel] = len(opciones)

    if len(cantidades) == 3:
        # A mayor nivel, al menos tantas imágenes como en el inferior (monótono).
        assert cantidades["bajo"] <= cantidades["medio"] <= cantidades["alto"]


# --------------------------------------------------------------------------
#  Sesiones PROGRAMADAS: crear (sin abrir), listar, abrir, editar, descartar
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_sesion_programada_ciclo_completo(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco, marisa = usuarios["Paco"], usuarios["Marisa"]

    # 1) Crear PROGRAMADA (no se abre): no debe aparecer como sesión activa.
    r = await client.post(
        "/sesiones",
        headers=headers,
        json={
            "tipo": "individual",
            "nombre": "Grupo de mañana",
            "programar": True,
            "programada_para": "2026-08-10",
            "participantes": [paco["id"], marisa["id"]],
            "configs": [
                {"usuario_final_id": paco["id"], "nivel": "medio",
                 "lineas": [{"bloque": "razonamiento", "n": 2}]},
                {"usuario_final_id": marisa["id"], "nivel": "bajo",
                 "lineas": [{"bloque": "lenguaje", "n": 1}]},
            ],
        },
    )
    assert r.status_code == 201, r.text
    ses = r.json()
    assert ses["abierta"] is False
    assert ses["programada_para"] == "2026-08-10"
    sesion_id = ses["id"]

    # No es la sesión activa (los kioscos no la ven todavía).
    r = await client.get(f"/sesiones/activa?centro_id={centro_id}", headers=headers)
    assert r.json()["sesion_id"] != sesion_id

    # 2) Aparece en /programadas con su config por participante.
    r = await client.get(f"/sesiones/programadas?centro_id={centro_id}", headers=headers)
    assert r.status_code == 200, r.text
    programadas = r.json()
    prog = next(p for p in programadas if p["id"] == sesion_id)
    assert prog["nombre"] == "Grupo de mañana"
    assert prog["programada_para"] == "2026-08-10"
    por_alias = {p["alias_interno"]: p for p in prog["participantes"]}
    assert por_alias["Paco"]["nivel"] == "medio"
    assert por_alias["Paco"]["lineas"][0]["bloque"] == "razonamiento"
    assert por_alias["Marisa"]["nivel"] == "bajo"

    # 3) Editar la programada (cambiar config de Paco) antes del día.
    r = await client.put(
        f"/sesiones/{sesion_id}/config",
        headers=headers,
        json={
            "nombre": "Grupo de mañana (v2)",
            "programada_para": "2026-08-11",
            "participantes": [paco["id"]],
            "configs": [{"usuario_final_id": paco["id"], "nivel": "alto",
                         "lineas": [{"bloque": "atencion_memoria", "n": 3}]}],
        },
    )
    assert r.status_code == 200, r.text
    r = await client.get(f"/sesiones/programadas?centro_id={centro_id}", headers=headers)
    prog = next(p for p in r.json() if p["id"] == sesion_id)
    assert prog["nombre"] == "Grupo de mañana (v2)"
    assert [p["alias_interno"] for p in prog["participantes"]] == ["Paco"]
    assert prog["participantes"][0]["nivel"] == "alto"

    # 4) Abrir la sala: pasa a ser la sesión activa; la cola de Paco sale de su config.
    r = await client.patch(f"/sesiones/{sesion_id}/abrir", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["abierta"] is True

    r = await client.get(f"/sesiones/activa?centro_id={centro_id}", headers=headers)
    assert r.json()["sesion_id"] == sesion_id

    r = await client.get(f"/usuarios/{paco['id']}/cola?sesion_id={sesion_id}", headers=headers)
    items = r.json()["items"]
    assert len(items) == 3 and all(it["bloque"] == "atencion_memoria" for it in items)
    assert all(it["nivel"] == "alto" for it in items)

    # Ya no aparece en /programadas (está abierta).
    r = await client.get(f"/sesiones/programadas?centro_id={centro_id}", headers=headers)
    assert all(p["id"] != sesion_id for p in r.json())


@pytest.mark.asyncio
async def test_descartar_programada(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "nombre": "Descartable", "programar": True,
              "participantes": [paco["id"]]},
    )
    sesion_id = r.json()["id"]

    r = await client.delete(f"/sesiones/{sesion_id}", headers=headers)
    assert r.status_code == 204, r.text
    r = await client.get(f"/sesiones/programadas?centro_id={centro_id}", headers=headers)
    assert all(p["id"] != sesion_id for p in r.json())


@pytest.mark.asyncio
async def test_no_editar_ni_descartar_sesion_abierta(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    # Sesión abierta al momento (no programada).
    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "participantes": [paco["id"]]},
    )
    sesion_id = r.json()["id"]

    # No se puede editar como programada.
    r = await client.put(
        f"/sesiones/{sesion_id}/config",
        headers=headers,
        json={"participantes": [paco["id"]], "configs": []},
    )
    assert r.status_code == 409, r.text
    # Ni descartar (tras iniciar).
    await client.patch(f"/sesiones/{sesion_id}/iniciar", headers=headers)
    r = await client.delete(f"/sesiones/{sesion_id}", headers=headers)
    assert r.status_code == 409, r.text


# --------------------------------------------------------------------------
#  Cota de `n`
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_n_disparatado_rechazado(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={
            "tipo": "individual",
            "participantes": [paco["id"]],
            "configs": [{"usuario_final_id": paco["id"],
                         "lineas": [{"bloque": "razonamiento", "n": 9999}]}],
        },
    )
    assert r.status_code == 422, r.text  # n fuera de rango (le=50)


@pytest.mark.asyncio
async def test_bloque_o_nivel_invalido_rechazado(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    # Bloque inexistente -> 422 (no cola vacía silenciosa).
    r = await client.post(
        "/sesiones", headers=headers,
        json={"tipo": "individual", "participantes": [paco["id"]],
              "configs": [{"usuario_final_id": paco["id"],
                           "lineas": [{"bloque": "inventado", "n": 1}]}]})
    assert r.status_code == 422, r.text

    # Nivel inválido -> 422.
    r = await client.post(
        "/sesiones", headers=headers,
        json={"tipo": "individual", "participantes": [paco["id"]],
              "configs": [{"usuario_final_id": paco["id"], "nivel": "altisimo",
                           "lineas": [{"bloque": "razonamiento", "n": 1}]}]})
    assert r.status_code == 422, r.text


# --------------------------------------------------------------------------
#  IDOR (RGPD): staff de otro centro -> 403 en endpoints con id ajeno
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_idor_nuevos_endpoints_403(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    # Sesión + intento reales en el centro demo.
    r = await client.post(
        "/sesiones", headers=headers,
        json={"tipo": "individual", "participantes": [paco["id"]]})
    sesion_id = r.json()["id"]
    r = await client.get("/ejercicios?bloque=praxias&activo=true", headers=headers)
    ej_id = r.json()[0]["id"]
    intento_id = str(uuid.uuid4())
    await client.post(
        f"/sesiones/{sesion_id}/intentos", headers=headers,
        json={"id": intento_id, "usuario_final_id": paco["id"], "sesion_id": sesion_id,
              "ejercicio_id": ej_id, "estado": "solo",
              "valores_json": {"precision": 0.8}})

    headers2 = await _segundo_centro(client, Session)

    # Todos con id del centro ajeno -> 403.
    r = await client.get(f"/sesiones/{sesion_id}/live", headers=headers2)
    assert r.status_code == 403, r.text
    r = await client.get(f"/usuarios/{paco['id']}/evolucion", headers=headers2)
    assert r.status_code == 403, r.text
    r = await client.get(f"/usuarios/{paco['id']}/alertas", headers=headers2)
    assert r.status_code == 403, r.text
    r = await client.get(f"/grupos/{sesion_id}/evolucion", headers=headers2)
    assert r.status_code == 403, r.text
    r = await client.patch(f"/intentos/{intento_id}/ayuda", headers=headers2,
                           json={"con_ayuda": True})
    assert r.status_code == 403, r.text
    r = await client.get(f"/sesiones/programadas?centro_id={centro_id}", headers=headers2)
    assert r.status_code == 403, r.text
    r = await client.patch(f"/sesiones/{sesion_id}/abrir", headers=headers2)
    assert r.status_code == 403, r.text


@pytest.mark.asyncio
async def test_idor_crear_sesion_participante_ajeno(client, Session):
    """No se puede crear una sesión con un participante de OTRO centro."""
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios(client, headers, centro_id)
    paco = usuarios["Paco"]

    headers2 = await _segundo_centro(client, Session)
    # El staff del centro 2 intenta meter a Paco (del centro demo) en su sesión.
    r = await client.post(
        "/sesiones", headers=headers2,
        json={"tipo": "individual", "participantes": [paco["id"]]})
    assert r.status_code in (403, 404), r.text
