"""Simulación de ECOSISTEMA REAL de Trazo, contra la app en proceso (SQLite en
memoria). NO toca producción. Informe PASS/FAIL por paso.

Escenario (lo que pidió Saulo):
- 3 centros AISLADOS.
- Cada centro: 5 trabajadoras = 1 coordinadora-psicóloga (admin_centro, planifica y
  evalúa, NO da actividades) + 4 facilitadoras (integradoras).
- 20 personas por centro.
- 4 grupos de 5 por centro, cada uno abierto e iniciado por una facilitadora
  distinta -> 4 salas SIMULTÁNEAS por centro (12 salas vivas a la vez en total).
- Las personas hacen actividades; el panel las refleja en vivo.
- La psicóloga revisa lo sin_valorar, mira evolución/áreas/objetivos y REPLANIFICA
  según el informe de cada persona.
- Aislamiento: cada centro NO ve nada de los otros dos (matriz completa).
"""
import asyncio
import os
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

    async with AsyncClient(transport=transport, base_url="http://test", timeout=60) as c:
        async def login(email, pw):
            r = await c.post("/auth/login", data={"username": email, "password": pw})
            assert r.status_code == 200, (email, r.text)
            b = r.json()
            return b, {"Authorization": "Bearer " + b["access_token"]}

        centros = {}  # nombre -> dict(centro_id, coord headers, facils[], usuarios[], salas[])

        for cn in ("Centro Norte", "Centro Sur", "Centro Este"):
            print("== Alta de %s (plataforma) ==" % cn)
            slug = cn.split()[1].lower()
            r = await c.post("/plataforma/centros", headers=PLAT, json={
                "centro": cn, "email": "coord@%s.es" % slug,
                "password": "clave-%s-coord" % slug, "nombre": "Psicóloga %s" % slug})
            check(r.status_code in (200, 201), "crear %s + coordinadora (%s)" % (cn, r.status_code))
            login_c, coord = await login("coord@%s.es" % slug, "clave-%s-coord" % slug)
            centro_id = login_c["centro_id"]
            check(login_c["rol"] == "admin_centro", "%s: coordinadora es admin_centro (la que manda)" % cn)

            # Contrato de encargo (DPA) del centro: la compuerta legal lo exige
            # antes de abrir sesiones reales.
            rd = await c.post("/documentos", headers=coord, json={
                "tipo": "dpa", "nombre_archivo": "dpa.txt", "mime": "text/plain",
                "contenido_b64": "RFBBIGRlbW8="})
            check(rd.status_code in (200, 201), "%s: DPA subido (%s)" % (cn, rd.status_code))

            # 4 facilitadoras (integradoras)
            facils = []
            for i in range(4):
                em = "facil%d@%s.es" % (i, slug)
                r = await c.post("/staff", headers=coord, json={
                    "nombre": "Facilitadora %d %s" % (i + 1, slug), "email": em,
                    "password": "clave-%s-f%d" % (slug, i), "rol": "integradora"})
                assert r.status_code in (200, 201), r.text
                _, h = await login(em, "clave-%s-f%d" % (slug, i))
                facils.append(h)
            check(len(facils) == 4, "%s: 4 facilitadoras creadas" % cn)

            # 20 personas + plan + objetivo (la psicóloga planifica)
            usuarios = []
            for i in range(20):
                r = await c.post("/usuarios", headers=coord, json={"alias_interno": "%s P%02d" % (slug, i + 1)})
                assert r.status_code == 201, r.text
                uid = r.json()["id"]
                usuarios.append(uid)
                # Consentimiento (compuerta legal): sin él no se abre sesión real.
                await c.post("/usuarios/%s/consentimiento" % uid, headers=coord,
                             json={"otorgado_por": "titular", "rol_otorgante": "titular"})
            planificados = objetivados = 0
            for k, uid in enumerate(usuarios):
                bloque = BLOQUES[k % len(BLOQUES)]
                rp = await c.put("/usuarios/%s/plan" % uid, headers=coord, json={"lineas": [
                    {"tipo": "dominio", "bloque": bloque, "n_por_sesion": 2, "orden": 0, "activo": True},
                    {"tipo": "dominio", "bloque": BLOQUES[(k + 1) % len(BLOQUES)], "n_por_sesion": 2, "orden": 1, "activo": True},
                ]})
                if rp.status_code in (200, 201):
                    planificados += 1
                ro = await c.post("/usuarios/%s/objetivos" % uid, headers=coord, json={
                    "bloque": bloque, "descripcion": "mantener %s" % bloque, "objetivo_desempeno": 0.6})
                if ro.status_code == 201:
                    objetivados += 1
            check(planificados == 20, "%s: plan a las 20 personas (%d)" % (cn, planificados))
            check(objetivados == 20, "%s: objetivo a las 20 personas (%d)" % (cn, objetivados))

            centros[cn] = dict(centro_id=centro_id, coord=coord, facils=facils,
                               usuarios=usuarios, slug=slug, salas=[])
            print()

        # --- 4 grupos SIMULTÁNEOS por centro (una facilitadora cada uno) ---
        print("== 4 grupos de 5 SIMULTÁNEOS por centro (12 salas vivas a la vez) ==")
        for cn, d in centros.items():
            grupos = [d["usuarios"][i * 5:(i + 1) * 5] for i in range(4)]
            for gi, grupo in enumerate(grupos):
                fac = d["facils"][gi]
                r = await c.post("/sesiones", headers=fac, json={
                    "tipo": "grupo", "nombre": "Grupo %d" % (gi + 1), "participantes": grupo})
                assert r.status_code == 201, (cn, r.text)
                sid = r.json()["id"]
                await c.patch("/sesiones/%s/iniciar" % sid, headers=fac)
                d["salas"].append((sid, grupo, fac))
            r = await c.get("/sesiones?centro_id=%s&estado=abierta" % d["centro_id"], headers=d["coord"])
            abiertas = {s["id"] for s in r.json()}
            esperadas = {s[0] for s in d["salas"]}
            check(esperadas <= abiertas and len(esperadas) == 4,
                  "%s: 4 salas conviven abiertas a la vez (%d)" % (cn, len(esperadas & abiertas)))
            # El kiosco ve las 4 salas del centro, cada una con sus 5, sin mezclar
            r = await c.get("/sesiones/activa?centro_id=%s" % d["centro_id"], headers=d["coord"])
            salas = r.json().get("salas", [])
            por_sala = {s["sesion_id"]: {p["usuario_final_id"] for p in s["participantes"]} for s in salas}
            ok_kiosco = len(salas) == 4 and all(por_sala.get(sid) == set(g) for sid, g, _ in d["salas"])
            check(ok_kiosco, "%s: el kiosco ve las 4 salas, cada una con los suyos" % cn)
        print()

        # --- Actividades a la vez: cada persona registra su intento ---
        print("== Actividades simultáneas: cada persona registra su intento ==")
        # cache de ejercicio por (centro, bloque)
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
            check(registrados == 20, "%s: las 20 personas registran su intento (%d)" % (cn, registrados))
        print()

        # --- El panel refleja en vivo cada grupo ---
        print("== Panel en vivo: cada grupo muestra sus 5 fichas ==")
        for cn, d in centros.items():
            todas_ok = True
            for sid, grupo, _ in d["salas"]:
                l = await c.get("/sesiones/%s/live" % sid, headers=d["coord"])
                if l.status_code != 200 or len(l.json()["fichas"]) != 5:
                    todas_ok = False
            check(todas_ok, "%s: las 4 salas muestran 5 fichas en vivo" % cn)
        print()

        # --- La psicóloga revisa y REPLANIFICA según el informe ---
        print("== La psicóloga revisa lo sin_valorar y replanifica según informes ==")
        for cn, d in centros.items():
            pend = (await c.get("/pendientes", headers=d["coord"])).json()
            check(len(pend) == 20, "%s: cola de revisión con 20 sin_valorar (%d)" % (cn, len(pend)))
            # valora 12 (mezcla de resultados) y deja 8
            for j, p in enumerate(pend[:12]):
                res = ["logrado", "parcial", "no_logrado"][j % 3]
                await c.patch("/intentos/%s/resultado" % p["id"], headers=d["coord"], json={"resultado": res})
            pend2 = (await c.get("/pendientes", headers=d["coord"])).json()
            check(len(pend2) == 8, "%s: tras valorar 12 quedan 8 (%d)" % (cn, len(pend2)))
            # panorámica por áreas
            areas = (await c.get("/centros/%s/resumen-areas" % d["centro_id"], headers=d["coord"])).json()
            check(any(a["bloque"] == "razonamiento" for a in areas), "%s: resumen por áreas incluye razonamiento" % cn)
            # REPLANIFICAR según el informe de 3 personas (mira evolución+objetivos y ajusta el plan)
            replanificados = 0
            for uid in d["usuarios"][:3]:
                ev = (await c.get("/usuarios/%s/evolucion" % uid, headers=d["coord"])).json()
                objs = (await c.get("/usuarios/%s/objetivos" % uid, headers=d["coord"])).json()
                assert "resumen" in ev and isinstance(objs, list)
                # decisión de planificación: reforzar el área del objetivo con más repeticiones
                area = objs[0]["bloque"] if objs else "lenguaje"
                rp = await c.put("/usuarios/%s/plan" % uid, headers=d["coord"], json={"lineas": [
                    {"tipo": "dominio", "bloque": area, "n_por_sesion": 3, "orden": 0, "activo": True},
                    {"tipo": "dominio", "bloque": "atencion_memoria", "n_por_sesion": 1, "orden": 1, "activo": True},
                ]})
                if rp.status_code in (200, 201):
                    replanificados += 1
            check(replanificados == 3, "%s: la psicóloga replanifica según informe a 3 personas (%d)" % (cn, replanificados))
        print()

        # --- Aislamiento multi-tenant: matriz completa entre los 3 centros ---
        print("== Aislamiento entre los 3 centros (matriz completa) ==")
        nombres = list(centros)
        aisl_ok = True
        detalles = []
        for a in nombres:
            for b in nombres:
                if a == b:
                    continue
                da, db = centros[a], centros[b]
                # A no ve una sala de B
                sid_b = db["salas"][0][0]
                r = await c.get("/sesiones/%s/live" % sid_b, headers=da["coord"])
                if r.status_code != 403:
                    aisl_ok = False
                    detalles.append("%s ve sala de %s (%s)" % (a, b, r.status_code))
                # A no ve el resumen de áreas de B
                r = await c.get("/centros/%s/resumen-areas" % db["centro_id"], headers=da["coord"])
                if r.status_code != 403:
                    aisl_ok = False
                    detalles.append("%s ve áreas de %s (%s)" % (a, b, r.status_code))
                # A no ve pendientes de B
                r = await c.get("/pendientes", headers=da["coord"])
                if any(p["usuario_final_id"] in set(db["usuarios"]) for p in r.json()):
                    aisl_ok = False
                    detalles.append("%s ve pendientes de %s" % (a, b))
        check(aisl_ok, "cada centro NO ve nada de los otros dos (6 pares) %s" % ("" if aisl_ok else detalles))
        # Cada facilitadora recupera SU sala (no la de otra compañera)
        for cn, d in centros.items():
            mias = []
            for gi, (sid, grupo, fac) in enumerate(d["salas"]):
                r = await c.get("/sesiones/mia-abierta", headers=fac)
                mias.append(r.json().get("sesion_id") == sid)
            check(all(mias), "%s: cada facilitadora recupera SU sala (4/4)" % cn)

    app.dependency_overrides.clear()
    await eng.dispose()
    print("\n==== RESULTADO ECOSISTEMA: %d OK, %d FAIL ====" % (len(oks), len(fails)))
    if fails:
        print("FALLOS:")
        for f in fails:
            print("  - " + f)


asyncio.run(main())
