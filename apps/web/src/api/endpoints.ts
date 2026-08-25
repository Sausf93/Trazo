/**
 * Funciones de acceso a la API, una por endpoint del contrato.
 * Cada función es fina: construye la ruta y delega en el cliente HTTP.
 */
import { API_URL, buildQuery, http } from "./client";
import { getToken } from "../auth/session";
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
  Objetivo,
  ObjetivoIn,
  Consentimiento,
  PendienteRevision,
  ResumenArea,
  ResumenUso,
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

/** El admin restablece la contraseña de un miembro de su equipo. */
export function restablecerPasswordStaff(id: string, password: string): Promise<void> {
  return http.post<void>(`/staff/${encodeURIComponent(id)}/password`, { password });
}

// ---- Usuarios finales ----
export function listarUsuarios(centroId: string, signal?: AbortSignal): Promise<UsuarioFinal[]> {
  return http.get<UsuarioFinal[]>(`/centros/${encodeURIComponent(centroId)}/usuarios`, signal);
}

export function crearUsuario(body: { alias_interno: string; nivel_base_json?: Record<string, unknown> }): Promise<UsuarioFinal> {
  return http.post<UsuarioFinal>("/usuarios", body);
}

export function editarUsuario(id: string, body: { alias_interno?: string; nivel_base_json?: Record<string, unknown>; nombre_real?: string }): Promise<UsuarioFinal> {
  return http.patch<UsuarioFinal>(`/usuarios/${encodeURIComponent(id)}`, body);
}

// ---- Consentimiento RGPD ----
export function listarConsentimientos(usuarioId: string, signal?: AbortSignal): Promise<Consentimiento[]> {
  return http.get<Consentimiento[]>(`/usuarios/${encodeURIComponent(usuarioId)}/consentimiento`, signal);
}

export function registrarConsentimiento(usuarioId: string, body: {
  tipo: string; otorgado_por: string; rol_otorgante: string; documento_ref?: string | null;
}): Promise<Consentimiento> {
  return http.post<Consentimiento>(`/usuarios/${encodeURIComponent(usuarioId)}/consentimiento`, body);
}

export function darDeBajaUsuario(id: string): Promise<UsuarioFinal> {
  return http.post<UsuarioFinal>(`/usuarios/${encodeURIComponent(id)}/baja`);
}

/** RGPD art. 17: anonimiza a la persona (borra datos identificativos). Solo admin. */
export function suprimirUsuario(id: string): Promise<unknown> {
  return http.del<unknown>(`/usuarios/${encodeURIComponent(id)}`);
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

/** Cierra la sala en vivo desde el panel (además de poder cerrarla en la tablet). */
export function cerrarSesion(sesionId: string): Promise<SesionListItem> {
  return http.patch<SesionListItem>(`/sesiones/${encodeURIComponent(sesionId)}/cerrar`);
}

/** Marca/desmarca que la integradora AYUDÓ en la última actividad (desde el monitor). */
export function marcarAyuda(intentoId: string, con_ayuda: boolean): Promise<unknown> {
  return http.patch<unknown>(`/intentos/${encodeURIComponent(intentoId)}/ayuda`, { con_ayuda });
}

// ---- Cola de revisión (intentos sin_valorar) ----
/** Intentos que la app no supo juzgar, pendientes de que la integradora decida. */
export function listarPendientes(
  params: { usuario_final_id?: string; limit?: number } = {},
  signal?: AbortSignal,
): Promise<PendienteRevision[]> {
  return http.get<PendienteRevision[]>(`/pendientes${buildQuery(params)}`, signal);
}

/** La integradora fija el resultado de un intento sin_valorar. */
export function marcarResultado(
  intentoId: string,
  resultado: "logrado" | "parcial" | "no_logrado" | "sin_valorar",
): Promise<unknown> {
  return http.patch<unknown>(`/intentos/${encodeURIComponent(intentoId)}/resultado`, { resultado });
}

/**
 * Descarga los intentos del centro (o de una persona) como CSV. Hace un fetch
 * autenticado y dispara la descarga en el navegador (el CSV no pasa por el
 * cliente HTTP JSON). Devuelve el nº de filas no está disponible; resuelve al
 * iniciarse la descarga.
 */
export async function descargarIntentosCsv(params: { centro_id: string; usuario_final_id?: string; incluir_nombre?: boolean }): Promise<void> {
  const res = await fetch(`${API_URL}/export/intentos.csv${buildQuery(params)}`, {
    headers: { Authorization: `Bearer ${getToken() ?? ""}` },
  });
  if (!res.ok) throw new Error("No se pudo exportar el CSV.");
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = params.usuario_final_id ? "trazo-persona.csv" : "trazo-centro.csv";
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

// ---- Panorámica del centro por área ----
export function resumenAreas(centroId: string, signal?: AbortSignal): Promise<ResumenArea[]> {
  return http.get<ResumenArea[]>(`/centros/${encodeURIComponent(centroId)}/resumen-areas`, signal);
}

// ---- Uso/adherencia del centro (para dirección) ----
export function resumenUso(centroId: string, signal?: AbortSignal): Promise<ResumenUso> {
  return http.get<ResumenUso>(`/centros/${encodeURIComponent(centroId)}/uso`, signal);
}

// ---- Objetivos/metas por paciente ----
export function listarObjetivos(usuarioId: string, signal?: AbortSignal): Promise<Objetivo[]> {
  return http.get<Objetivo[]>(`/usuarios/${encodeURIComponent(usuarioId)}/objetivos`, signal);
}
export function crearObjetivo(usuarioId: string, body: ObjetivoIn): Promise<Objetivo> {
  return http.post<Objetivo>(`/usuarios/${encodeURIComponent(usuarioId)}/objetivos`, body);
}
export function editarObjetivo(
  objetivoId: string,
  body: { descripcion?: string | null; objetivo_desempeno?: number; activo?: boolean },
): Promise<Objetivo> {
  return http.patch<Objetivo>(`/objetivos/${encodeURIComponent(objetivoId)}`, body);
}
export function borrarObjetivo(objetivoId: string): Promise<unknown> {
  return http.del<unknown>(`/objetivos/${encodeURIComponent(objetivoId)}`);
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
