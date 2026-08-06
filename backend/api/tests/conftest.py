"""Fixtures compartidas para los tests E2E de la API.

Montan la app FastAPI real sobre una BD SQLite EN MEMORIA (aislada por test,
con `StaticPool` para que todas las conexiones compartan la misma base) y la
siembran con los datos de demo (`sembrar`). La app se ejerce en proceso vía
transporte ASGI de httpx (sin abrir puertos ni levantar servidor).
"""
from __future__ import annotations

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app
from app.services.seed import sembrar


@pytest_asyncio.fixture
async def engine():
    """Motor SQLite en memoria, aislado por test, con las tablas creadas."""
    eng = create_async_engine(
        "sqlite+aiosqlite://",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    await eng.dispose()


@pytest_asyncio.fixture
async def Session(engine):
    """Sessionmaker ligado al motor de test (para sembrar y para `get_db`)."""
    return async_sessionmaker(
        bind=engine, class_=AsyncSession, expire_on_commit=False, autoflush=False
    )


@pytest_asyncio.fixture
async def client(Session):
    """Cliente httpx sobre la app real, con la BD de test sembrada.

    Siembra los datos de demo y sustituye la dependencia `get_db` por una que
    entrega sesiones del motor de test.
    """
    async with Session() as db:
        await sembrar(db)

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
        yield c
    app.dependency_overrides.clear()
