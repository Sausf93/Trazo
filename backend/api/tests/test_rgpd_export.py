"""RGPD (rectificación art. 16 y supresión art. 17) y export CSV de datos."""
from __future__ import annotations

import uuid

import pytest

from app.models import DatosIdentificativos
from sqlalchemy import select

INTEGRADORA = ("integradora@trazo.local", "trazo1234")
ADMIN = ("admin@trazo.local", "trazo1234")


async def _login(client, cred=INTEGRADORA):
    r = await client.post("/auth/login", data={"username": cred[0], "password": cred[1]})
    assert r.status_code == 200, r.text
    b = r.json()
    return b, {"Authorization": f"Bearer {b['access_token']}"}


async def _usuarios(client, headers, centro_id):
    r = await client.get(f"/centros/{centro_id}/usuarios", headers=headers)
    return {u["alias_interno"]: u for u in r.json()}


@pytest.mark.asyncio
async def test_rectificar_nombre_real(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    paco = (await _usuarios(client, headers, centro_id))["Paco"]

    # Fijar el nombre real (art. 16).
    r = await client.patch(f"/usuarios/{paco['id']}", headers=headers,
                           json={"nombre_real": "Francisco Ruiz"})
    assert r.status_code == 200, r.text
    async with Session() as db:
        di = (await db.execute(select(DatosIdentificativos)
              .where(DatosIdentificativos.usuario_final_id == paco["id"]))).scalars().first()
        assert di is not None and di.nombre_real == "Francisco Ruiz"

    # Vaciar ("") -> borra el dato identificativo.
    r = await client.patch(f"/usuarios/{paco['id']}", headers=headers, json={"nombre_real": ""})
    assert r.status_code == 200, r.text
    async with Session() as db:
        di = (await db.execute(select(DatosIdentificativos)
              .where(DatosIdentificativos.usuario_final_id == paco["id"]))).scalars().first()
        assert di is None


@pytest.mark.asyncio
async def test_supresion_rgpd_anonimiza(client, Session):
    _, integradora = await _login(client, INTEGRADORA)
    login_admin, admin = await _login(client, ADMIN)
    centro_id = login_admin["centro_id"]
    marisa = (await _usuarios(client, admin, centro_id))["Marisa"]

    # Ponerle nombre real para comprobar que se borra.
    await client.patch(f"/usuarios/{marisa['id']}", headers=admin,
                       json={"nombre_real": "María López"})

    # La integradora NO puede suprimir (solo admin_centro).
    r = await client.delete(f"/usuarios/{marisa['id']}", headers=integradora)
    assert r.status_code == 403, r.text

    # El admin sí: anonimiza.
    r = await client.delete(f"/usuarios/{marisa['id']}", headers=admin)
    assert r.status_code == 204, r.text
    async with Session() as db:
        di = (await db.execute(select(DatosIdentificativos)
              .where(DatosIdentificativos.usuario_final_id == marisa["id"]))).scalars().first()
        assert di is None  # nombre real borrado
    # Ya no aparece en el listado (activo=False) y su alias quedó pseudonimizado.
    assert "Marisa" not in await _usuarios(client, admin, centro_id)


@pytest.mark.asyncio
async def test_export_csv_scoped(client, Session):
    login, headers = await _login(client)
    centro_id = login["centro_id"]
    r = await client.get(f"/export/intentos.csv?centro_id={centro_id}", headers=headers)
    assert r.status_code == 200, r.text
    assert "text/csv" in r.headers["content-type"]
    cuerpo = r.text
    assert "persona;area;actividad;resultado" in cuerpo.replace("fecha;", "")

    # Otro centro no puede exportar el ajeno.
    from app.models import Centro, UsuarioStaff
    from app.security import hash_password
    async with Session() as db:
        c2 = Centro(nombre="Otro")
        db.add(c2)
        await db.flush()
        db.add(UsuarioStaff(centro_id=c2.id, nombre="Ajeno", rol="integradora",
                            email="ajeno2@trazo.local", password_hash=hash_password("trazo1234")))
        await db.commit()
    _, h2 = await _login(client, ("ajeno2@trazo.local", "trazo1234"))
    r = await client.get(f"/export/intentos.csv?centro_id={centro_id}", headers=h2)
    assert r.status_code == 403, r.text
