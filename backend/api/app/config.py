"""Configuración de la aplicación, leída del entorno (.env)."""
from functools import lru_cache

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_JWT_SECRET_DEV = "dev-secret-cambiar"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Entorno: "dev" | "prod". En prod se exige un JWT_SECRET propio (ver validador).
    entorno: str = "dev"

    # Base de datos
    database_url: str = "postgresql+asyncpg://trazo:trazo@localhost:5432/trazo"
    # SSL para Postgres gestionado (Aiven/Supabase/etc. lo exigen). asyncpg NO
    # entiende ?sslmode= en la URL, así que se activa con este flag: DB_SSL=true.
    db_ssl: bool = False

    # JWT
    jwt_secret: str = _JWT_SECRET_DEV
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480

    # CORS (cadena separada por comas)
    cors_origins: str = "http://localhost:5173,http://localhost:3000"

    # Comportamiento de arranque. La siembra de datos de DEMO (que crea cuentas
    # con contraseña conocida) solo debe ocurrir en dev: además de este flag, el
    # arranque exige entorno == "dev" para sembrar (ver main.py). Así un
    # despliegue de producción no queda con credenciales de demo aunque olvide
    # apagar el flag.
    seed_on_startup: bool = True
    app_timezone: str = "Europe/Madrid"

    # Token de PLATAFORMA (nivel 0): protege el alta de centros + su primer admin
    # (POST /plataforma/centros). Si está vacío, ese endpoint queda DESHABILITADO.
    # Solo lo conoce el dueño de la plataforma (tú). Nunca se expone al panel.
    platform_token: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @model_validator(mode="after")
    def _exigir_secreto_en_prod(self) -> "Settings":
        """Fail-fast: en producción NO se arranca con el secreto JWT por defecto.

        Evita firmar tokens con un secreto público conocido (falsificación de
        credenciales de cualquier staff/centro). En dev se permite el default.
        """
        if self.entorno.lower() != "dev" and self.jwt_secret == _JWT_SECRET_DEV:
            raise ValueError(
                "JWT_SECRET no definido: en producción (ENTORNO!=dev) debes fijar "
                "un secreto propio en el entorno."
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
