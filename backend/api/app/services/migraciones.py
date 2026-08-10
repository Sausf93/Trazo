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
    (
        "sesion_participantes",
        "actividad_actual",
        {"sqlite": "VARCHAR(200)", "postgresql": "VARCHAR(200)"},
    ),
    (
        "sesion_participantes",
        "pos_actual",
        {"sqlite": "INTEGER NOT NULL DEFAULT 0",
         "postgresql": "INTEGER NOT NULL DEFAULT 0"},
    ),
    (
        "sesion_participantes",
        "total_actual",
        {"sqlite": "INTEGER NOT NULL DEFAULT 0",
         "postgresql": "INTEGER NOT NULL DEFAULT 0"},
    ),
    (
        "sesiones",
        "notas",
        {"sqlite": "VARCHAR(2000)", "postgresql": "VARCHAR(2000)"},
    ),
    (
        "intentos",
        "resultado",
        {"sqlite": "VARCHAR(20) NOT NULL DEFAULT 'sin_valorar'",
         "postgresql": "VARCHAR(20) NOT NULL DEFAULT 'sin_valorar'"},
    ),
    (
        "intentos",
        "con_ayuda",
        {"sqlite": "BOOLEAN NOT NULL DEFAULT 0",
         "postgresql": "BOOLEAN NOT NULL DEFAULT false"},
    ),
]


# Índices de las consultas calientes (histórico de alertas/evolución, live,
# resumen, salas activas). `CREATE INDEX IF NOT EXISTS` es idempotente y portable
# a SQLite y PostgreSQL. Sin ellos, en producción serían sequential scans según
# crecen los datos (auditoría de arquitectura).
_INDICES = [
    ("ix_intentos_usuario_ejercicio", "intentos", "(usuario_final_id, ejercicio_id)"),
    ("ix_intentos_usuario_ts", "intentos", "(usuario_final_id, timestamp_inicio)"),
    ("ix_intentos_sesion", "intentos", "(sesion_id)"),
    ("ix_sesiones_centro_fecha", "sesiones", "(centro_id, fecha)"),
    ("ix_sesion_participantes_sesion", "sesion_participantes", "(sesion_id)"),
    # La tabla alertas se consulta en el path caliente (anti-duplicado en cada
    # intento) y en los listados por usuario/centro.
    ("ix_alertas_usuario", "alertas", "(usuario_final_id, fecha_revision)"),
]


def migrar_indices(conn: Connection) -> list[str]:
    """Crea los índices que falten (idempotente). Devuelve los creados."""
    inspector = inspect(conn)
    tablas = set(inspector.get_table_names())
    creados: list[str] = []
    for nombre, tabla, cols in _INDICES:
        if tabla not in tablas:
            continue
        existentes = {ix["name"] for ix in inspector.get_indexes(tabla)}
        if nombre in existentes:
            continue
        conn.execute(text(f'CREATE INDEX IF NOT EXISTS {nombre} ON {tabla} {cols}'))
        creados.append(nombre)
    return creados


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
