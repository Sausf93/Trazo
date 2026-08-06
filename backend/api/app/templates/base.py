"""Contrato base de una plantilla de ejercicio."""
from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Any


@dataclass
class InstanciaEjercicio:
    """Una tirada concreta de un ejercicio, lista para que la tablet la pinte.

    - `render`: todo lo que el cliente necesita para dibujar el ejercicio.
    - `cantidad_objetivo`: las cantidades/opciones elegidas ESTA vez. Se guarda
      en el intento (`cantidad_objetivo_json`) para que la comparación histórica
      de alertas sea justa aunque cambie la dificultad después.
    - `solucion`: respuesta esperada. El backend la conserva; según el ejercicio
      puede enviarse o no al cliente (para evitar que se pueda "adivinar").
    - `metricas`: nombres de las métricas que este tipo de ejercicio produce.
    """

    plantilla: str
    render: dict[str, Any]
    cantidad_objetivo: dict[str, Any]
    solucion: dict[str, Any] = field(default_factory=dict)
    metricas: list[str] = field(default_factory=list)

    def publico(self, incluir_solucion: bool = False) -> dict[str, Any]:
        """Representación segura para enviar al cliente."""
        data = {
            "plantilla": self.plantilla,
            "render": self.render,
            "cantidad_objetivo": self.cantidad_objetivo,
            "metricas": self.metricas,
        }
        if incluir_solucion:
            data["solucion"] = self.solucion
        return data


class PlantillaBase:
    """Clase base. Cada plantilla concreta define `tipo`, `metricas` y `generar`."""

    tipo: str = "base"
    # Métricas que este tipo produce (para documentación y validación).
    metricas: list[str] = []

    def generar(
        self,
        parametros: dict[str, Any],
        nivel: dict[str, Any] | None = None,
        rng: random.Random | None = None,
    ) -> InstanciaEjercicio:
        raise NotImplementedError

    # -- helpers comunes --

    @staticmethod
    def _rng(rng: random.Random | None) -> random.Random:
        return rng or random.Random()

    @staticmethod
    def _nivel_val(nivel: dict[str, Any] | None, clave: str, defecto: Any) -> Any:
        if nivel and clave in nivel:
            return nivel[clave]
        return defecto
