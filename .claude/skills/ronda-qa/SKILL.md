---
name: ronda-qa
description: Lanzar una ronda de QA multi-agente sobre Trazo — agentes que revisan o "juegan" la app desde distintas lentes/personas (mayor con Alzheimer, baja visión, maestra, comprador exigente), verifican en local y devuelven bugs/pulido/mejoras priorizados. Úsala cuando Saulo pida "revisa con agentes", "otra ronda", "prueba los juegos", "ponte en la piel de…" o quiera pulir antes de subir.
---

# Ronda de QA multi-agente

Patrón probado (rondas 1–5) para encontrar y priorizar mejoras antes de desplegar.
Se lanza con la herramienta **Workflow** (opt-in de multi-agente). Contexto en `AGENTS.md`.

## Cómo montarla
1. **Elige lentes** distintas y complementarias, cada una un agente en paralelo. Ejemplos ya usados:
   - Por familia de juego: trazo+selección · memoria+búsqueda · conteo+dinero · ordenar+arrastrar.
   - Por persona: mayor con Alzheimer (sesión entera) · baja visión/temblor · la maestra operando · comprador exigente vs NeuronUP.
   - Por dimensión: valor clínico/producto · accesibilidad · contenido del catálogo · seguridad/RGPD/multi-tenant · robustez (WiFi inestable).
2. **Cada agente trabaja EN LOCAL** (nunca prod, sin credenciales): genera instancias reales con los generadores de `app/templates/tipos.py` o levanta el backend en proceso (ver `backend/api/tests/conftest.py`), lee el widget Flutter que pinta cada actividad y comprueba `correccion.py`. Que "juegue" y narre la vivencia de su persona.
3. **Salida estructurada** por agente con `schema`: `{area, resumen, bugs[], pulido[], mejoras[]}` (bugs = defectos reproducidos; pulido = rompe la sensación de producto perfecto; mejoras = subir valor). Un agente **sintetizador** final deduplica y da veredicto (`sí/casi/no` perfecto) + roadmap priorizado.
4. **NO metas credenciales de producción en los prompts** (el clasificador de seguridad bloquea el agente por credential-leak; ya pasó en la ronda 4). Los agentes no las necesitan: trabajan local.
5. **Dales la lista de lo ya arreglado** en rondas previas para que no lo re-reporten.

## Tamaño y límites
- ~6–8 lentes + 1 síntesis. Guía "medium" (<15 agentes).
- Si saltan errores "session limit", **reintenta con `resumeFromRunId`**: los agentes completados salen de caché y solo re-corren los que fallaron.
- El script se guarda en `_deploy/rondaN-*.js`; itera editándolo y re-invocando Workflow con `scriptPath`.

## Después de la ronda
1. Aplica primero los **bloqueantes** (medición clínica, crashes, callejones sin salida), luego el pulido barato de alto valor. Deja los rediseños grandes (layout espacial, TTS, escalado de dificultad, features nuevas) como **roadmap** para que Saulo priorice.
2. Verifica en verde (`pytest` + `tsc` + `flutter analyze`).
3. Si tocaste backend o frontend, usa la skill **desplegar**.
4. Deja constancia en la memoria del proyecto (`trazo-despliegue-gcp`).
