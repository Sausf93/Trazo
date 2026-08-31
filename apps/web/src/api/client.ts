/**
 * Cliente HTTP centralizado para la API de Trazo.
 * - La URL base sale de VITE_API_URL (por defecto http://localhost:8000).
 * - Adjunta el JWT Bearer si hay sesión.
 * - Ante un 401 limpia la sesión (token caducado / inválido).
 */
import { clearSession, getToken } from "../auth/session";

export const API_URL: string =
  import.meta.env.VITE_API_URL?.replace(/\/$/, "") || "http://localhost:8000";

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

interface RequestOptions {
  method?: string;
  /** Cuerpo JSON. Se serializa y se manda con Content-Type: application/json. */
  json?: unknown;
  /** Cuerpo form-urlencoded (login). */
  form?: Record<string, string>;
  signal?: AbortSignal;
}

async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = {};
  const token = getToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;

  let body: BodyInit | undefined;
  if (opts.form) {
    headers["Content-Type"] = "application/x-www-form-urlencoded";
    body = new URLSearchParams(opts.form).toString();
  } else if (opts.json !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(opts.json);
  }

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method: opts.method ?? "GET",
      headers,
      body,
      signal: opts.signal,
    });
  } catch (err) {
    if ((err as Error)?.name === "AbortError") throw err;
    throw new ApiError(
      0,
      "No se pudo conectar con el servidor. ¿Está encendido el backend?",
    );
  }

  // Un 401 en el propio login NO es sesión caducada: es email/contraseña mal.
  // Solo expulsamos al /login cuando el 401 llega en cualquier OTRA llamada.
  if (res.status === 401 && !path.startsWith("/auth/login")) {
    clearSession();
    // Fuerza la vuelta al login sin depender de React Router aquí.
    if (typeof window !== "undefined" && window.location.pathname !== "/login") {
      window.location.assign("/login");
    }
    throw new ApiError(401, "Sesión caducada. Vuelve a iniciar sesión.");
  }

  if (!res.ok) {
    let detail = `Error ${res.status}`;
    try {
      const data = await res.json();
      if (data?.detail) {
        // Nunca mostrar JSON crudo al usuario. Si el detail es un texto, se usa;
        // si es la lista de errores de validación de FastAPI (422), un mensaje
        // humano; cualquier otra forma, un genérico.
        if (typeof data.detail === "string") {
          detail = data.detail;
        } else if (Array.isArray(data.detail)) {
          detail = "Revisa los datos: hay campos incompletos o con formato incorrecto.";
        } else {
          detail = "No se pudo completar la operación. Revisa los datos e inténtalo de nuevo.";
        }
      }
    } catch {
      /* respuesta sin cuerpo JSON */
    }
    throw new ApiError(res.status, detail);
  }

  if (res.status === 204) return undefined as T;
  const text = await res.text();
  if (!text) return undefined as T;
  try {
    return JSON.parse(text) as T;
  } catch {
    // Un 2xx con cuerpo no-JSON (un proxy/portal cautivo/WiFi inestable puede
    // devolver HTML) rompería con un SyntaxError que la app no reconoce como
    // ApiError. Lo normalizamos a un error legible.
    throw new ApiError(res.status, "Respuesta inesperada del servidor. Inténtalo de nuevo.");
  }
}

export function buildQuery(params: Record<string, string | number | boolean | undefined | null>): string {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== "") q.set(k, String(v));
  }
  const s = q.toString();
  return s ? `?${s}` : "";
}

export const http = {
  get: <T>(path: string, signal?: AbortSignal) => request<T>(path, { signal }),
  post: <T>(path: string, json?: unknown) => request<T>(path, { method: "POST", json }),
  put: <T>(path: string, json?: unknown) => request<T>(path, { method: "PUT", json }),
  patch: <T>(path: string, json?: unknown) => request<T>(path, { method: "PATCH", json }),
  del: <T>(path: string) => request<T>(path, { method: "DELETE" }),
  postForm: <T>(path: string, form: Record<string, string>) =>
    request<T>(path, { method: "POST", form }),
};
