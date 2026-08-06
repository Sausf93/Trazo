"""Utilidades de seguridad: hashing de contraseñas y JWT."""
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.config import settings


# ---- Contraseñas (bcrypt directo, sin passlib para evitar problemas de compat) ----

def hash_password(plain: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(plain.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# ---- JWT ----

def create_access_token(subject: str, extra: dict | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload: dict = {
        "sub": subject,
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict:
    """Devuelve el payload; lanza jwt.PyJWTError si es inválido/expirado."""
    return jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
