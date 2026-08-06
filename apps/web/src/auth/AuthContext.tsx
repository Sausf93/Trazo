/**
 * Contexto de autenticación. Expone la sesión actual y acciones de login/logout.
 */
import { createContext, useCallback, useContext, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { login as apiLogin } from "../api/endpoints";
import { clearSession, getSession, saveSession } from "./session";
import type { Session } from "./session";

interface AuthContextValue {
  session: Session | null;
  isAdmin: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(() => getSession());

  const signIn = useCallback(async (email: string, password: string) => {
    const token = await apiLogin(email, password);
    setSession(saveSession(token));
  }, []);

  const signOut = useCallback(() => {
    clearSession();
    setSession(null);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      isAdmin: session?.rol === "admin_centro",
      signIn,
      signOut,
    }),
    [session, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth debe usarse dentro de <AuthProvider>");
  return ctx;
}
