"""Alta inicial de un centro y su primera cuenta (para producción).

En producción NO se siembran datos de demo, así que tras el primer despliegue la
base de datos está vacía y nadie puede iniciar sesión. Este comando crea un
centro y una cuenta de administración del centro, de forma idempotente.

Uso (dentro del contenedor api, o con el entorno del backend):
    python -m app.bootstrap \
        --centro "Centro de Día X" \
        --email admin@centrox.es \
        --password "una-contraseña-fuerte" \
        --nombre "Nombre Apellidos"

La contraseña puede pasarse por --password o por la variable de entorno
BOOTSTRAP_PASSWORD (recomendado para no dejarla en el historial de la shell).
"""
from __future__ import annotations

import argparse
import asyncio
import os

from sqlalchemy import select

from app.database import AsyncSessionLocal, Base, engine
from app.models import Centro, UsuarioStaff
from app.security import hash_password


async def alta_centro_admin(db, nombre_centro: str, email: str, password: str,
                            nombre_staff: str) -> tuple[str, bool]:
    """Crea (idempotente) un centro y su cuenta admin sobre la sesión `db` dada.

    Devuelve (mensaje, creado). No hace commit del engine global: opera sobre la
    sesión que le pasen, así vale tanto para el CLI como para el endpoint de
    plataforma (y es testeable sobre la BD de test)."""
    existe = (await db.execute(
        select(UsuarioStaff).where(UsuarioStaff.email == email)
    )).scalars().first()
    if existe is not None:
        return (f"La cuenta {email} ya existe (no se hace nada).", False)

    centro = (await db.execute(
        select(Centro).where(Centro.nombre == nombre_centro)
    )).scalars().first()
    if centro is None:
        centro = Centro(nombre=nombre_centro)
        db.add(centro)
        await db.flush()

    db.add(UsuarioStaff(
        centro_id=centro.id,
        nombre=nombre_staff,
        rol="admin_centro",
        email=email,
        password_hash=hash_password(password),
    ))
    await db.commit()
    return (f"Creado el centro '{nombre_centro}' y la cuenta {email} "
            f"(rol admin_centro). Ya puedes iniciar sesión.", True)


async def crear_centro_y_admin(nombre_centro: str, email: str, password: str,
                               nombre_staff: str) -> tuple[str, bool]:
    """Versión autónoma para el CLI: abre su propio motor y crea las tablas."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as db:
        return await alta_centro_admin(db, nombre_centro, email, password, nombre_staff)


def main() -> None:
    p = argparse.ArgumentParser(description="Alta inicial de centro + cuenta admin")
    p.add_argument("--centro", required=True, help="Nombre del centro")
    p.add_argument("--email", required=True, help="Email de la cuenta admin")
    p.add_argument("--nombre", default="Administración del centro",
                   help="Nombre de la persona")
    p.add_argument("--password", default=None,
                   help="Contraseña (o usa la variable BOOTSTRAP_PASSWORD)")
    args = p.parse_args()

    password = args.password or os.environ.get("BOOTSTRAP_PASSWORD")
    if not password:
        raise SystemExit("Falta la contraseña: usa --password o BOOTSTRAP_PASSWORD.")
    if len(password) < 8:
        raise SystemExit("La contraseña debe tener al menos 8 caracteres.")

    msg, _creado = asyncio.run(
        crear_centro_y_admin(args.centro, args.email, password, args.nombre))
    print(msg)


if __name__ == "__main__":
    main()
