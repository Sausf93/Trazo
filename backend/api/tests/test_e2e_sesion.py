"""Tests END-TO-END del flujo real de una sesión de Trazo.

Ejercen la app FastAPI COMPLETA (routers + servicios + BD) sobre una base de
datos SQLite temporal sembrada con los datos de demo, usando transporte ASGI de
httpx (en proceso, sin puertos). El objetivo es dar confianza de que "las
actividades funcionan y las mediciones se registran" recorriendo el camino real:

  login -> abrir sala -> iniciar -> cola -> instancia -> registrar intento ->
  marcar con ayuda -> idempotencia -> live -> cerrar,

más detección de anomalías/alertas, sugerencias de nivel y seguridad básica
(401 sin token, 403 entre centros — IDOR).

Cada test recibe un `client` con su propia BD sembrada (fixtures en conftest.py).
"""
from __future__ import annotations

import uuid

import pytest

from app.models import Centro, UsuarioStaff
from app.security import hash_password

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


# --------------------------------------------------------------------------
#  Helpers
# --------------------------------------------------------------------------

async def _login(client, email=INTEGRADORA[0], password=INTEGRADORA[1]):
    r = await client.post("/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200, r.text
    body = r.json()
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    return body, headers


async def _usuarios_por_alias(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    assert r.status_code == 200, r.text
    return {u["alias_interno"]: u for u in r.json()}


async def _ejercicio_de_bloque(client, headers, bloque):
    r = await client.get(f"/ejercicios?bloque={bloque}&activo=true", headers=headers)
    assert r.status_code == 200, r.text
    ejercicios = r.json()
    assert ejercicios, f"no hay ejercicios en el bloque {bloque}"
    return ejercicios[0]


# --------------------------------------------------------------------------
#  1-9: flujo feliz completo de una sesión
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_flujo_completo_sesion(client):
    # 1) Login de la integradora demo -> token + centro_id.
    login, headers = await _login(client)
    assert login["rol"] == "integradora"
    assert login["centro_id"]
    centro_id = login["centro_id"]

    usuarios = await _usuarios_por_alias(client, headers, centro_id)
    assert "Paco" in usuarios and "Marisa" in usuarios
    paco = usuarios["Paco"]

    # 2) Abrir sala: crear sesión con nombre + participantes.
    r = await client.post(
        "/sesiones",
        headers=headers,
        json={
            "tipo": "grupo",
            "nombre": "Grupo tarde",
            "participantes": [usuarios["Paco"]["id"], usuarios["Marisa"]["id"]],
        },
    )
    assert r.status_code == 201, r.text
    sesion = r.json()
    sesion_id = sesion["id"]
    assert sesion["cerrada"] is False and sesion["iniciada"] is False

    # Aparece en /sesiones/activa con iniciada=false y sus participantes.
    r = await client.get(f"/sesiones/activa?centro_id={centro_id}", headers=headers)
    assert r.status_code == 200, r.text
    activa = r.json()
    assert activa["sesion_id"] == sesion_id
    assert activa["nombre"] == "Grupo tarde"
    assert activa["iniciada"] is False
    alias_activos = {p["alias_interno"] for p in activa["participantes"]}
    assert {"Paco", "Marisa"} <= alias_activos

    # 3) Iniciar: la maestra pulsa "Iniciar actividad".
    r = await client.patch(f"/sesiones/{sesion_id}/iniciar", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["iniciada"] is True
    r = await client.get(f"/sesiones/activa?centro_id={centro_id}", headers=headers)
    assert r.json()["iniciada"] is True

    # 4) Cola de un participante con plan -> coherente con su plan.
    #    Paco tiene plan de praxias (bajo) + atencion_memoria (medio).
    r = await client.get(f"/usuarios/{paco['id']}/cola?sesion_id={sesion_id}", headers=headers)
    assert r.status_code == 200, r.text
    cola = r.json()
    assert cola["items"], "la cola de Paco no debería estar vacía"
    bloques_cola = {it["bloque"] for it in cola["items"]}
    assert "praxias" in bloques_cola
    assert "atencion_memoria" in bloques_cola
    # Cada item trae los datos que la tablet necesita para pintar la actividad.
    for it in cola["items"]:
        assert it["ejercicio_id"] and it["nombre"] and it["plantilla"]

    # 5) Hacer un ejercicio: pedir instancia y registrar un intento con métrica.
    item_praxias = next(it for it in cola["items"] if it["bloque"] == "praxias")
    ejercicio_id = item_praxias["ejercicio_id"]

    r = await client.get(
        f"/ejercicios/{ejercicio_id}/instancia?usuario_final_id={paco['id']}",
        headers=headers,
    )
    assert r.status_code == 200, r.text
    instancia = r.json()
    assert instancia["ejercicio_id"] == ejercicio_id
    assert instancia["render"] and instancia["metricas"]

    # Estado del histórico ANTES del intento (para comprobar que se registra).
    r = await client.get(f"/usuarios/{paco['id']}/evolucion?bloque=praxias", headers=headers)
    assert r.status_code == 200, r.text
    n_antes = r.json()["resumen"]["n_intentos"]

    PRECISION = 0.9  # trazo amplio y preciso -> se autocorrige como 'logrado'
    intento_uuid = str(uuid.uuid4())
    r = await client.post(
        f"/sesiones/{sesion_id}/intentos",
        headers=headers,
        json={
            "id": intento_uuid,
            "usuario_final_id": paco["id"],
            "sesion_id": sesion_id,
            "ejercicio_id": ejercicio_id,
            "estado": "sin_valorar",
            "valores_json": {"precision": PRECISION, "puntos_capturados": 20,
                             "tiempo_ms": 88000},
            "cantidad_objetivo_json": {"figura_id": "onda", "tolerancia_px": 24},
        },
    )
    assert r.status_code in (200, 201), r.text
    intento = r.json()
    assert intento["id"] == intento_uuid
    # La app autocorrige el resultado sin que la integradora toque nada.
    assert intento["resultado"] == "logrado"
    assert intento["con_ayuda"] is False

    # La medición queda guardada: la evolución refleja +1 intento y la métrica.
    r = await client.get(f"/usuarios/{paco['id']}/evolucion?bloque=praxias", headers=headers)
    ev = r.json()
    assert ev["resumen"]["n_intentos"] == n_antes + 1
    precisiones = [p["precision"] for p in ev["puntos"]]
    assert PRECISION in precisiones

    # 8) Live: la ficha trae el intento recién creado y su resultado autocorregido.
    r = await client.get(f"/sesiones/{sesion_id}/live", headers=headers)
    assert r.status_code == 200, r.text
    live = r.json()
    ficha_paco = next(f for f in live["fichas"] if f["usuario_final_id"] == paco["id"])
    assert ficha_paco["ultimo_intento_id"] == intento_uuid
    assert ficha_paco["ultimo_estado"] == "logrado"

    # 6) Marcar "le ayudé" en ESA actividad (capa secundaria): no cambia el
    # resultado, solo anota la ayuda.
    r = await client.patch(
        f"/intentos/{intento_uuid}/ayuda", headers=headers, json={"con_ayuda": True}
    )
    assert r.status_code == 200, r.text
    assert r.json()["con_ayuda"] is True
    assert r.json()["resultado"] == "logrado"  # el resultado no se toca
    # Se ve reflejado en live.
    r = await client.get(f"/sesiones/{sesion_id}/live", headers=headers)
    ficha_paco = next(f for f in r.json()["fichas"] if f["usuario_final_id"] == paco["id"])
    assert ficha_paco["ultimo_con_ayuda"] is True

    # 9) Cerrar: la sala deja de aparecer como activa.
    r = await client.patch(f"/sesiones/{sesion_id}/cerrar", headers=headers)
    assert r.status_code == 200, r.text
    assert r.json()["cerrada"] is True
    r = await client.get(f"/sesiones/activa?centro_id={centro_id}", headers=headers)
    assert r.json()["sesion_id"] is None


# --------------------------------------------------------------------------
#  7: idempotencia del registro de intentos (sync offline)
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_intento_idempotente_no_duplica(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    usuarios = await _usuarios_por_alias(client, headers, centro_id)
    paco = usuarios["Paco"]
    ejercicio = await _ejercicio_de_bloque(client, headers, "praxias")

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "nombre": "Sala Paco", "participantes": [paco["id"]]},
    )
    sesion_id = r.json()["id"]

    r = await client.get(f"/usuarios/{paco['id']}/evolucion?bloque=praxias", headers=headers)
    n_antes = r.json()["resumen"]["n_intentos"]

    intento_uuid = str(uuid.uuid4())
    payload = {
        "id": intento_uuid,
        "usuario_final_id": paco["id"],
        "sesion_id": sesion_id,
        "ejercicio_id": ejercicio["id"],
        "estado": "sin_valorar",
        "valores_json": {"precision": 0.85, "puntos_capturados": 20, "tiempo_ms": 90000},
    }

    r1 = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers, json=payload)
    assert r1.status_code in (200, 201), r1.text
    # Reenvío EXACTO del mismo UUID -> no debe crear otro.
    r2 = await client.post(f"/sesiones/{sesion_id}/intentos", headers=headers, json=payload)
    assert r2.status_code in (200, 201), r2.text
    assert r1.json()["id"] == r2.json()["id"] == intento_uuid

    r = await client.get(f"/usuarios/{paco['id']}/evolucion?bloque=praxias", headers=headers)
    assert r.json()["resumen"]["n_intentos"] == n_antes + 1  # +1, no +2


# --------------------------------------------------------------------------
#  10: detección/alertas + sugerencias ante empeoramiento sostenido
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_serie_descendente_genera_alerta_y_sugerencia(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    ejercicio = await _ejercicio_de_bloque(client, headers, "praxias")

    # Usuario nuevo y limpio (sin historial de demo).
    r = await client.post(
        "/usuarios",
        headers=headers,
        json={"alias_interno": "TestBajada", "nivel_base_json": {}},
    )
    assert r.status_code == 201, r.text
    uf = r.json()
    # Consentimiento (compuerta legal RGPD: sin él no se puede abrir sesión real).
    await client.post(f"/usuarios/{uf['id']}/consentimiento", headers=headers,
                      json={"otorgado_por": "titular", "rol_otorgante": "titular"})

    # Plan con nivel en praxias (para poder sugerir bajar de nivel).
    r = await client.put(
        f"/usuarios/{uf['id']}/plan",
        headers=headers,
        json={"lineas": [{"tipo": "dominio", "bloque": "praxias", "nivel": "medio",
                          "n_por_sesion": 1, "orden": 0}]},
    )
    assert r.status_code == 200, r.text

    r = await client.post(
        "/sesiones",
        headers=headers,
        json={"tipo": "individual", "participantes": [uf["id"]]},
    )
    sesion_id = r.json()["id"]

    # Serie de RESULTADO claramente descendente y sostenida (dispara el motor):
    # trazos amplios y precisos (logrado) y luego trazos casi vacíos (no_logrado).
    serie = [
        {"precision": 0.9, "puntos_capturados": 20},   # logrado
        {"precision": 0.9, "puntos_capturados": 20},
        {"precision": 0.9, "puntos_capturados": 20},
        {"precision": 0.9, "puntos_capturados": 20},
        {"precision": 0.9, "puntos_capturados": 20},
        {"precision": 0.4, "puntos_capturados": 3},    # no_logrado (apenas trazó)
        {"precision": 0.4, "puntos_capturados": 3},
    ]
    for idx, met in enumerate(serie):
        r = await client.post(
            f"/sesiones/{sesion_id}/intentos",
            headers=headers,
            json={
                "id": str(uuid.uuid4()),
                "usuario_final_id": uf["id"],
                "sesion_id": sesion_id,
                "ejercicio_id": ejercicio["id"],
                "estado": "sin_valorar",
                "valores_json": {**met, "tiempo_ms": 90000},
                # cantidad_objetivo REALISTA: la figura cambia en cada tirada
                # (como en producción). La dificultad (tolerancia_px) es estable,
                # así que la firma debe agruparlos pese a que figura_id varíe.
                "cantidad_objetivo_json": {"figura_id": f"onda_{idx}",
                                           "tolerancia_px": 24},
            },
        )
        assert r.status_code in (200, 201), r.text

    # Alerta de la persona.
    r = await client.get(f"/usuarios/{uf['id']}/alertas", headers=headers)
    assert r.status_code == 200, r.text
    alertas = r.json()
    assert alertas, "un empeoramiento sostenido debería generar una alerta"
    assert any(a["bloque_afectado"] == "praxias" for a in alertas)

    # Bandeja del centro con revisada=false la incluye.
    r = await client.get("/alertas?revisada=false", headers=headers)
    assert r.status_code == 200, r.text
    ids_bandeja = {a["id"] for a in r.json()}
    assert any(a["id"] in ids_bandeja for a in alertas)

    # Sugerencias: propone BAJAR nivel de forma coherente.
    r = await client.get(f"/usuarios/{uf['id']}/sugerencias", headers=headers)
    assert r.status_code == 200, r.text
    sugerencias = r.json()
    assert any(s["sugerencia"] == "bajar" and s["bloque"] == "praxias" for s in sugerencias)


# --------------------------------------------------------------------------
#  11: seguridad básica (RGPD) — 401 sin token, 403 entre centros (IDOR)
# --------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_endpoints_protegidos_sin_token_401(client):
    login, headers = await _login(client)
    centro_id = login["centro_id"]

    # Sin cabecera Authorization -> 401 en endpoints protegidos.
    for path in (
        f"/sesiones/activa?centro_id={centro_id}",
        "/alertas?revisada=false",
        f"/centros/{centro_id}/usuarios",
    ):
        r = await client.get(path)
        assert r.status_code == 401, f"{path} debería exigir token, dio {r.status_code}"


@pytest.mark.asyncio
async def test_idor_staff_no_ve_otro_centro_403(client, Session):
    # Staff del centro sembrado (demo).
    login, headers = await _login(client)
    centro_demo = login["centro_id"]

    # Creamos un SEGUNDO centro con su propio staff directamente en la BD de test.
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

    # El staff del centro 2 NO puede listar usuarios del centro demo (otro centro).
    r = await client.get(f"/centros/{centro_demo}/usuarios", headers=headers2)
    assert r.status_code == 403, r.text

    # Ni consultar la sesión activa ni la bandeja de alertas de un centro ajeno.
    r = await client.get(f"/sesiones/activa?centro_id={centro_demo}", headers=headers2)
    assert r.status_code == 403, r.text
    r = await client.get(f"/alertas?centro_id={centro_demo}", headers=headers2)
    assert r.status_code == 403, r.text
