# Documentos legales (BORRADORES)

> ⚠️ **Estos documentos son borradores orientativos generados con IA. NO son
> asesoramiento jurídico.** Antes de usarlos con pacientes reales, **debe
> revisarlos y adaptarlos un abogado especializado en protección de datos y/o un
> DPO**. Se tratan datos de salud (categoría especial, art. 9 RGPD) de personas
> vulnerables: el margen de error legal es muy bajo. Los campos a rellenar están
> marcados **[ENTRE CORCHETES]**.

Punto de partida para cerrar los bloqueantes legales del piloto (ver
`../MEJORAS_PENDIENTES.md`). Modelo de roles: el **centro es responsable** del
tratamiento; **Trazo es encargado**.

| Documento | Para qué |
|---|---|
| [00-CHECKLIST.md](00-CHECKLIST.md) | Los 6 bloqueantes legales, con pasos concretos y orden. |
| [01-contrato-encargo-tratamiento.md](01-contrato-encargo-tratamiento.md) | Contrato de encargo (art. 28 RGPD) centro ↔ Trazo. |
| [02-consentimiento-informado.md](02-consentimiento-informado.md) | Consentimiento (titular o representante legal/tutor). |
| [03-DPIA-evaluacion-impacto.md](03-DPIA-evaluacion-impacto.md) | Evaluación de Impacto (EIPD/DPIA, art. 35 RGPD). |

**Orden recomendado:** cerrar 1 (entidad), 2 (contrato), 4 (DPIA) y 5 (cifrado,
ya implementado en el backend) **antes de meter el primer dato real**; firmar el 3
**antes de dar de alta a cada paciente**; probar el 6 (restauración de backup)
**antes de considerar el sistema operativo**.
