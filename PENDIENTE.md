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
      versión "de marca" más trabajada, encargar/diseñar y sustituir. (A Saulo no
      le convence del todo; lo comentará con su pareja. Está centralizado: cambiarlo
      es rápido — Logo.tsx en web, símbolo SVG en landing, favicon data-URI, y la
      tablet.)
- [ ] **Unificar logo/favicon en la app tablet** (aún tiene el de Flutter por defecto).
      Se hace en la reorientación maestra/kiosco.
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
- [x] Backend: motor de auto-sugerencia de nivel (propone, el profesional aprueba). ✅
- [x] Backend: ciclo de sala (nombre, iniciar, cerrar, /sesiones/activa). ✅
- [x] Tablet: modo **kiosco participante** (reposo → "¿quién eres?" → reparto por toque → cola con las 8 actividades y mediciones). ✅
- [x] Tablet: modo **maestra** (abrir sala + monitor en vivo + marcar ayuda + iniciar/cerrar). ✅
- [x] Tablet: logo/favicon unificado. ✅
- [x] Web: editor de plan por paciente + gestión de dispositivos. ✅
- [x] Tests E2E del flujo de sesión (28 en verde). ✅
- [ ] Web: UI para **aprobar sugerencias de nivel** (endpoint listo, falta pantalla).
- [ ] Tablet: "Ayuda" antes de que exista el intento (hoy marca el último intento; refinar con flag de sesión-participante).
- [ ] Visual: subir las actividades de la tablet a ilustración (librería SVG + flutter_svg) — EN CURSO.
- [ ] **Niveles de dificultad por CANTIDAD** (decidido con Saulo): el `nivel` del plan
      (bajo/medio/alto) debe fijar cuántas imágenes/objetos tiene el ejercicio →
      **básico ~3 · intermedio ~6-8 · alto ~10-12**. Aplica a memoria, contar,
      reconocer, etc. Falta: mapear nivel→cantidad en el motor de plantillas y que el
      `nivel` de la cola llegue a la generación de instancia (hoy no se pasa) + tablet.
- [x] Preparar el stack Docker (compose db+api+web+tablet, Dockerfiles, YAML validado). ✅
- [ ] Ejecutar/probar en Docker — requiere instalar Docker Desktop (hoy solo el cliente).
- [ ] **Grafomotricidad: guía de dirección del trazo** (apunte de Laura). Muchos
      mayores nunca aprendieron a escribir bien y no saben por dónde EMPEZAR ni en
      qué SENTIDO trazar cada letra. En los ejercicios `trazo` (seguir líneas,
      letras, palabras) mostrar: (a) un **punto de inicio** marcado y (b) **flechas
      de dirección** a lo largo de la línea guía indicando el recorrido (para letras,
      el orden/sentido de cada trazo). Se implementa en `trazo_widget` usando la
      dirección/tangente del propio path (y, para letras con varios trazos, que el
      guide_path lleve el orden correcto).
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
