# Trazo — Web comercial (landing)

Página de marketing autocontenida (un solo `index.html`, sin dependencias de
build). Inspirada en la estructura de plataformas del sector (p. ej. neuronup.com),
con la identidad visual de Trazo.

## Verla

Basta con abrir el archivo en el navegador:

```
apps/landing/index.html
```

O servirla en local:

```powershell
cd apps/landing
python -m http.server 8080
# luego abrir http://localhost:8080
```

## Secciones

Hero · para quién · 3 pilares · 8 bloques de ejercicios · cómo funciona (4 pasos) ·
detección temprana · precios (piloto / centro / red) · contacto con formulario ·
footer con aviso legal.

El formulario de contacto abre el correo del usuario con el mensaje preparado
(`mailto:`), así funciona sin backend.

## ⚠️ Marcadores a rellenar antes de publicar

Busca la etiqueta visual **"cambiar"** en la sección de contacto y sustituye:

- **Email** de contacto (ahora `hola@trazo.app`) — también en el `<script>`
  (`EMAIL_DESTINO`) y en el footer.
- **Teléfono** (ahora `+34 600 000 000`).
- **Precios**: el plan "Centro" pone "Consúltanos"; ponle importe cuando lo tengáis.
- Enlaces de **Aviso legal / Privacidad** del footer (ahora `#`).

## Publicar

Al ser un HTML estático se puede subir a cualquier hosting (Netlify, Vercel,
GitHub Pages, un bucket, etc.). Usa Google Fonts por CDN; si lo quieres 100%
offline, se pueden incrustar las fuentes.
