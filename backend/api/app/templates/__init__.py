"""Motor de plantillas de ejercicios (data-driven).

Un ejercicio del catálogo NO es código: es una fila con `plantilla_tipo` +
`parametros_json`. Aquí viven las plantillas reutilizables que, dada esa
configuración y el nivel de la persona, generan una "instancia" concreta del
ejercicio (con cantidades cambiantes cada vez) que la tablet renderiza.

Añadir un ejercicio nuevo = insertar una fila en `ejercicios_catalogo`.
Añadir un TIPO de ejercicio nuevo (raro) = añadir una plantilla aquí.
"""
from app.templates.base import PlantillaBase, InstanciaEjercicio
from app.templates.registry import REGISTRY, get_plantilla, plantilla_existe

__all__ = [
    "PlantillaBase",
    "InstanciaEjercicio",
    "REGISTRY",
    "get_plantilla",
    "plantilla_existe",
]
