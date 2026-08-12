/**
 * Funciones de acceso a la API, una por endpoint del contrato.
 * Cada función es fina: construye la ruta y delega en el cliente HTTP.
 */
import { buildQuery, http } from "./client";
import type {
  Alerta,
  Cola,
  Dispositivo,
  DispositivoCreado,
  DispositivoIn,
  Ejercicio,
  EjercicioIn,
  Evolucion,
  Live,
  PlanLinea,
  ResumenSesion,
  SesionListItem,
  EstadoSesion,
  SugerenciaNivel,
  Staff,
  TokenOut,
  UsuarioFinal,
} from "./types";

// ---- Auth ----
export function login(email: string, password: string): Promise<TokenOut> {
  // OAuth2PasswordRequestForm: username = email.
  return http.postForm<TokenOut>("/auth/login", { username: email, password });
}

// ---- Equipo (staff del centro) ----
export function listarStaff(signal?: AbortSignal): Promise<Staff[]> {
  return http.get<Staff[]>("/staff", signal);
}

export function crearStaff(body: {
  nombre: string;
  email: string;
  password: string;
  rol?: string;
}): Promise<Staff> {
  return http.post<Staff>("/staff", body);
}

export function actualizarStaff(
  id: string,
  body: { nombre?: string; activo?: boolean },
): Promise<Staff> {
  return http.patch<Staff>(`/staff/${encodeURIComponent(id)}`, body);
}

// ---- Usuarios finales ----
export function listarUsuarios(centroId: string, signal?: AbortSignal): Promise<UsuarioFinal[]> {
  return http.get<UsuarioFinal[]>(`/centros/${encodeURIComponent(centroId)}/usuarios`, signal);
}

export function crearUsuario(body: { alias_interno: string; nivel_base_json?: Record<string, unknown> }): Promise<UsuarioFinal> {
  return http.post<UsuarioFinal>("/usuarios", body);
}

export function editarUsuario(id: string, body: { alias_interno?: string; nivel_base_json?: Record<string, unknown> }): Promise<UsuarioFinal> {
  return http.patch<UsuarioFinal>(`/usuarios/${encodeURIComponent(id)}`, body);
}

export function darDeBajaUsuario(id: string): Promise<UsuarioFinal> {
  return http.post<UsuarioFinal>(`/usuarios/${encodeURIComponent(id)}/baja`);
}

// ---- Ejercicios ----
export function listarEjercicios(
  params: { bloque?: string; activo?: boolean } = {},
  signal?: AbortSignal,
): Promise<Ejercicio[]> {
  return http.get<Ejercicio[]>(`/ejercicios${buildQuery(params)}`, signal);
}

export function crearEjercicio(body: EjercicioIn): Promise<Ejercicio> {
  return http.post<Ejercicio>("/ejercicios", body);
}

// ---- Evolución ----
export function evolucionUsuario(
  usuarioId: string,
  params: { bloque?: string; desde?: string; hasta?: string } = {},
  signal?: AbortSignal,
): Promise<Evolucion> {
  return http.get<Evolucion>(
    `/usuarios/${encodeURIComponent(usuarioId)}/evolucion${buildQuery(params)}`,
    signal,
  );
}

export function alertasUsuario(usuarioId: string, signal?: AbortSignal): Promise<Alerta[]> {
  return http.get<Alerta[]>(`/usuarios/${encodeURIComponent(usuarioId)}/alertas`, signal);
}

// ---- Alertas (bandeja del centro) ----
export function listarAlertas(
  params: { centro_id?: string; revisada?: boolean } = {},
  signal?: AbortSignal,
): Promise<Alerta[]> {
  return http.get<Alerta[]>(`/alertas${buildQuery(params)}`, signal);
}

export function revisarAlerta(alertaId: string, resultado: string): Promise<Alerta> {
  return http.patch<Alerta>(`/alertas/${encodeURIComponent(alertaId)}/revisar`, { resultado });
}

// ---- Sesiones (listado, en vivo e historial) ----
export function listarSesiones(
  params: { centro_id?: string; estado?: EstadoSesion; limit?: number } = {},
  signal?: AbortSignal,
): Promise<SesionListItem[]> {
  return http.get<SesionListItem[]>(`/sesiones${buildQuery(params)}`, signal);
}

export function sesionLive(sesionId: string, signal?: AbortSignal): Promise<Live> {
  return http.get<Live>(`/sesiones/${encodeURIComponent(sesionId)}/live`, signal);
}

export function resumenSesion(sesionId: string, signal?: AbortSignal): Promise<ResumenSesion> {
  return http.get<ResumenSesion>(`/sesiones/${encodeURIComponent(sesionId)}/resumen`, signal);
}

// ---- Plan de trabajo por paciente ----
/**
 * GET del plan. El contrato dice "líneas ordenadas por orden"; aceptamos tanto
 * un array como `{ lineas: [...] }` y normalizamos a PlanLinea[].
 */
export async function obtenerPlan(usuarioId: string, signal?: AbortSignal): Promise<PlanLinea[]> {
  const data = await http.get<PlanLinea[] | { lineas: PlanLinea[] }>(
    `/usuarios/${encodeURIComponent(usuarioId)}/plan`,
    signal,
  );
  const lineas = Array.isArray(data) ? data : (data?.lineas ?? []);
  return [...lineas].sort((a, b) => a.orden - b.orden);
}

/** PUT reemplaza TODO el plan. */
export function guardarPlan(usuarioId: string, lineas: PlanLinea[]): Promise<unknown> {
  return http.put<unknown>(`/usuarios/${encodeURIComponent(usuarioId)}/plan`, { lineas });
}

/** Vista previa de la cola resuelta desde el plan. */
export function obtenerCola(
  usuarioId: string,
  params: { sesion_id?: string } = {},
  signal?: AbortSignal,
): Promise<Cola> {
  return http.get<Cola>(
    `/usuarios/${encodeURIComponent(usuarioId)}/cola${buildQuery(params)}`,
    signal,
  );
}

// ---- Sugerencias de nivel (auto-sugerencia) ----
/** Sugerencias que el sistema calcula para esta persona; el profesional decide. */
export function sugerenciasUsuario(
  usuarioId: string,
  signal?: AbortSignal,
): Promise<SugerenciaNivel[]> {
  return http.get<SugerenciaNivel[]>(
    `/usuarios/${encodeURIComponent(usuarioId)}/sugerencias`,
    signal,
  );
}

/** Aplica un cambio de nivel a una línea del plan (PATCH). */
export function aplicarNivelLinea(lineaId: string, nivel: string): Promise<PlanLinea> {
  return http.patch<PlanLinea>(
    `/planes/lineas/${encodeURIComponent(lineaId)}/nivel`,
    { nivel },
  );
}

// ---- Dispositivos (tablets emparejadas) ----
export function listarDispositivos(
  params: { centro_id?: string; activo?: boolean } = {},
  signal?: AbortSignal,
): Promise<Dispositivo[]> {
  return http.get<Dispositivo[]>(`/dispositivos${buildQuery(params)}`, signal);
}

export function emparejarDispositivo(body: DispositivoIn): Promise<DispositivoCreado> {
  return http.post<DispositivoCreado>("/dispositivos", body);
}

export function revocarDispositivo(dispositivoId: string): Promise<Dispositivo> {
  return http.patch<Dispositivo>(`/dispositivos/${encodeURIComponent(dispositivoId)}/revocar`);
}
