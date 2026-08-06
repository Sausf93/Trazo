/**
 * Tipos que reflejan el contrato de la API (docs/API.md + schemas Pydantic).
 * No inventamos campos: si el backend no lo devuelve, no está aquí.
 */

export interface TokenOut {
  access_token: string;
  token_type: string;
  rol: string;
  nombre: string;
  centro_id: string;
}

export interface UsuarioFinal {
  id: string;
  centro_id: string;
  alias_interno: string;
  fecha_alta: string;
  nivel_base_json: Record<string, unknown>;
  activo: boolean;
}

export interface UsuarioFinalIn {
  alias_interno: string;
  nombre_real?: string | null;
  nivel_base_json?: Record<string, unknown>;
}

export interface Ejercicio {
  id: string;
  bloque: string;
  plantilla_tipo: string;
  nombre: string;
  descripcion: string | null;
  parametros_json: Record<string, unknown>;
  activo: boolean;
}

export interface EjercicioIn {
  bloque: string;
  plantilla_tipo: string;
  nombre: string;
  descripcion?: string | null;
  parametros_json?: Record<string, unknown>;
  activo?: boolean;
}

export interface PuntoEvolucion {
  fecha: string;
  ejercicio_id: string;
  bloque: string;
  estado: EstadoIntento;
  precision: number | null;
  valores: Record<string, unknown>;
}

export interface ResumenEvolucion {
  n_intentos: number;
  rendimiento_medio: number | null;
  tasa_ayuda: number | null;
}

export interface Evolucion {
  usuario_final_id: string;
  bloque: string | null;
  puntos: PuntoEvolucion[];
  resumen: ResumenEvolucion;
}

export interface Alerta {
  id: string;
  usuario_final_id: string;
  fecha_generada: string;
  tipo: string;
  bloque_afectado: string | null;
  descripcion: string;
  contexto_json: ContextoAlerta;
  revisada_por: string | null;
  fecha_revision: string | null;
  resultado: string | null;
}

/** Forma del contexto_json que produce el servicio de anomalías. */
export interface ContextoAlerta {
  baseline_media?: number;
  baseline_std?: number;
  reciente_media?: number;
  umbral_inferior?: number;
  n_baseline?: number;
  n_reciente?: number;
  caida?: number;
  [key: string]: unknown;
}

export interface FichaViva {
  usuario_final_id: string;
  alias_interno: string;
  ejercicio_actual: string | null;
  ultimo_estado: EstadoIntento | null;
  segundos_desde_ultimo_intento: number | null;
  atascado: boolean;
}

export interface Live {
  sesion_id: string;
  tipo: string;
  fichas: FichaViva[];
}

export type EstadoIntento = "solo" | "con_ayuda" | "no_completado";
