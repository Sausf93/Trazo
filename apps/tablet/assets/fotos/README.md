# Fotos reales de objetos (sustituyen a las ilustraciones)

Aquí se van poniendo **fotografías reales** de objetos cotidianos. Cuando existe
una foto para un objeto, la app la usa **en lugar del dibujo SVG** (los usuarios
mayores reconocen mejor una foto real). Es la estrategia de "ir sustituyendo poco
a poco" los dibujos por fotos.

## Cómo añadir una foto
1. Guarda la imagen aquí con el **id del objeto** como nombre, en minúsculas y con
   guion_bajo. Ej.: `perro.png`, `jabon.jpg`, `martillo.webp`.
   - Formatos: png / jpg / webp. Fondo preferiblemente blanco o transparente.
2. Regístrala en `lib/widgets/ilustracion.dart`, en el mapa `_fotos`:
   ```dart
   'perro': 'assets/fotos/perro.png',
   ```
3. Listo: la app usará la foto para ese objeto (y para todos sus alias) en todas
   las actividades. Si no hay foto, sigue usando el dibujo SVG de
   `assets/ilustraciones/`.

Ids disponibles: ver el set `_disponibles` en `ilustracion.dart`.
