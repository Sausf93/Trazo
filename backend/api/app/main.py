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
    planes,
    sesiones,
    usuarios,
)
from app.services.migraciones import migrar_columnas
from app.services.seed import sembrar

logger = logging.getLogger("trazo")
logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Crear tablas si no existen (MVP; en producción se pasaría a Alembic).
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        # Añadir columnas nuevas a tablas ya existentes sin borrar la BD.
        creadas = await conn.run_sync(migrar_columnas)
        if creadas:
            logger.info("Migración: columnas añadidas -> %s", ", ".join(creadas))
    logger.info("Tablas verificadas/creadas.")

    if settings.seed_on_startup:
        async with AsyncSessionLocal() as db:
            try:
                await sembrar(db)
                logger.info("Datos de demo verificados/sembrados.")
            except Exception:  # pragma: no cover
                logger.exception("Fallo al sembrar datos de demo")
    yield


app = FastAPI(
    title="Trazo API",
    description="Estimulación cognitiva para centros de día — backend.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
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
app.include_router(dispositivos.router)
