# -*- coding: utf-8 -*-
"""Calidad del CONTENIDO que ve/oye el mayor: sin opciones duplicadas visibles,
sin concordancia rota de artículo ('una reloj'), sin silueta sobre foto opaca
(cuadro negro), y sin referencias a imágenes inexistentes. Corre en pytest para
que el contenido malo NO pueda desplegarse (estas clases de bug ya reaparecieron)."""
import json
import os
import random
import re
import unicodedata

from app.templates.registry import get_plantilla

_BASE = os.path.dirname(__file__)
_CAT = os.path.join(_BASE, "..", "app", "data", "catalogo.json")
_ILUS = os.path.join(_BASE, "..", "..", "..", "apps", "tablet", "lib", "widgets", "ilustracion.dart")

with open(_CAT, encoding="utf-8") as f:
    CATALOGO = json.load(f)

with open(_ILUS, encoding="utf-8") as f:
    _il = f.read()
# ids de ilustración conocidos: TODO token entre comillas (claves de mapas, alias,
# case de dibujos vectoriales y sets como las caras de emoción 'cara_alegria').
IDS = set(re.findall(r"'([a-z0-9_]+)'", _il))
# figuras geométricas que también son ids válidos de render (no ilustración)
IDS |= {"circulo", "cuadrado", "triangulo", "estrella", "corazon", "rombo", "ovalo", "rectangulo"}

# Fotos OPACAS (sin recorte alfa): con degradado='silueta' saldrían como cuadro
# negro. No deben usarse en silueta hasta recortarlas con alfa.
FOTOS_OPACAS = {"cactus", "campana", "candado", "estrella", "delfin", "faro",
                "jamon", "maleta", "montana", "nube"}

# Sustantivos masculinos frecuentes: 'una <estos>' es concordancia rota.
MASC = set(
    "reloj tenedor plato cuchillo espejo zapato paraguas sofa bol caballo telefono "
    "avion arbol autobus tren coche camion martillo destornillador bolso vaso libro "
    "pan queso globo huevo tambor abanico candado cactus delfin elefante pez perro "
    "gato pato banco cubo boton baston violin jamon limon platano pimiento peine "
    "cepillo lapiz boligrafo pajaro faro cerdo pantalon vestido tomate barco conejo "
    "calcetin".split()
)


def _sinac(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn").lower()


def _seleccion():
    return [e for e in CATALOGO if e["plantilla_tipo"] == "seleccion_multiple"]


def test_sin_opciones_visibles_duplicadas():
    for e in _seleccion():
        p = e["parametros_json"]
        inst = get_plantilla("seleccion_multiple").generar(p, nivel="medio", rng=random.Random(0))
        opciones = [str(o).strip().lower() for o in inst.render.get("opciones", [])]
        assert len(opciones) == len(set(opciones)), (e["nombre"], "opciones duplicadas", opciones)


def test_concordancia_articulo_masculino():
    for e in _seleccion():
        for it in e["parametros_json"].get("items", []):
            for op in [it.get("correcta", "")] + list(it.get("distractores", [])):
                m = re.match(r"^una\s+([A-Za-zÁÉÍÓÚáéíóúñÑ]+)$", str(op).strip())
                if m and _sinac(m.group(1)) in MASC:
                    raise AssertionError((e["nombre"], "concordancia rota", op))


def test_silueta_no_sobre_foto_opaca():
    for e in _seleccion():
        for it in e["parametros_json"].get("items", []):
            if it.get("degradado") == "silueta":
                img = str(it.get("imagen", ""))
                assert img not in FOTOS_OPACAS, (e["nombre"], "silueta sobre foto opaca", img)


def test_imagenes_referenciadas_existen():
    faltan = set()
    for e in _seleccion():
        for it in e["parametros_json"].get("items", []):
            img = it.get("imagen")
            if img and img not in IDS:
                faltan.add((e["nombre"], img))
    assert not faltan, ("imágenes inexistentes", sorted(faltan)[:20])
