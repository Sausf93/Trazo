/** Envuelve rutas privadas: si no hay sesión, redirige a /login. */
import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { Layout } from "./Layout";

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  if (!session) return <Navigate to="/login" replace />;
  return <Layout>{children}</Layout>;
}
