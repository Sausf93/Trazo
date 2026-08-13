"""Motor async de SQLAlchemy y sesión de base de datos."""
from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

# SSL para Postgres gestionado. Equivale a `sslmode=require`: cifra la conexión
# pero NO verifica la CA (Aiven/varios usan una CA propia autofirmada, que un
# contexto por defecto rechazaría). Para pruebas es lo correcto; en producción
# estricta se puede pasar a verify-ca con el certificado de la CA del proveedor.
# SQLite u otros no llevan connect_args.
_connect_args: dict = {}
if settings.db_ssl and settings.database_url.startswith("postgresql"):
    import ssl as _ssl

    _ctx = _ssl.create_default_context()
    _ctx.check_hostname = False
    _ctx.verify_mode = _ssl.CERT_NONE
    _connect_args["ssl"] = _ctx

engine = create_async_engine(
    settings.database_url,
    echo=False,
    pool_pre_ping=True,
    connect_args=_connect_args,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    """Base declarativa para todos los modelos ORM."""


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependencia de FastAPI: entrega una sesión y la cierra al terminar."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
