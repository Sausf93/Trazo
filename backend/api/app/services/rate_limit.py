"""Rate-limit en memoria para frenar fuerza bruta en el login.

MVP de un solo proceso: un diccionario en memoria basta. Si algún día se
escala a varios workers/instancias, esto se sustituye por Redis, pero la
interfaz (`comprobar` / `registrar_fallo` / `limpiar`) se mantiene.

Ventana deslizante por clave (IP + email): se guardan los instantes de los
intentos FALLIDOS; un login correcto limpia el contador de esa clave.
"""
from __future__ import annotations

import time
from collections import defaultdict


class LimitadorIntentos:
    def __init__(self, max_intentos: int = 5, ventana_seg: float = 300.0) -> None:
        self.max_intentos = max_intentos
        self.ventana_seg = ventana_seg
        self._fallos: dict[str, list[float]] = defaultdict(list)

    def _poda(self, clave: str, ahora: float) -> list[float]:
        """Descarta los fallos fuera de la ventana y devuelve los vigentes."""
        limite = ahora - self.ventana_seg
        vigentes = [t for t in self._fallos.get(clave, []) if t > limite]
        if vigentes:
            self._fallos[clave] = vigentes
        else:
            self._fallos.pop(clave, None)
        return vigentes

    def segundos_bloqueo(self, clave: str, ahora: float | None = None) -> int:
        """Si la clave está bloqueada, segundos que faltan; 0 si puede intentar."""
        ahora = time.monotonic() if ahora is None else ahora
        vigentes = self._poda(clave, ahora)
        if len(vigentes) < self.max_intentos:
            return 0
        # Se desbloquea cuando el fallo más antiguo salga de la ventana.
        libera_en = vigentes[0] + self.ventana_seg
        return max(1, int(libera_en - ahora) + 1)

    def registrar_fallo(self, clave: str, ahora: float | None = None) -> None:
        ahora = time.monotonic() if ahora is None else ahora
        self._poda(clave, ahora)
        self._fallos[clave].append(ahora)

    def limpiar(self, clave: str) -> None:
        """Login correcto: se olvida el historial de fallos de esa clave."""
        self._fallos.pop(clave, None)


# Instancia compartida por la app (5 fallos cada 5 min por IP+email).
limitador_login = LimitadorIntentos(max_intentos=5, ventana_seg=300.0)
