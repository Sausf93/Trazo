/** Marco de la aplicación: barra lateral de navegación + área de contenido. */
import type { ReactNode } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { Logo } from "./Logo";
import { colors, radius } from "../theme";

const NAV = [
  { to: "/", label: "Panel", end: true },
  { to: "/alertas", label: "Alertas" },
  { to: "/ejercicios", label: "Ejercicios" },
  { to: "/sesion", label: "Sesión en vivo" },
  { to: "/dispositivos", label: "Dispositivos" },
];

export function Layout({ children }: { children: ReactNode }) {
  const { session, signOut } = useAuth();
  const navigate = useNavigate();

  return (
    <div style={{ display: "flex", minHeight: "100vh", background: colors.ivory }}>
      <aside
        style={{
          width: 232,
          flexShrink: 0,
          background: colors.white,
          borderRight: `1px solid ${colors.sand}`,
          padding: "26px 18px",
          display: "flex",
          flexDirection: "column",
          gap: 8,
          position: "sticky",
          top: 0,
          height: "100vh",
        }}
      >
        <div style={{ padding: "0 8px 20px" }}>
          <Logo size={30} textSize={26} />
          <div className="eyebrow" style={{ marginTop: 6 }}>Panel del centro</div>
        </div>

        <nav style={{ display: "flex", flexDirection: "column", gap: 4 }} aria-label="Navegación principal">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              style={({ isActive }) => ({
                display: "block",
                padding: "10px 14px",
                borderRadius: radius.sm,
                fontWeight: 600,
                fontSize: 15.5,
                textDecoration: "none",
                color: isActive ? colors.white : colors.ink,
                background: isActive ? colors.sage : "transparent",
              })}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div style={{ marginTop: "auto", paddingTop: 18, borderTop: `1px solid ${colors.sand}` }}>
          <div style={{ fontSize: 14, fontWeight: 600 }}>{session?.nombre}</div>
          <div style={{ fontSize: 12.5, color: colors.textFaint, marginBottom: 12 }}>
            {session?.rol === "admin_centro" ? "Administración del centro" : "Integradora"}
          </div>
          <button
            onClick={() => {
              signOut();
              navigate("/login");
            }}
            style={{
              width: "100%",
              padding: "9px 12px",
              borderRadius: radius.sm,
              border: `1.5px solid ${colors.sand}`,
              background: "transparent",
              color: colors.textMuted,
              fontWeight: 600,
              fontSize: 14,
            }}
          >
            Cerrar sesión
          </button>
        </div>
      </aside>

      <main style={{ flex: 1, minWidth: 0, padding: "34px clamp(20px, 4vw, 48px) 64px" }}>
        <div style={{ maxWidth: 1080, margin: "0 auto" }}>{children}</div>
      </main>
    </div>
  );
}
