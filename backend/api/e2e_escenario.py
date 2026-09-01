"""Simulación E2E del escenario real que pidió Saulo, contra la app en proceso
(SQLite en memoria). NO toca producción. Imprime un informe PASS/FAIL por paso.

Escenario:
- 2 centros aislados.
- Centro A: 1 coordinadora/psicóloga (admin_centro, planifica y evalúa, NO da
  actividades) + 2 maestras (integradoras) + 10 usuarios.
- La coordinadora crea plan y objetivo por usuario.
- 2 grupos de 5; cada maestra abre e inicia el suyo -> ¿pueden coexistir?
- Los usuarios hacen actividades; la coordinadora revisa sin_valorar, evolución,
  áreas y objetivos. Todo debe reflejarse en el panel (live/resumen).
- Aislamiento: el Centro B no ve nada del A.
"""
import asyncio
import os
import uuid

os.environ.setdefault("PLATFORM_TOKEN", "e2e-token")
os.environ.setdefault("ENTORNO", "prod")
os.environ.setdefault("JWT_SECRET", "e2e-secret-e2e-secret-e2e-secret-xx")

from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy.ext.asyncio import (  # noqa: E402
    AsyncSession, async_sessionmaker, create_async_engine)
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.services.migraciones import migrar_columnas, migrar_indices  # noqa: E402
from app.services.seed import sincronizar_catalogo  # noqa: E402

PLAT = {"X-Platform-Token": "e2e-token"}
oks = []
fails = []


def check(cond, msg):
    (oks if cond else fails).append(msg)
    print(("  OK  " if cond else " FAIL ") + msg)


async def main():
    eng = create_async_engine("sqlite+aiosqlite://", poolclass=StaticPool,
                              connect_args={"check_same_thread": False})
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(migrar_columnas)
        await conn.run_sync(migrar_indices)
    Session = async_sessionmaker(bind=eng, class_=AsyncSession, expire_on_commit=False)
    async with Session() as db:
        n = await sincronizar_catalogo(db)
    print("catálogo sincronizado: %d actividades" % n)

    async def _get_db():
        async with Session() as s:
            try:
                yield s
            except Exception:
                await s.rollback()
                raise
    app.dependency_overrides[get_db] = _get_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as c:
        async def login(email, pw):
            r = await c.post("/auth/login", data={"username": email, "password": pw})
            assert r.status_code == 200, (email, r.text)
            b = r.json()
            return b, {"Authorization": "Bearer " + b["access_token"]}

        # --- Alta de 2 centros por plataforma ---
        print("\n== Alta de centros (plataforma) ==")
        rA = await c.post("/plataforma/centros", headers=PLAT, json={
            "centro": "Centro A", "email": "ana@centroa.es",
            "password": "clave-fuerte-A", "nombre": "Ana (psicóloga)"})
        check(rA.status_code in (200, 201), "crear Centro A + coordinadora (%s)" % rA.status_code)
        rB = await c.post("/plataforma/centros", headers=PLAT, json={
            "centro": "Centro B", "email": "bea@centrob.es",
            "password": "clave-fuerte-B", "nombre": "Bea (psicóloga)"})
        check(rB.status_code in (200, 201), "crear Centro B + coordinadora (%s)" % rB.status_code)

        coordA_login, coordA = await login("ana@centroa.es", "clave-fuerte-A")
        centroA = coordA_login["centro_id"]
        coordB_login, coordB = await login("bea@centrob.es", "clave-fuerte-B")
        centroB = coordB_login["centro_id"]
        check(coordA_login["rol"] == "admin_centro", "la coordinadora A es admin_centro (la que manda)")

        # Contrato de encargo (DPA) de cada centro: la compuerta legal lo exige
        # antes de abrir sesiones reales.
        for _cn, _h in [("A", coordA), ("B", coordB)]:
            rd = await c.post("/documentos", headers=_h, json={
                "tipo": "dpa", "nombre_archivo": "dpa.txt", "mime": "text/plain",
                "contenido_b64": "RFBBIGRlbW8="})
            check(rd.status_code in (200, 201), "DPA centro %s (%s)" % (_cn, rd.status_code))

        # --- La coordinadora crea 2 maestras (integradoras) ---
        print("\n== Coordinadora crea su equipo (2 maestras) ==")
        maestras = {}
        for nom, em in [("Lucía", "lucia@centroa.es"), ("Marta", "marta@centroa.es")]:
            r = await c.post("/staff", headers=coordA, json={
                "nombre": nom, "email": em, "password": "clave-" + nom, "rol": "integradora"})
            check(r.status_code in (200, 201), "crear maestra %s (%s)" % (nom, r.status_code))
        _, lucia = await login("lucia@centroa.es", "clave-Lucía")
        _, marta = await login("marta@centroa.es", "clave-Marta")

        # --- La coordinadora da de alta 10 usuarios ---
        print("\n== Coordinadora crea 10 usuarios y les planifica ==")
        usuarios = []
        for i in range(10):
            r = await c.post("/usuarios", headers=coordA, json={"alias_interno": "Usuario %02d" % (i + 1)})
            assert r.status_code == 201, r.text
            uid = r.json()["id"]
            usuarios.append(uid)
            # Consentimiento (compuerta legal): sin él no se abre sesión real.
            await c.post("/usuarios/%s/consentimiento" % uid, headers=coordA,
                         json={"otorgado_por": "titular", "rol_otorgante": "titular"})
        check(len(usuarios) == 10, "10 usuarios creados")

        # Plan + objetivo por usuario (la psicóloga planifica y plantea).
        planificados = 0
        objetivados = 0
        for uid in usuarios:
            rp = await c.put("/usuarios/%s/plan" % uid, headers=coordA, json={"lineas": [
                {"tipo": "dominio", "bloque": "razonamiento", "n_por_sesion": 2, "orden": 0, "activo": True},
                {"tipo": "dominio", "bloque": "lenguaje", "n_por_sesion": 2, "orden": 1, "activo": True},
            ]})
            if rp.status_code in (200, 201):
                planificados += 1
            ro = await c.post("/usuarios/%s/objetivos" % uid, headers=coordA, json={
                "bloque": "razonamiento", "descripcion": "mantener el razonamiento", "objetivo_desempeno": 0.6})
            if ro.status_code == 201:
                objetivados += 1
        check(planificados == 10, "plan puesto a los 10 (%d)" % planificados)
        check(objetivados == 10, "objetivo puesto a los 10 (%d)" % objetivados)

        # --- 2 grupos de 5; cada maestra abre e inicia el suyo ---
        print("\n== Dos grupos de 5, cada maestra abre e inicia el suyo (SIMULTÁNEOS) ==")
        g1, g2 = usuarios[:5], usuarios[5:]
        r1 = await c.post("/sesiones", headers=lucia, json={
            "tipo": "grupo", "nombre": "Grupo mañana (Lucía)", "participantes": g1})
        ses1 = r1.json()["id"]
        await c.patch("/sesiones/%s/iniciar" % ses1, headers=lucia)
        r2 = await c.post("/sesiones", headers=marta, json={
            "tipo": "grupo", "nombre": "Grupo mañana (Marta)", "participantes": g2})
        ses2 = r2.json()["id"]
        await c.patch("/sesiones/%s/iniciar" % ses2, headers=marta)

        # ¿Coexisten las dos salas abiertas del MISMO centro?
        r = await c.get("/sesiones?centro_id=%s&estado=abierta" % centroA, headers=coordA)
        abiertas = [s["id"] for s in r.json()]
        check(ses1 in abiertas and ses2 in abiertas,
              "las 2 salas del centro conviven abiertas a la vez (%d abiertas)" % len(abiertas))

        # El kiosco debe ver las DOS salas del centro (para elegir a cuál unirse).
        r = await c.get("/sesiones/activa?centro_id=%s" % centroA, headers=coordA)
        salas = r.json().get("salas", [])
        ids_salas = {s["sesion_id"] for s in salas}
        check(ids_salas == {ses1, ses2},
              "el kiosco ve LAS DOS salas del centro (%d salas)" % len(salas))
        # Cada sala trae sus 5 participantes, sin mezclarse.
        por_sala = {s["sesion_id"]: {p["usuario_final_id"] for p in s["participantes"]} for s in salas}
        check(por_sala.get(ses1) == set(g1) and por_sala.get(ses2) == set(g2),
              "cada sala muestra SOLO a los suyos (5 y 5, sin mezclar)")
        # Cada sala trae su responsable (para distinguir salas homónimas).
        resp = {s["sesion_id"]: s.get("responsable") for s in salas}
        check(resp.get(ses1) == "Lucía" and resp.get(ses2) == "Marta",
              "cada sala indica su responsable (Lucía / Marta)")

        # Al refrescar, cada maestra recupera SU sala (no la de la compañera).
        mia_l = (await c.get("/sesiones/mia-abierta", headers=lucia)).json()
        mia_m = (await c.get("/sesiones/mia-abierta", headers=marta)).json()
        check(mia_l.get("sesion_id") == ses1 and mia_m.get("sesion_id") == ses2,
              "cada maestra recupera SU sala (Lucía->ses1, Marta->ses2)")

        # Una persona no puede estar en dos salas a la vez (se rechaza).
        rdup = await c.post("/sesiones", headers=lucia, json={
            "tipo": "grupo", "nombre": "Choque", "participantes": [g2[0]]})
        check(rdup.status_code == 409, "poner a alguien de otra sala abierta -> 409 (%d)" % rdup.status_code)

        # --- Los usuarios hacen actividades en su grupo ---
        print("\n== Actividades: cada grupo con su sesión; se registran intentos ==")
        ejs = (await c.get("/ejercicios?bloque=razonamiento&activo=true", headers=coordA)).json()
        ej = ejs[0]["id"]
        reg1 = reg2 = 0
        for uid in g1:
            r = await c.post("/sesiones/%s/intentos" % ses1, headers=lucia, json={
                "id": str(uuid.uuid4()), "usuario_final_id": uid, "sesion_id": ses1,
                "ejercicio_id": ej, "estado": "sin_valorar", "valores_json": {}, "cantidad_objetivo_json": {}})
            if r.status_code == 201:
                reg1 += 1
        for uid in g2:
            r = await c.post("/sesiones/%s/intentos" % ses2, headers=marta, json={
                "id": str(uuid.uuid4()), "usuario_final_id": uid, "sesion_id": ses2,
                "ejercicio_id": ej, "estado": "sin_valorar", "valores_json": {}, "cantidad_objetivo_json": {}})
            if r.status_code == 201:
                reg2 += 1
        check(reg1 == 5, "los 5 del grupo 1 registran su intento (%d)" % reg1)
        check(reg2 == 5, "los 5 del grupo 2 registran su intento (%d)" % reg2)

        # --- El panel refleja cada grupo (live) ---
        print("\n== El panel en vivo refleja cada grupo ==")
        l1 = await c.get("/sesiones/%s/live" % ses1, headers=coordA)
        l2 = await c.get("/sesiones/%s/live" % ses2, headers=coordA)
        check(l1.status_code == 200 and len(l1.json()["fichas"]) == 5, "live grupo 1: 5 fichas")
        check(l2.status_code == 200 and len(l2.json()["fichas"]) == 5, "live grupo 2: 5 fichas")

        # --- La coordinadora revisa lo sin_valorar y ve la panorámica ---
        print("\n== La coordinadora (psicóloga) revisa y evalúa ==")
        pend = (await c.get("/pendientes", headers=coordA)).json()
        check(len(pend) == 10, "cola de revisión: 10 intentos sin_valorar (%d)" % len(pend))
        # valora unos cuantos
        for p in pend[:6]:
            await c.patch("/intentos/%s/resultado" % p["id"], headers=coordA, json={"resultado": "logrado"})
        pend2 = (await c.get("/pendientes", headers=coordA)).json()
        check(len(pend2) == 4, "tras valorar 6, quedan 4 pendientes (%d)" % len(pend2))
        areas = (await c.get("/centros/%s/resumen-areas" % centroA, headers=coordA)).json()
        check(any(a["bloque"] == "razonamiento" for a in areas), "resumen por áreas incluye razonamiento")
        ev = (await c.get("/usuarios/%s/evolucion" % usuarios[0], headers=coordA)).json()
        check("resumen" in ev, "evolución individual accesible")
        objs = (await c.get("/usuarios/%s/objetivos" % usuarios[0], headers=coordA)).json()
        check(len(objs) >= 1, "objetivos del usuario visibles con situación actual")

        # --- Aislamiento multi-tenant ---
        print("\n== Aislamiento entre centros ==")
        r = await c.get("/sesiones/%s/live" % ses1, headers=coordB)
        check(r.status_code == 403, "Centro B NO ve la sala del Centro A (403)")
        r = await c.get("/pendientes", headers=coordB)
        check(all(p["usuario_final_id"] not in usuarios for p in r.json()), "Centro B no ve pendientes del A")
        r = await c.get("/centros/%s/resumen-areas" % centroA, headers=coordB)
        check(r.status_code == 403, "Centro B no ve el resumen de áreas del A (403)")

    app.dependency_overrides.clear()
    await eng.dispose()
    print("\n==== RESULTADO: %d OK, %d FAIL ====" % (len(oks), len(fails)))
    if fails:
        print("FALLOS:")
        for f in fails:
            print("  - " + f)


asyncio.run(main())
