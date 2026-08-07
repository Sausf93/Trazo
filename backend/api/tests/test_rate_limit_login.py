"""El login se bloquea temporalmente tras varios fallos (anti fuerza bruta)."""
from __future__ import annotations

import pytest

from app.services.rate_limit import LimitadorIntentos, limitador_login

INTEGRADORA = ("integradora@trazo.local", "trazo1234")


def test_limitador_unitario_bloquea_y_reinicia():
    lim = LimitadorIntentos(max_intentos=3, ventana_seg=100.0)
    clave = "ip:mail"
    # Reloj inyectado para no depender del tiempo real.
    for i in range(3):
        assert lim.segundos_bloqueo(clave, ahora=i) == 0
        lim.registrar_fallo(clave, ahora=i)
    # Cuarto intento dentro de la ventana -> bloqueado.
    assert lim.segundos_bloqueo(clave, ahora=3) > 0
    # Un login correcto (limpiar) reinicia el contador.
    lim.limpiar(clave)
    assert lim.segundos_bloqueo(clave, ahora=3) == 0


def test_limitador_expira_pasada_la_ventana():
    lim = LimitadorIntentos(max_intentos=2, ventana_seg=60.0)
    clave = "ip:mail"
    lim.registrar_fallo(clave, ahora=0)
    lim.registrar_fallo(clave, ahora=1)
    assert lim.segundos_bloqueo(clave, ahora=2) > 0
    # Pasada la ventana, los fallos viejos ya no cuentan.
    assert lim.segundos_bloqueo(clave, ahora=200) == 0


@pytest.mark.asyncio
async def test_login_429_tras_muchos_fallos(client):
    email = "fuerzabruta@trazo.local"  # aislado: no toca la clave de otros tests
    try:
        # 5 contraseñas incorrectas -> 401.
        for _ in range(5):
            r = await client.post(
                "/auth/login", data={"username": email, "password": "mal"}
            )
            assert r.status_code == 401, r.text
        # El sexto intento (aunque la contraseña fuese buena) -> 429.
        r = await client.post(
            "/auth/login", data={"username": email, "password": "mal"}
        )
        assert r.status_code == 429, r.text
        assert "Retry-After" in r.headers
    finally:
        # No dejar la clave sucia para el resto de la suite.
        limitador_login.limpiar(f"testclient:{email}")
