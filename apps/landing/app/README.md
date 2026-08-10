# Descargas de la app de tablet (APK)

Esta carpeta se publica en GitHub Pages junto con la web comercial, así que sirve
de canal de descarga y de **aviso de actualización** para las tablets (que no
usan Play Store — ver `apps/tablet/DISTRIBUCION_TABLET.md`).

- `version.json` — lo consulta la app al abrir. Si su `version_code` es mayor que
  el instalado, la tablet muestra un banner con el enlace de descarga.
- `trazo-latest.apk` — el APK firmado más reciente (súbelo aquí al publicar).

## Publicar una versión nueva

1. Sube el número de versión en `apps/tablet/pubspec.yaml`
   (ej. `version: 0.2.0+2` → el `+2` es el `version_code`).
2. Construye el APK firmado (ver la guía de distribución).
3. Copia el APK aquí como `trazo-latest.apk` (o con nombre versionado y ajusta
   `apk_url`).
4. Edita `version.json` con el nuevo `version_code`, `version_name` y `notas`.
5. `git push` — el workflow de Pages lo publica solo. Las tablets avisarán al
   abrirse.

> El APK no se versiona en git (los binarios no van al repo). Se sube al publicar.
