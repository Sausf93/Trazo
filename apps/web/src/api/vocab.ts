/**
 * Vocabulario del dominio (docs/API.md §Vocabulario).
 * Las CLAVES deben coincidir EXACTAMENTE con lo que espera el backend;
 * los valores son solo etiquetas legibles para el cuidador.
 */

export const BLOQUES = [
  "atencion_memoria",
  "lenguaje",
  "razonamiento",
  "gnosias",
  "praxias",
  "percepcion",
  "funcion_ejecutiva",
  "vida_cotidiana",
] as const;

export type Bloque = (typeof BLOQUES)[number];

export const BLOQUE_LABEL: Record<string, string> = {
  atencion_memoria: "Atención y memoria",
  lenguaje: "Lenguaje",
  razonamiento: "Razonamiento",
  gnosias: "Gnosias",
  praxias: "Praxias",
  percepcion: "Percepción",
  funcion_ejecutiva: "Función ejecutiva",
  vida_cotidiana: "Vida cotidiana",
};

export const PLANTILLAS = [
  "trazo",
  "seleccion_multiple",
  "memoria_visual",
  "secuencia_ordenar",
  "conteo_comparacion",
  "arrastrar_posicion",
  "evocacion_libre",
  "manejo_cantidad",
] as const;

export type Plantilla = (typeof PLANTILLAS)[number];

export const PLANTILLA_LABEL: Record<string, string> = {
  trazo: "Trazo",
  seleccion_multiple: "Selección múltiple",
  memoria_visual: "Memoria visual",
  secuencia_ordenar: "Secuencia / ordenar",
  conteo_comparacion: "Conteo / comparación",
  arrastrar_posicion: "Arrastrar a posición",
  evocacion_libre: "Evocación libre",
  manejo_cantidad: "Manejo de cantidad",
};

export const ESTADO_LABEL: Record<string, string> = {
  solo: "Solo",
  con_ayuda: "Con ayuda",
  no_completado: "No completado",
};

export function labelBloque(b: string | null | undefined): string {
  if (!b) return "Todos los bloques";
  return BLOQUE_LABEL[b] ?? b;
}

export function labelPlantilla(p: string | null | undefined): string {
  if (!p) return "";
  return PLANTILLA_LABEL[p] ?? p;
}

export function labelEstado(e: string | null | undefined): string {
  if (!e) return "—";
  return ESTADO_LABEL[e] ?? e;
}
