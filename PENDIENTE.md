# Trazo — Pendientes

Lista viva de cosas por hacer/decidir. Marca con `[x]` lo que se cierre.

## Web comercial (`apps/landing/`)
- [ ] **Email comercial propio** — ahora se usa el personal (`saulodlsf@gmail.com`).
      Para dar imagen profesional, registrar algo tipo `hola@trazo.app` /
      `info@trazo.es` y cambiarlo en `apps/landing/index.html` (aparece en:
      sección contacto, `EMAIL_DESTINO` del `<script>`, y footer).
- [ ] **Teléfono de contacto** — hay un placeholder `+34 600 000 000`, poner el real
      (o quitarlo si preferís solo email/formulario).
- [ ] **Dominio** — decidir dominio (`trazo.app`, `trazo.es`...) y hosting
      (Netlify/Vercel/GitHub Pages sirven para el HTML estático).
- [ ] **Precio del plan "Centro"** — ahora dice "Consúltanos". Definir importe/rango.
- [ ] **Aviso legal y Política de privacidad** — el footer enlaza a `#` (vacío).
      Redactar ambas páginas (obligatorio por RGPD al tratar datos de salud).
- [ ] **Formulario de contacto real** — ahora abre el correo del usuario (`mailto:`).
      Si se quiere recepción automática, conectar a un servicio (Formspree, un
      endpoint propio, etc.).
- [ ] **Logo definitivo** — hay un logo SVG propio hecho a mano; si se quiere una
      versión "de marca" más trabajada, encargar/diseñar y sustituir.
- [ ] **Textos e imágenes** — revisar copy con Laura; añadir capturas reales del
      producto cuando estén pulidas.
- [ ] (Opcional) **Testimonios reales** — cuando haya centros piloto, añadir prueba
      social real (NO inventar).

## Modelo operativo maestra/esclava — ver `docs/MODELO-OPERATIVO.md`
Decisiones tomadas: plan por paciente (mixto dominios+concretos) + modo grupo;
tablets emparejadas al centro una vez; niveles por auto-sugerencia aprobada; fin
de sesión por nº de ejercicios del plan. Reorienta la app hacia dos caras
(maestra + kiosco de participante). Implementación pendiente:
- [x] Backend: entidad `planes_paciente` (líneas: dominio/ejercicio + nivel + nº por sesión). ✅
- [x] Backend: entidad `dispositivos` (tablets emparejadas al centro, token revocable). ✅
- [x] Backend: campo `modo` en sesión (individual/grupo) + ejercicio compartido. ✅
- [x] Backend: construir la "cola" de ejercicios de cada participante desde su plan. ✅ (`/usuarios/{id}/cola`)
- [ ] Backend: motor de auto-sugerencia de nivel (propone, el profesional aprueba). ← pendiente
- [ ] Tablet: modo **kiosco participante** (reposo → "¿quién eres?" → reparto por toque → cola).
- [ ] Tablet: modo **maestra** (montar sesión + monitor en vivo 3-en-3 + marcar ayuda + seguimiento).
- [ ] Web: editor de plan por paciente + aprobar sugerencias + gestión de dispositivos.
- [ ] Decidir detalles menores (rotación de ejercicios, umbral atascado, PIN de recuperación).

## App tablet (`apps/tablet/`) — base actual (andamiaje)
- [x] Instalar Flutter y verificar compilación — OK (Flutter 3.44.8, `build web` sin errores, la app bootea).
- [ ] Prueba visual del dibujo/interacción en el navegador (abrir la app y probar).
- [x] Renderers específicos para las 8 plantillas — ✅ las 8 jugables (trazo, selección,
      memoria, ordenar, contar/comparar, arrastrar, evocación, dinero/reloj).
- [ ] Offline robusto con `drift`/`sqflite` (ahora: cola simple con
      `shared_preferences`).
- [ ] Modo kiosco real (Guided Access iPad / kiosk Android).

## Backend / infra
- [ ] Migraciones con Alembic (ahora se crean tablas con `create_all` al arrancar).
- [ ] Desplegar en servidor (Oracle Cloud + Coolify, según el plan original).
- [ ] Bot de Telegram para alertas técnicas (servidor caído, sync fallida).
- [ ] Modo demo con datos sintéticos para enseñar a otros centros.

## Producto / negocio
- [ ] Fase 0 del plan: hablar con el centro (¿piloto informal?).
- [ ] Acuerdo de encargado de tratamiento (RGPD) con el centro.

## Datos de contacto usados actualmente (temporales)
- Nombre: Saulo Santacruz
- Email: saulodlsf@gmail.com
- Teléfono: (pendiente)
