/**
 * Tipos que reflejan el contrato de la API (docs/API.md + schemas Pydantic).
 * No inventamos campos: si el backend no lo devuelve, no está aquí.
 */

export interface TokenOut {
  access_token: string;
  token_type: string;
  id: string;
  rol: string;
  nombre: string;
  centro_id: string;
  centro_nombre?: string | null;
}

export interface UsuarioFinal {
  id: string;
  centro_id: string;
  alias_interno: string;
  fecha_alta: string;
  nivel_base_json: Record<string, unknown>;
  activo: boolean;
}

/** Cuenta de equipo del centro (integradora o admin del centro). */
export interface Staff {
  id: string;
  centro_id: string;
  nombre: string;
  email: string;
  rol: string;
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
  n_sin_valorar: number;
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
  ultimo_con_ayuda: boolean;
  ultimo_intento_id: string | null;
  segundos_desde_ultimo_intento: number | null;
  atascado: boolean;
  terminado: boolean;
  ronda: number;
  pos_actual: number;
  total_actual: number;
}

export interface Live {
  sesion_id: string;
  tipo: string;
  fichas: FichaViva[];
}

export interface ResumenArea {
  bloque: string;
  n_personas: number;
  desempeno_medio: number;
  n_por_debajo: number;
}

export interface Consentimiento {
  id: string;
  usuario_final_id: string;
  tipo: string;
  fecha: string;
  otorgado_por: string;
  rol_otorgante: string;
  documento_ref: string | null;
}

export interface PersonaInactiva {
  usuario_final_id: string;
  alias_interno: string;
  dias_sin_actividad: number | null; // null = nunca ha participado
}

export interface ResumenUso {
  personas_totales: number;
  personas_activas_30d: number;
  sesiones_7d: number;
  sesiones_30d: number;
  inactivas: PersonaInactiva[];
}

export interface Objetivo {
  id: string;
  usuario_final_id: string;
  bloque: string;
  descripcion: string | null;
  objetivo_desempeno: number;
  activo: boolean;
  creado_en: string;
  situacion_actual: number | null;
  cumple: boolean | null;
  n_valorados: number;
}

export interface ObjetivoIn {
  bloque: string;
  descripcion?: string | null;
  objetivo_desempeno: number;
}

export interface PendienteRevision {
  id: string;
  usuario_final_id: string;
  alias_interno: string;
  ejercicio_id: string;
  ejercicio: string;
  bloque: string;
  plantilla_tipo: string;
  cuando: string;
  valores_json: Record<string, unknown>;
  cantidad_objetivo_json: Record<string, unknown>;
}

export type EstadoIntento = "logrado" | "parcial" | "no_logrado" | "sin_valorar";

// ---- Sesiones (listado e historial) ----
export type EstadoSesion = "abierta" | "cerrada" | "programada";

/** Elemento del listado GET /sesiones. */
export interface SesionListItem {
  id: string;
  nombre: string;
  fecha: string;
  modo: string;
  abierta: boolean;
  iniciada: boolean;
  cerrada: boolean;
  n_participantes: number;
}

/** Ficha por participante dentro del resumen de una sesión cerrada. */
export interface FichaResumen {
  usuario_final_id: string;
  alias_interno: string;
  n_intentos: number;
  logrado: number;
  parcial: number;
  no_logrado: number;
  sin_valorar: number;
  con_ayuda: number;
}

/** Resumen GET /sesiones/{id}/resumen. */
export interface ResumenSesion {
  sesion_id: string;
  nombre: string;
  notas: string | null;
  fichas: FichaResumen[];
}

// ---- Plan de trabajo (PlanLinea) ----
export type TipoLinea = "dominio" | "ejercicio";

export interface PlanLinea {
  /** Presente en las líneas que devuelve el GET; no se envía al crear. */
  id?: string;
  tipo: TipoLinea;
  /** Requerido si tipo=dominio (uno de los bloques). */
  bloque?: string | null;
  /** Requerido si tipo=ejercicio. */
  ejercicio_id?: string | null;
  /** "bajo"/"medio"/"alto" o un entero como cadena. */
  nivel: string;
  n_por_sesion: number;
  orden: number;
  activo: boolean;
}

/** Cuerpo del PUT: reemplaza TODO el plan. */
export interface PlanIn {
  lineas: PlanLinea[];
}

// ---- Cola resuelta (/usuarios/{id}/cola) ----
export interface ColaItem {
  ejercicio_id: string;
  nombre: string;
  bloque: string;
  plantilla: string;
  nivel: string;
  origen: string;
  plan_linea_id: string | null;
}

export interface Cola {
  usuario_final_id: string;
  sesion_id: string | null;
  modo: string;
  items: ColaItem[];
}

// ---- Sugerencias de nivel (auto-sugerencia del sistema) ----
export type SentidoSugerencia = "subir" | "bajar";

/**
 * Sugerencia de cambio de nivel que calcula el backend. NO se aplica sola:
 * el profesional decide y la aplica con el PATCH de nivel.
 */
export interface SugerenciaNivel {
  plan_linea_id: string;
  bloque: string;
  nivel_actual: string;
  sugerencia: SentidoSugerencia;
  nivel_propuesto: string;
  motivo: string;
  media_reciente: number | null;
  n_intentos: number;
}

// ---- Dispositivos (tablets emparejadas) ----
export type RolDispositivo = "maestra" | "participante";

export interface Dispositivo {
  id: string;
  centro_id: string;
  nombre: string;
  rol: string;
  activo: boolean;
  fecha_alta?: string | null;
  emparejado_en?: string | null;
  visto_en?: string | null; // última vez que la tablet se conectó
}

export interface DispositivoIn {
  nombre: string;
  rol: RolDispositivo;
  centro_id?: string;
}

/** Respuesta del POST: incluye el token de emparejamiento (solo se ve una vez). */
export interface DispositivoCreado extends Dispositivo {
  token: string;
}
