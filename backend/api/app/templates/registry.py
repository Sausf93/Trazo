"""Registro de plantillas disponibles."""
from __future__ import annotations

from app.templates.base import PlantillaBase
from app.templates.tipos import (
    PlantillaArrastrarPosicion,
    PlantillaBusqueda,
    PlantillaConteoComparacion,
    PlantillaManejoCantidad,
    PlantillaMemoriaVisual,
    PlantillaParejas,
    PlantillaRetoCruzar,
    PlantillaRetoGarrafas,
    PlantillaRetoHanoi,
    PlantillaRetoMastermind,
    PlantillaRetoRanas,
    PlantillaRetoTaquin,
    PlantillaSecuenciaOrdenar,
    PlantillaSeleccionMultiple,
    PlantillaTrazo,
)

_PLANTILLAS: list[type[PlantillaBase]] = [
    PlantillaTrazo,
    PlantillaSeleccionMultiple,
    PlantillaMemoriaVisual,
    PlantillaSecuenciaOrdenar,
    PlantillaConteoComparacion,
    PlantillaArrastrarPosicion,
    PlantillaManejoCantidad,
    PlantillaBusqueda,
    PlantillaParejas,
    PlantillaRetoGarrafas,
    PlantillaRetoCruzar,
    PlantillaRetoHanoi,
    PlantillaRetoMastermind,
    PlantillaRetoRanas,
    PlantillaRetoTaquin,
]

REGISTRY: dict[str, PlantillaBase] = {p.tipo: p() for p in _PLANTILLAS}


def get_plantilla(tipo: str) -> PlantillaBase:
    if tipo not in REGISTRY:
        raise KeyError(f"Plantilla desconocida: {tipo!r}. Disponibles: {list(REGISTRY)}")
    return REGISTRY[tipo]


def plantilla_existe(tipo: str) -> bool:
    return tipo in REGISTRY
