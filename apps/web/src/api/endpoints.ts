/**
 * Funciones de acceso a la API, una por endpoint del contrato.
 * Cada función es fina: construye la ruta y delega en el cliente HTTP.
 */
import { buildQuery, http } from "./client";
import type {
  Alerta,
  Ejercicio,
  EjercicioIn,
  Evolucion,
  Live,
  TokenOut,
  UsuarioFinal,
} from "./types";

// ---- Auth ----
export function login(email: string, password: string): Promise<TokenOut> {
  // OAuth2PasswordRequestForm: username = email.
  return http.postForm<TokenOut>("/auth/login", { username: email, password });
}

// ---- Usuarios finales ----
export function listarUsuarios(centroId: string, signal?: AbortSignal): Promise<UsuarioFinal[]> {
  return http.get<UsuarioFinal[]>(`/centros/${encodeURIComponent(centroId)}/usuarios`, signal);
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

// ---- Sesión en vivo ----
export function sesionLive(sesionId: string, signal?: AbortSignal): Promise<Live> {
  return http.get<Live>(`/sesiones/${encodeURIComponent(sesionId)}/live`, signal);
}
