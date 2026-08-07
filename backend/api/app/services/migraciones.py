"""Micro-migraciones idempotentes de esquema (sin Alembic, para el MVP).

`create_all` crea tablas que faltan, pero NO añade columnas nuevas a tablas ya
existentes. Cuando el esquema evoluciona (p. ej. sesiones programadas), estas
funciones añaden las columnas que falten SIN borrar la base de datos, para no
invalidar los datos ni los logins existentes.

Portable a SQLite (local) y PostgreSQL (producción).
"""
from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.engine import Connection

# Columnas que deben existir por tabla, con su SQL de ALTER por dialecto.
# Cada entrada: (tabla, columna, {dialecto: "tipo + default"}).
_COLUMNAS = [
    (
        "sesiones",
        "abierta",
        {
            # Filas existentes eran salas en vivo -> abierta = verdadero.
            "sqlite": "BOOLEAN NOT NULL DEFAULT 1",
            "postgresql": "BOOLEAN NOT NULL DEFAULT true",
        },
    ),
    (
        "sesiones",
        "programada_para",
        {
            "sqlite": "DATE",
            "postgresql": "DATE",
        },
    ),
]


def migrar_columnas(conn: Connection) -> list[str]:
    """Añade las columnas que falten. Devuelve la lista de columnas creadas."""
    inspector = inspect(conn)
    dialecto = conn.dialect.name  # 'sqlite' | 'postgresql'
    tablas = set(inspector.get_table_names())
    creadas: list[str] = []

    for tabla, columna, tipos in _COLUMNAS:
        if tabla not in tablas:
            continue  # create_all la creará entera con sus columnas
        existentes = {c["name"] for c in inspector.get_columns(tabla)}
        if columna in existentes:
            continue
        tipo = tipos.get(dialecto) or next(iter(tipos.values()))
        conn.execute(text(f'ALTER TABLE {tabla} ADD COLUMN {columna} {tipo}'))
        creadas.append(f"{tabla}.{columna}")

    return creadas
