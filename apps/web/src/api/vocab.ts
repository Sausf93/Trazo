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
  "busqueda_visual",
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
  busqueda_visual: "Búsqueda visual",
  manejo_cantidad: "Manejo de cantidad",
};

export const NIVELES = ["bajo", "medio", "alto"] as const;
export type Nivel = (typeof NIVELES)[number];

export const NIVEL_LABEL: Record<string, string> = {
  bajo: "Bajo",
  medio: "Medio",
  alto: "Alto",
};

export function labelNivel(n: string | null | undefined): string {
  if (!n) return "—";
  return NIVEL_LABEL[n] ?? n;
}

export const ROLES_DISPOSITIVO = ["maestra", "participante"] as const;

export const ROL_DISPOSITIVO_LABEL: Record<string, string> = {
  maestra: "Maestra",
  participante: "Participante",
};

export function labelRolDispositivo(r: string | null | undefined): string {
  if (!r) return "—";
  return ROL_DISPOSITIVO_LABEL[r] ?? r;
}

export const TIPO_LINEA_LABEL: Record<string, string> = {
  dominio: "Dominio",
  ejercicio: "Ejercicio concreto",
};

export const ESTADO_LABEL: Record<string, string> = {
  logrado: "Lo logró",
  parcial: "A medias",
  no_logrado: "No lo logró",
  sin_valorar: "Sin valorar",
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
