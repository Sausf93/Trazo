"""Configuración de la aplicación, leída del entorno (.env)."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Base de datos
    database_url: str = "postgresql+asyncpg://trazo:trazo@localhost:5432/trazo"

    # JWT
    jwt_secret: str = "dev-secret-cambiar"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480

    # CORS (cadena separada por comas)
    cors_origins: str = "http://localhost:5173,http://localhost:3000"

    # Comportamiento de arranque
    seed_on_startup: bool = True
    app_timezone: str = "Europe/Madrid"

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
