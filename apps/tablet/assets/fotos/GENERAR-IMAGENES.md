# Fotos reales de objetos — pipeline gratis (probado)

`assets/fotos/` tiene PRIORIDAD sobre el SVG: basta dejar `<id>.png` (con
transparencia) y registrarlo en `_fotos` de `lib/widgets/ilustracion.dart`
(por id CANÓNICO; los alias lo heredan). Reversible: si una foto no gusta, se
borra del mapa y vuelve el dibujo.

## Regla de oro (mayor)
Un ÚNICO objeto, inequívoco, sin personas/manos/escena (ni platos, cuencos,
jarrones), completo y centrado. Ante la duda, se descarta.

## Pipeline gratis que funcionó (piloto)
Todo local/gratis, sin cuentas ni pagos:

1. **Generar** (gratis, sin clave) con Pollinations:
   `https://image.pollinations.ai/prompt/<PROMPT>?width=768&height=768&nologo=true&model=flux&seed=N`
   Prompt e-commerce anti-escena:
   `"{objeto en inglés}, isolated product cutout on a plain pure white seamless background, entire single object centered, high-key studio lighting, no shadow, no table, no plate, no bowl, no dish, no vase, no other objects, no people, no hands, no text, realistic sharp photo"`
   Generar **3 candidatas por objeto** (seeds distintas): el modelo mete escena a
   menudo, hace falta margen.
2. **Revisar con agentes** (un agente por objeto): abre las 3 candidatas (Read) y
   elige la mejor que cumpla la regla de oro, o descarta las 3. Muchas se caen por
   plato/cuenco/jarrón/persona → normal.
3. **Recortar el fondo** con rembg (gratis, local; modelo bria-rmbg):
   `from rembg import remove; remove(Image.open(x).convert('RGBA')).save(y)`
   Deja fondo transparente → limpísimo en las tarjetas de la app.
4. **Integrar**: copiar a `assets/fotos/<id>.png`, añadir al mapa `_fotos`,
   `flutter build web` + desplegar la tablet.

## Límites observados (Pollinations/FLUX gratis)
- Insiste en escena: queso/cuchara en plato, huevo en cuenco, flor en jarrón.
- No hace bien: llaves, gafas (mete cara), relojes (números ilegibles).
- Rinde ~5 de 12 objetos limpios. Para el resto: seguir con SVG, hacer más
  intentos, o tomar una FOTO real con el móvil (objeto sobre fondo liso) y
  pasarla por rembg (paso 3) — la vía más fiable y también gratis.

## Piloto actual desplegado
`manzana, vaso, botella, taza, pan` (fotos reales recortadas). El resto siguen
con su dibujo SVG. Comparar en la tablet y decidir si se amplía.
