/** Marco de la aplicación: barra lateral de navegación + área de contenido.
 * Responsive: en móvil la barra lateral se convierte en una cabecera con la
 * navegación en una fila horizontal deslizable, y el contenido ocupa todo el
 * ancho (antes el panel "se veía fatal" en móvil: la barra fija de 232px
 * aplastaba el contenido). */
import { useEffect, useState, type ReactNode } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { listarPendientes } from "../api/endpoints";
import { Logo } from "./Logo";
import { colors, radius } from "../theme";

// Menú del día a día de la integradora. "Ejercicios" (catálogo, avanzado) y
// "Dispositivos" (emparejar tablets) se dejan fuera para no recargar; las rutas
// siguen existiendo por si se necesitan.
const NAV = [
  { to: "/", label: "Panel", end: true },
  { to: "/pacientes", label: "Personas" },
  { to: "/dispositivos", label: "Tablets" },
  { to: "/revisar", label: "Por revisar" },
  { to: "/alertas", label: "Alertas" },
  { to: "/sesion", label: "En directo" },
  { to: "/sesiones", label: "Historial de sesiones" },
];

// "Equipo" (alta de maestras) solo lo ve el admin del centro.
const NAV_ADMIN = [
  { to: "/equipo", label: "Equipo", end: false },
  { to: "/cumplimiento", label: "Cumplimiento", end: false },
];

/** True cuando la ventana es estrecha (móvil/tablet vertical). */
function useEsMovil(bp = 820) {
  const [movil, setMovil] = useState(
    typeof window !== "undefined" ? window.innerWidth <= bp : false,
  );
  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${bp}px)`);
    const on = () => setMovil(mq.matches);
    on();
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, [bp]);
  return movil;
}

export function Layout({ children }: { children: ReactNode }) {
  const { session, signOut } = useAuth();
  const navigate = useNavigate();
  const movil = useEsMovil();

  // Contador de "por revisar" en el menú: la integradora ve si hay cola sin
  // entrar (esos intentos no cuentan hasta valorarlos, no deben acumularse).
  const [porRevisar, setPorRevisar] = useState<number | null>(null);
  useEffect(() => {
    let vivo = true;
    const refrescar = () =>
      listarPendientes({ limit: 200 })
        .then((p) => vivo && setPorRevisar(p.length))
        .catch(() => {});
    refrescar();
    window.addEventListener("trazo:pendientes-cambiaron", refrescar);
    return () => {
      vivo = false;
      window.removeEventListener("trazo:pendientes-cambiaron", refrescar);
    };
  }, []);

  const items = session?.rol === "admin_centro" ? [...NAV, ...NAV_ADMIN] : NAV;

  const badge = (to: string) =>
    to === "/revisar" && porRevisar != null && porRevisar > 0 ? (
      <span
        className="mono"
        aria-label={`${porRevisar} por revisar`}
        style={{
          fontSize: 11.5,
          fontWeight: 700,
          minWidth: 20,
          textAlign: "center",
          padding: "1px 6px",
          borderRadius: 999,
          background: colors.coral,
          color: colors.white,
        }}
      >
        {porRevisar}
      </span>
    ) : null;

  const cerrar = (
    <button
      onClick={() => {
        signOut();
        navigate("/login");
      }}
      style={{
        padding: "9px 12px",
        borderRadius: radius.sm,
        border: `1.5px solid ${colors.sand}`,
        background: "transparent",
        color: colors.textMuted,
        fontWeight: 600,
        fontSize: 14,
        whiteSpace: "nowrap",
      }}
    >
      Cerrar sesión
    </button>
  );

  // -------------------- MÓVIL: cabecera + nav horizontal --------------------
  if (movil) {
    return (
      <div style={{ minHeight: "100vh", background: colors.ivory }}>
        <header
          style={{
            position: "sticky",
            top: 0,
            zIndex: 10,
            background: colors.white,
            borderBottom: `1px solid ${colors.sand}`,
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              gap: 10,
              padding: "12px 16px",
            }}
          >
            <Logo size={26} textSize={22} />
            <div style={{ display: "flex", alignItems: "center", gap: 10, minWidth: 0 }}>
              <div style={{ textAlign: "right", minWidth: 0 }}>
                <div
                  style={{
                    fontSize: 13,
                    fontWeight: 600,
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                    maxWidth: 120,
                  }}
                >
                  {session?.nombre}
                </div>
              </div>
              {cerrar}
            </div>
          </div>
          <nav
            aria-label="Navegación principal"
            style={{
              display: "flex",
              gap: 8,
              overflowX: "auto",
              WebkitOverflowScrolling: "touch",
              padding: "0 12px 10px",
              scrollbarWidth: "none",
            }}
          >
            {items.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                style={({ isActive }) => ({
                  display: "flex",
                  alignItems: "center",
                  gap: 6,
                  padding: "9px 14px",
                  borderRadius: 999,
                  fontWeight: 600,
                  fontSize: 14.5,
                  whiteSpace: "nowrap",
                  textDecoration: "none",
                  color: isActive ? colors.white : colors.ink,
                  background: isActive ? colors.sageDark : colors.card,
                })}
              >
                <span>{item.label}</span>
                {badge(item.to)}
              </NavLink>
            ))}
          </nav>
        </header>

        <main style={{ padding: "20px clamp(14px, 4vw, 22px) 56px" }}>
          <div style={{ maxWidth: 1080, margin: "0 auto" }}>{children}</div>
        </main>
      </div>
    );
  }

  // -------------------- ESCRITORIO: barra lateral --------------------
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
          {items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              style={({ isActive }) => ({
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 8,
                padding: "10px 14px",
                borderRadius: radius.sm,
                fontWeight: 600,
                fontSize: 15.5,
                textDecoration: "none",
                color: isActive ? colors.white : colors.ink,
                background: isActive ? colors.sageDark : "transparent",
              })}
            >
              <span>{item.label}</span>
              {badge(item.to)}
            </NavLink>
          ))}
        </nav>

        <div style={{ marginTop: "auto", paddingTop: 18, borderTop: `1px solid ${colors.sand}` }}>
          <div style={{ fontSize: 14, fontWeight: 600 }}>{session?.nombre}</div>
          <div style={{ fontSize: 12.5, color: colors.textFaint, marginBottom: 12 }}>
            {session?.rol === "admin_centro" ? "Administración del centro" : "Integradora"}
          </div>
          {cerrar}
        </div>
      </aside>

      <main style={{ flex: 1, minWidth: 0, padding: "34px clamp(20px, 4vw, 48px) 64px" }}>
        <div style={{ maxWidth: 1080, margin: "0 auto" }}>{children}</div>
      </main>
    </div>
  );
}
