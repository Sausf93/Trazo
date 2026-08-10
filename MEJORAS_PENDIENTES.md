# Roadmap de mejoras — revisión multidisciplinar

Consolidación de una revisión con 6 perspectivas (arquitecto de software, UX de
producto, terapeuta ocupacional, integradora "Laura", neuropsicólogo y usuario
anciano). Marca lo ya aplicado y prioriza lo pendiente.

## ✅ Rediseño de la medición (hecho, validado por 3 expertos)

- **Autocorrección del resultado** (`services/correccion.py`): la app puntúa sola
  cada actividad (logrado/parcial/no_logrado/sin_valorar) con reglas del TO.
- **Resultado y ayuda separados**: la ayuda la marca la integradora por actividad
  concreta; nunca cambia el resultado ni dispara alertas sola.
- **Vigilar la desconexión** (`detectar_missingness`): dejar de participar avisa
  por sí mismo; lo "sin valorar" se cuenta y se muestra, no se esconde.
- **Marcado en la tablet**: la maestra solo marca "le ayudé" y resuelve la cola
  de revisión inline; el resto lo corrige la app.

Pendiente de este bloque (Laura, no bloquea): marcar "le ayudé" en lote a las
últimas 3-4 de golpe, atajo "hoy va con ayuda en todo", y una cola de revisión
agrupada por persona al cerrar la sesión.

## ✅ Ya aplicado en rondas anteriores

- **Integridad de la medición**: el intento nace `sin_valorar` y NO cuenta como
  acierto hasta que la integradora lo marca (antes se inflaba solo). Excluido de
  rendimiento, evolución y alertas; contabilizado aparte.
- **Reencuadre clínico**: "cambio en el desempeño", no "deterioro"; el informe a
  la familia no muestra alarmas automáticas; descargo con causas alternativas;
  se quita el umbral absoluto de ayuda (≥30%).
- **Seguridad de producción**: la demo (credenciales conocidas) solo se siembra
  en `ENTORNO=dev`; aviso por log; `.env.example` documentado.
- **UX panel**: contraste WCAG AA (coral profundo), `textFaint` unificado, nav
  renombrada ("En directo" / "Historial de sesiones").
- **UX tablet**: aviso de sin conexión, botones de medición grandes, spinner en
  "¡Muy bien!", nombre siempre entero, rehacer trazo grande, enunciado acotado,
  sin texto técnico al mayor, memoria sin cuenta atrás roja.

## 🔴 Alta prioridad pendiente

1. **Marcado por actividad, no solo la última** (Laura #2, psicólogo): permitir
   a la integradora tocar a una persona y corregir las últimas 3-4 actividades
   de hoy. Hoy solo se valora el último intento.
2. **Avisar de quién se atasca** (Laura #3): que las fichas de personas atascadas
   salten arriba y con sonido/vibración; ordenar el monitor por urgencia.
3. **Gestión de usuarios finales** (Laura #4, UX #5): pantalla para que la
   integradora dé de alta/baja y edite personas del centro (hoy no existe).
4. **Fiabilidad de alertas** (psicólogo #4/#5/#10): descartar las primeras N
   sesiones (efecto aprendizaje), subir baseline mínimo (≥8), ventana reciente
   ≥3 y también en tiempo calendario, ponderar por nº de intentos, calibrar la
   tasa de falsos positivos con datos simulados antes de mostrar alertas.
5. **Mensajes de error humanos** (UX #3): mapear `err.toString()` a frases
   claras con reintento; nunca mostrar trazas técnicas a la integradora.

## 🟠 Media prioridad

6. **Lectura en voz alta (TTS)** del enunciado y del nombre (anciano #2, Laura
   #6): botón "escuchar" con `flutter_tts`. Requiere pruebas en tablet real.
7. **Foto para identificarse** (Laura #5): que cada persona se reconozca por su
   cara, no por el nombre escrito. Necesita subida/almacenado de foto (RGPD).
8. **Feedback de "hecho"** al mayor (anciano #1): confirmar que su respuesta
   quedó guardada, sin juzgar acierto/error (decisión terapéutica).
9. **Notas por persona + reabrir sesión** (Laura #10): nota corta por persona en
   el resumen y reapertura de una sesión recién cerrada.
10. **Acciones desde el panel web** (Laura #7, UX): marcar/enviar desde "En
    directo", o dejar clarísimo que es solo lectura.
11. **Buscar/filtrar personas** (Laura #9, UX): buscador y filtro "con alerta"
    en el panel principal.
12. **Exportar informes en lote** (Laura #8): varios PDF a la vez y export a hoja
    de cálculo del resumen mensual.
13. **Estado sin_valorar automático** (TO #7): detectar "sin interacción" en cada
    widget y proponer `no_completado` en vez de dejarlo sin valorar.
14. **Contenido clínico** (TO): variantes fáciles de memoria/función ejecutiva y
    media/difícil de praxias; bloque de dinero menos exigente (reconocimiento);
    marcar tareas dependientes de lectura; botón "No lo sé"; orientación a la
    realidad y comprensión de órdenes; equilibrar cancionero adulto.
15. **Métrica de trazo** (TO #3): añadir cobertura del recorrido y dirección,
    no solo precisión (evita sobrestimar la praxis).
16. **Consentimiento específico** (psicólogo #8): separar consentir usar la
    actividad de consentir la monitorización/reporte; figura de representante.

## 🟡 Arquitectura / plataforma (antes de escalar)

17. **Alembic** en vez de micro-migraciones (arquitecto #1).
18. **Índices** en claves foráneas y en `intentos(usuario, ejercicio, ts)`;
    sacar la evaluación de alertas del POST de intento (background) (arquitecto #2).
19. **Rate-limit en Redis** (multi-worker) (arquitecto #5).
20. **Versionado de API** `/v1` (tablets viejas por APK) (arquitecto #6).
21. **Sync offline** a `sqflite`/`drift` con backoff (arquitecto #7).
22. **Token de dispositivo** con rotación/caducidad (arquitecto #8).
23. **Despliegue endurecido** (imagen prod no-root, sin reload) y observabilidad
    (logs estructurados, APM) (arquitecto #9/#10).

## 🟢 Comercial / web

24. **Formulario de demo** a un servicio/endpoint (no `mailto`) + dominio propio
    de contacto (UX landing #1/#2).
25. **Prueba social** en la landing (piloto, cita de una facilitadora) (UX #9).
26. **Vídeo demo** de la app funcionando en el hero (idea de Amy).
