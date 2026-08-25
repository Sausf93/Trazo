"""Punto de entrada de la API de Trazo (FastAPI)."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import AsyncSessionLocal, Base, engine, get_db

# Importar modelos para que Base los conozca al crear las tablas.
from app import models  # noqa: F401
from app.routers import (
    alertas,
    auth,
    dispositivos,
    ejercicios,
    evolucion,
    intentos,
    objetivos,
    planes,
    plataforma,
    sesiones,
    staff,
    usuarios,
)
from app.services.migraciones import migrar_columnas, migrar_indices
from app.services.seed import sembrar, sincronizar_catalogo

logger = logging.getLogger("trazo")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Crear tablas si no existen (MVP; en producción se pasaría a Alembic).
    async with engine.begin() as conn:
        # Lock de arranque (solo Postgres): serializa create_all + migraciones
        # entre procesos/instancias. Sin él, al desplegar o escalar, dos arranques
        # simultáneos compiten en CREATE INDEX / ALTER TABLE. El advisory lock de
        # transacción se libera solo al cerrar este bloque.
        if conn.dialect.name == "postgresql":
            await conn.execute(text("SELECT pg_advisory_xact_lock(727274)"))
        await conn.run_sync(Base.metadata.create_all)
        # Añadir columnas nuevas a tablas ya existentes sin borrar la BD.
        creadas = await conn.run_sync(migrar_columnas)
        if creadas:
            logger.info("Migración: columnas añadidas -> %s", ", ".join(creadas))
        indices = await conn.run_sync(migrar_indices)
        if indices:
            logger.info("Migración: índices creados -> %s", ", ".join(indices))
    logger.info("Tablas verificadas/creadas.")

    # El CATÁLOGO de actividades es CONTENIDO del producto (no datos de demo): se
    # carga y actualiza SIEMPRE, también en producción. Sin esto, un despliegue de
    # prod se queda sin ninguna actividad que asignar o jugar.
    #
    # Se serializa entre instancias con un advisory lock de SESIÓN (distinto del de
    # arranque): sin él, dos arranques a la vez (deploy/autoescalado) verían la misma
    # actividad ausente e insertarían filas duplicadas (el macheo es por nombre y no
    # hay unique). El lock vive en una conexión dedicada durante toda la sync.
    try:
        if engine.dialect.name == "postgresql":
            async with engine.connect() as lock_conn:
                await lock_conn.execute(text("SELECT pg_advisory_lock(727275)"))
                try:
                    async with AsyncSessionLocal() as db:
                        nuevas = await sincronizar_catalogo(db)
                finally:
                    await lock_conn.execute(text("SELECT pg_advisory_unlock(727275)"))
        else:
            async with AsyncSessionLocal() as db:
                nuevas = await sincronizar_catalogo(db)
        logger.info("Catálogo sincronizado (%s actividades nuevas).", nuevas)
    except Exception:  # pragma: no cover
        logger.exception("Fallo al sincronizar el catálogo de actividades")

    es_dev = settings.entorno.lower() == "dev"
    if not es_dev:
        logger.info("Arranque en entorno '%s' (producción): sin datos de demo.",
                    settings.entorno)
    else:
        logger.warning(
            "Arranque en ENTORNO=dev: datos y credenciales de DEMO activos. "
            "En producción define ENTORNO=prod y un JWT_SECRET propio."
        )
    # La siembra de demo SOLO en dev, aunque el flag quede encendido por error:
    # evita que un despliegue de producción cree cuentas con contraseña conocida.
    if settings.seed_on_startup and es_dev:
        async with AsyncSessionLocal() as db:
            try:
                await sembrar(db)
                logger.info("Datos de demo verificados/sembrados.")
            except Exception:  # pragma: no cover
                logger.exception("Fallo al sembrar datos de demo")
    yield


_es_dev = settings.entorno.lower() == "dev"
app = FastAPI(
    title="Trazo API",
    description="Estimulación cognitiva para centros de día — backend.",
    version="0.1.0",
    lifespan=lifespan,
    # En producción se ocultan la documentación interactiva y el esquema OpenAPI.
    docs_url="/docs" if _es_dev else None,
    redoc_url=None,
    openapi_url="/openapi.json" if _es_dev else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    # En desarrollo aceptamos cualquier puerto de localhost (panel/tablet en
    # local); en producción solo los orígenes explícitos de la configuración.
    allow_origin_regex=r"http://localhost:\d+" if _es_dev else None,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["salud"])
async def raiz():
    return {"app": "Trazo API", "version": "0.1.0", "docs": "/docs"}


@app.get("/health", tags=["salud"])
async def health(db: AsyncSession = Depends(get_db)):
    """Sonda de salud: comprueba que la base de datos responde.

    Devuelve 200 {"status":"ok"} si la BD contesta, o 503 {"status":"degraded"}
    si no. Pensada para el health check del hosting (readiness probe)."""
    try:
        await db.execute(text("SELECT 1"))
    except Exception:  # pragma: no cover
        logger.exception("Health check: la base de datos no responde")
        return JSONResponse(
            status_code=503,
            content={"status": "degraded", "database": "down"},
        )
    return {"status": "ok", "database": "up"}


app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(ejercicios.router)
app.include_router(sesiones.router)
app.include_router(intentos.router)
app.include_router(evolucion.router)
app.include_router(alertas.router)
app.include_router(planes.router)
app.include_router(objetivos.router)
app.include_router(dispositivos.router)
app.include_router(staff.router)
app.include_router(plataforma.router)
