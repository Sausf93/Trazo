/**
 * Persistencia de la sesión en localStorage.
 * Guardamos el JWT y los datos no sensibles que devuelve el login
 * (centro_id, rol, nombre) para no tener que decodificar el token.
 */
import type { TokenOut } from "../api/types";

const KEY = "trazo.session";

export interface Session {
  token: string;
  id: string;
  rol: string;
  nombre: string;
  centro_id: string;
  centro_nombre?: string | null;
}

export function saveSession(t: TokenOut): Session {
  const s: Session = {
    token: t.access_token,
    id: t.id,
    rol: t.rol,
    nombre: t.nombre,
    centro_id: t.centro_id,
    centro_nombre: t.centro_nombre ?? null,
  };
  localStorage.setItem(KEY, JSON.stringify(s));
  return s;
}

export function getSession(): Session | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as Session;
    if (!s?.token) return null;
    return s;
  } catch {
    return null;
  }
}

export function getToken(): string | null {
  return getSession()?.token ?? null;
}

export function clearSession(): void {
  localStorage.removeItem(KEY);
}
