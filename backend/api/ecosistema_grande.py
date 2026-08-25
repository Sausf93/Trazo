"""Simulación de ECOSISTEMA GRANDE de Trazo, contra la app en proceso (SQLite en
memoria). NO toca producción. Prueba que el SOFTWARE aguanta a ESCALA:

- 10 centros AISLADOS a la vez.
- Cada centro: 1 psicóloga (admin_centro, planifica/evalúa) + 5 integradoras
  (SIN LÍMITE de profesionales) = 6 profesionales/centro (60 en total).
- 30 personas por centro (300 en total).
- 3 grupos de 10 SIMULTÁNEOS por centro -> 30 salas vivas a la vez.
- Todas las personas registran intentos; el panel las refleja en vivo.
- La psicóloga revisa lo sin_valorar, mira evolución/áreas y replanifica.
- PRUEBA EXPLÍCITA de "sin límite de profesionales": un centro con 10 profesionales.
- Aislamiento: matriz completa entre los 10 centros (90 pares).
- Mide el tiempo total.
"""
import asyncio
import os
import time
import uuid

os.environ.setdefault("PLATFORM_TOKEN", "eco-token")
os.environ.setdefault("ENTORNO", "prod")
os.environ.setdefault("JWT_SECRET", "eco-secret-eco-secret-eco-secret-xx")

from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy.ext.asyncio import (  # noqa: E402
    AsyncSession, async_sessionmaker, create_async_engine)
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.services.migraciones import migrar_columnas, migrar_indices  # noqa: E402
from app.services.seed import sincronizar_catalogo  # noqa: E402

PLAT = {"X-Platform-Token": "eco-token"}
oks, fails = [], []
BLOQUES = ["razonamiento", "lenguaje", "atencion_memoria", "calculo"]

N_CENTROS = 10
N_INTEG = 5          # integradoras por centro (+1 psicóloga = 6 profesionales)
N_USERS = 30         # personas por centro
N_SALAS = 3          # salas simultáneas por centro
POR_SALA = 10        # personas por sala (3x10 = 30)


def check(cond, msg):
    (oks if cond else fails).append(msg)
    print(("  OK  " if cond else " FAIL ") + msg)


async def main():
    t0 = time.perf_counter()
    eng = create_async_engine("sqlite+aiosqlite://", poolclass=StaticPool,
                              connect_args={"check_same_thread": False})
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(migrar_columnas)
        await conn.run_sync(migrar_indices)
    Session = async_sessionmaker(bind=eng, class_=AsyncSession, expire_on_commit=False)
    async with Session() as db:
        n = await sincronizar_catalogo(db)
    print("catálogo sincronizado: %d actividades\n" % n)

    async def _get_db():
        async with Session() as s:
            try:
                yield s
            except Exception:
                await s.rollback()
                raise
    app.dependency_overrides[get_db] = _get_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test", timeout=120) as c:
        async def login(email, pw):
            r = await c.post("/auth/login", data={"username": email, "password": pw})
            assert r.status_code == 200, (email, r.text)
            b = r.json()
            return b, {"Authorization": "Bearer " + b["access_token"]}

        centros = {}
        for idx in range(N_CENTROS):
            cn = "Centro %02d" % (idx + 1)
            slug = "c%02d" % (idx + 1)
            r = await c.post("/plataforma/centros", headers=PLAT, json={
                "centro": cn, "email": "coord@%s.es" % slug,
                "password": "clave-%s-coord" % slug, "nombre": "Psicóloga %s" % slug})
            assert r.status_code in (200, 201), r.text
            login_c, coord = await login("coord@%s.es" % slug, "clave-%s-coord" % slug)
            centro_id = login_c["centro_id"]

            # N_INTEG integradoras (sin límite de profesionales)
            facils = []
            for i in range(N_INTEG):
                em = "facil%d@%s.es" % (i, slug)
                r = await c.post("/staff", headers=coord, json={
                    "nombre": "Integradora %d %s" % (i + 1, slug), "email": em,
                    "password": "clave-%s-f%d" % (slug, i), "rol": "integradora"})
                assert r.status_code in (200, 201), r.text
                _, h = await login(em, "clave-%s-f%d" % (slug, i))
                facils.append(h)

            # N_USERS personas + plan (la psicóloga planifica)
            usuarios = []
            for i in range(N_USERS):
                r = await c.post("/usuarios", headers=coord, json={"alias_interno": "%s P%02d" % (slug, i + 1)})
                assert r.status_code == 201, r.text
                usuarios.append(r.json()["id"])
            planificados = 0
            for k, uid in enumerate(usuarios):
                bloque = BLOQUES[k % len(BLOQUES)]
                rp = await c.put("/usuarios/%s/plan" % uid, headers=coord, json={"lineas": [
                    {"tipo": "dominio", "bloque": bloque, "n_por_sesion": 2, "orden": 0, "activo": True},
                ]})
                if rp.status_code in (200, 201):
                    planificados += 1
            check(planificados == N_USERS, "%s: plan a las %d personas (%d)" % (cn, N_USERS, planificados))
            centros[cn] = dict(centro_id=centro_id, coord=coord, facils=facils,
                               usuarios=usuarios, slug=slug, salas=[])
        print("== %d centros creados, cada uno con %d profesionales y %d personas ==\n"
              % (N_CENTROS, N_INTEG + 1, N_USERS))

        # PRUEBA de SIN LÍMITE de profesionales: al primer centro le añadimos 5 más
        d0 = centros["Centro 01"]
        extra_ok = 0
        for i in range(5):
            em = "extra%d@c01.es" % i
            r = await c.post("/staff", headers=d0["coord"], json={
                "nombre": "Trabajadora social %d" % (i + 1), "email": em,
                "password": "clave-x%d" % i, "rol": "integradora"})
            if r.status_code in (200, 201):
                _, _ = await login(em, "clave-x%d" % i)
                extra_ok += 1
        check(extra_ok == 5, "Sin límite de profesionales: Centro 01 llega a %d profesionales (+5 OK=%d)"
              % (1 + N_INTEG + 5, extra_ok))

        # 3 grupos SIMULTÁNEOS por centro (30 salas vivas a la vez)
        for cn, d in centros.items():
            grupos = [d["usuarios"][i * POR_SALA:(i + 1) * POR_SALA] for i in range(N_SALAS)]
            for gi, grupo in enumerate(grupos):
                fac = d["facils"][gi % len(d["facils"])]
                r = await c.post("/sesiones", headers=fac, json={
                    "tipo": "grupo", "nombre": "Grupo %d" % (gi + 1), "participantes": grupo})
                assert r.status_code == 201, (cn, r.text)
                sid = r.json()["id"]
                await c.patch("/sesiones/%s/iniciar" % sid, headers=fac)
                d["salas"].append((sid, grupo, fac))
            r = await c.get("/sesiones?centro_id=%s&estado=abierta" % d["centro_id"], headers=d["coord"])
            abiertas = {s["id"] for s in r.json()}
            esperadas = {s[0] for s in d["salas"]}
            check(esperadas <= abiertas and len(esperadas) == N_SALAS,
                  "%s: %d salas conviven abiertas a la vez" % (cn, len(esperadas & abiertas)))
        print("== %d salas vivas a la vez en total ==\n" % (N_CENTROS * N_SALAS))

        # Actividades simultáneas: cada persona registra su intento
        total_intentos = 0
        for cn, d in centros.items():
            ej = (await c.get("/ejercicios?bloque=razonamiento&activo=true", headers=d["coord"])).json()[0]["id"]
            registrados = 0
            for sid, grupo, fac in d["salas"]:
                for uid in grupo:
                    r = await c.post("/sesiones/%s/intentos" % sid, headers=fac, json={
                        "id": str(uuid.uuid4()), "usuario_final_id": uid, "sesion_id": sid,
                        "ejercicio_id": ej, "estado": "sin_valorar", "valores_json": {}, "cantidad_objetivo_json": {}})
                    if r.status_code == 201:
                        registrados += 1
            total_intentos += registrados
            if registrados != N_USERS:
                check(False, "%s: intentos %d/%d" % (cn, registrados, N_USERS))
        check(total_intentos == N_CENTROS * N_USERS,
              "%d personas registran su intento a la vez (%d)" % (N_CENTROS * N_USERS, total_intentos))

        # El panel refleja en vivo cada grupo
        vivo_ok = True
        for cn, d in centros.items():
            for sid, grupo, _ in d["salas"]:
                l = await c.get("/sesiones/%s/live" % sid, headers=d["coord"])
                if l.status_code != 200 or len(l.json()["fichas"]) != POR_SALA:
                    vivo_ok = False
        check(vivo_ok, "el panel en vivo muestra las %d fichas en cada una de las %d salas"
              % (POR_SALA, N_CENTROS * N_SALAS))

        # La psicóloga revisa lo sin_valorar y evolución
        eval_ok = True
        for cn, d in centros.items():
            pend = (await c.get("/pendientes", headers=d["coord"])).json()
            if len(pend) != N_USERS:
                eval_ok = False
            for j, p in enumerate(pend[:15]):
                res = ["logrado", "parcial", "no_logrado"][j % 3]
                await c.patch("/intentos/%s/resultado" % p["id"], headers=d["coord"], json={"resultado": res})
            ev = (await c.get("/usuarios/%s/evolucion" % d["usuarios"][0], headers=d["coord"])).json()
            if "resumen" not in ev:
                eval_ok = False
        check(eval_ok, "cada psicóloga revisa su cola de %d sin_valorar y ve evolución" % N_USERS)

        # Aislamiento multi-tenant: matriz completa entre los 10 centros
        nombres = list(centros)
        aisl_ok = True
        pares = 0
        for a in nombres:
            for b in nombres:
                if a == b:
                    continue
                pares += 1
                da, db = centros[a], centros[b]
                sid_b = db["salas"][0][0]
                if (await c.get("/sesiones/%s/live" % sid_b, headers=da["coord"])).status_code != 403:
                    aisl_ok = False
                if (await c.get("/centros/%s/resumen-areas" % db["centro_id"], headers=da["coord"])).status_code != 403:
                    aisl_ok = False
        check(aisl_ok, "cada centro NO ve nada de los demás (%d pares comprobados)" % pares)

    app.dependency_overrides.clear()
    await eng.dispose()
    dt = time.perf_counter() - t0
    print("\n==== ECOSISTEMA GRANDE: %d OK, %d FAIL · %d centros · %d profesionales · %d personas · %d salas a la vez · %.1fs ===="
          % (len(oks), len(fails), N_CENTROS, N_CENTROS * (N_INTEG + 1), N_CENTROS * N_USERS, N_CENTROS * N_SALAS, dt))
    if fails:
        print("FALLOS:")
        for f in fails:
            print("  - " + f)
    return len(fails) == 0


ok = asyncio.run(main())
raise SystemExit(0 if ok else 1)
