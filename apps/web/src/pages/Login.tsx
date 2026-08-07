/** Pantalla de acceso. Guarda el JWT + centro_id/rol vía AuthContext. */
import { useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { ApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { Button, Field, inputStyle } from "../components/ui";
import { Logo } from "../components/Logo";
import { colors, radius, shadow } from "../theme";

const DEMO_EMAIL = "admin@trazo.local";
const DEMO_PASS = "trazo1234";

export function LoginPage() {
  const { session, signIn } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Si ya hay sesión, no tiene sentido mostrar el login.
  if (session) {
    return <Navigate to="/" replace />;
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await signIn(email.trim(), password);
      navigate("/", { replace: true });
    } catch (err) {
      setError(
        err instanceof ApiError ? err.message : "No se pudo iniciar sesión. Inténtalo de nuevo.",
      );
    } finally {
      setLoading(false);
    }
  }

  function rellenarDemo() {
    setEmail(DEMO_EMAIL);
    setPassword(DEMO_PASS);
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 24,
        background: colors.ivory,
      }}
    >
      <div style={{ width: "100%", maxWidth: 420 }}>
        <div style={{ textAlign: "center", marginBottom: 24, display: "flex", flexDirection: "column", alignItems: "center" }}>
          <Logo size={48} textSize={40} />
          <p className="eyebrow" style={{ marginTop: 10 }}>Panel del centro</p>
        </div>

        <form
          onSubmit={onSubmit}
          style={{
            background: colors.white,
            border: `1px solid ${colors.sand}`,
            borderRadius: radius.lg,
            padding: "30px 28px",
            boxShadow: shadow.soft,
          }}
        >
          <h1 style={{ fontSize: 24, marginBottom: 4 }}>Acceso al panel</h1>
          <p style={{ color: colors.textMuted, fontSize: 14.5, marginBottom: 22 }}>
            Introduce las credenciales del centro para ver la evolución de las personas usuarias.
          </p>

          <Field label="Correo electrónico" htmlFor="email">
            <input
              id="email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              style={inputStyle}
              placeholder="nombre@centro.local"
            />
          </Field>

          <Field label="Contraseña" htmlFor="password">
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={inputStyle}
              placeholder="••••••••"
            />
          </Field>

          {error && (
            <div
              role="alert"
              style={{
                background: colors.alertBg,
                border: `1px solid ${colors.coral}`,
                color: colors.coralDark,
                borderRadius: radius.sm,
                padding: "10px 12px",
                fontSize: 14,
                marginBottom: 16,
              }}
            >
              {error}
            </div>
          )}

          <Button type="submit" disabled={loading} style={{ width: "100%" }}>
            {loading ? "Entrando…" : "Entrar"}
          </Button>
        </form>

        {import.meta.env.DEV && (
          <div
            style={{
              marginTop: 16,
              background: colors.card,
              border: `1px dashed ${colors.sand}`,
              borderRadius: radius.md,
              padding: "14px 16px",
              fontSize: 13.5,
              color: colors.textMuted,
            }}
          >
            <strong style={{ color: colors.ink }}>Credenciales de demostración</strong>
            <div className="mono" style={{ marginTop: 6, lineHeight: 1.7 }}>
              {DEMO_EMAIL} / {DEMO_PASS}
            </div>
            <button
              type="button"
              onClick={rellenarDemo}
              style={{
                marginTop: 10,
                background: "transparent",
                border: `1.5px solid ${colors.sage}`,
                color: colors.sageDark,
                borderRadius: radius.sm,
                padding: "7px 14px",
                fontWeight: 600,
                fontSize: 13.5,
              }}
            >
              Usar credenciales demo
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
