# Trazo — Guía de piloto y APK

Todo lo que necesitas para pasar de "funciona en el navegador" a "funciona en tablets reales en el centro". Dos partes: **sacar e instalar el APK** y el **ensayo/piloto** para que no falle nada delante de los mayores.

---

## Parte 1 · El APK (la app nativa de la tablet)

### 1.1 Qué necesitas (una vez)
- Un ordenador con **Android Studio** instalado (trae el SDK de Android). *Este equipo actual no lo tiene, por eso el APK hay que sacarlo en una máquina con Android Studio.*
- El proyecto ya está listo (`applicationId = com.trazo.trazo_tablet`).

### 1.2 Generar el APK
En `apps/tablet`:
```bash
flutter build apk --release --dart-define=API_URL=https://trazo-api-11684717030.europe-southwest1.run.app
```
El `.apk` queda en `apps/tablet/build/app/outputs/flutter-apk/app-release.apk`.

> **Firma (solo la 1ª vez, para "release"):** genera una clave con `keytool -genkey -v -keystore trazo.keystore -alias trazo -keyalg RSA -keysize 2048 -validity 10000`, copia `key.properties.example` a `key.properties` con los datos de tu clave, y vuelve a construir. (Para probar rápido puedes usar `flutter build apk --debug` sin firma).

### 1.3 Instalar en cada tablet
1. En la tablet: **Ajustes → Seguridad → Instalar apps de origen desconocido** (actívalo para el gestor de archivos o el navegador).
2. Pasa el `app-release.apk` a la tablet (cable USB, o súbelo a un enlace y descárgalo).
3. Tócalo y **Instalar**.
4. Ábrelo una vez y comprueba que arranca en la pantalla de **emparejar**.

*(Alternativa por USB desde el ordenador: `adb install app-release.apk`.)*

### 1.4 Modo kiosco (para que el mayor no se salga)
- Rápido (nativo Android): **Ajustes → Seguridad → Fijar pantalla** (screen pinning). Abres Trazo, botón de recientes, y "fijas" la app. Para salir hace falta el patrón/PIN.
- Robusto (varias tablets): una app lanzadora de kiosco (p. ej. *Fully Kiosk*) que arranca sola con Trazo y bloquea el resto.

### 1.5 ¿Todas las tablets valen?
- **Un solo APK sirve para todas las tablets Android** modernas (**Android 5.0 / 2015 en adelante**). Comprueba la versión de Android de las que vayáis a usar.
- Los tamaños de pantalla están cubiertos: **probado que las 1.010 actividades caben sin recorte en 7", 8", 10" (vertical y horizontal) y grande**.

---

## Parte 2 · El ensayo (antes de los mayores)

**Regla de oro: nunca estrenéis delante de los mayores. Ensayad primero vosotros.**

### 2.1 Ensayo técnico (tú + Laura, 1 rato, 2-3 tablets)
Recorre el flujo entero y marca cada paso:
- [ ] **Emparejar:** en el panel («Tablets») genera el código; mételo en la tablet; queda vinculada.
- [ ] **Rol MAESTRA:** abre una sala con 2-3 nombres de prueba.
- [ ] **Rol PARTICIPANTE:** elige un nombre y haz **una actividad de cada tipo** (trazo, selección, memoria, parejas, dinero…). Fíjate en: botones grandes, se entiende sin leer, háptico al tocar, no se queda atrapado.
- [ ] **Panel en vivo:** desde el panel/otra tablet, ve el grupo en tiempo real y marca "ayuda".
- [ ] **Medición:** revisa lo "sin valorar", ponle resultado y mira que aparece la evolución.
- [ ] **Prueba de WiFi:** a mitad de una sesión, **apaga el WiFi** de la tablet unos minutos y sigue jugando → debe funcionar offline y sincronizar al volver.
- [ ] **Prueba en 2-3 tablets distintas** (tamaños/marcas distintas si podéis).

### 2.2 Primera sesión real (empieza pequeño)
- [ ] **UN grupo de ~5 personas, UNA integradora, UNA sesión.** No todo el centro de golpe.
- [ ] Ten a mano una tablet de repuesto ya emparejada.
- [ ] Observa y apunta: ¿alguien se pierde? ¿algún botón cuesta? ¿alguna actividad no se entiende?
- [ ] Al acabar: revisa en el panel que se registró todo y que la evolución tiene sentido.

### 2.3 Qué vigilar (los riesgos reales)
- **Hardware viejo:** una tablet lenta o vieja arruina la experiencia. Usa tablets decentes (Android 5+, pantalla ≥7").
- **Manos con temblor / baja visión:** confirma que los objetivos grandes y el háptico les bastan.
- **WiFi del centro:** si es malo, el modo offline lo cubre, pero pruébalo antes.
- **Kiosco puesto:** que no puedan salirse a Ajustes ni cerrar la app.

### 2.4 Cuando funcione
- Amplía a más grupos y más tablets poco a poco.
- Recoge una **frase de Laura o de una integradora** (testimonio) — es oro para vender a otros centros.

---

## Estado actual (verificado)
- **Software probado a escala:** 10 centros, 60 profesionales, 300 personas, 30 salas a la vez → 25/0.
- **Encaje en pantalla:** las 1.010 actividades caben en todas las tablets (0 recortes).
- **Medición clínica:** simulados 3 mayores (estable/Alzheimer/demencia) → mide, ve evolución y avisa de empeoramiento (6/0).
- **Lo único que NO se puede simular:** lo físico (tablets reales, manos, WiFi). Eso lo valida este ensayo.
