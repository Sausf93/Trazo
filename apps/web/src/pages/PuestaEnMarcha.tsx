/**
 * Asistente de PUESTA EN MARCHA: guía a los trabajadores del centro, paso a paso,
 * para dejar el centro funcionando (equipo, tablets, DPA, personas + consentimiento,
 * suscripción, primera sesión). Lee el estado REAL y marca lo hecho / lo que falta,
 * con un enlace directo a donde se hace cada cosa. Así se puede montar sin Saulo.
 */
import { Link, Navigate } from "react-router-dom";
import { puestaEnMarcha, type PuestaEnMarcha } from "../api/endpoints";
import { useAuth } from "../auth/AuthContext";
import { Card, PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAsync } from "../hooks/useAsync";
import { colors } from "../theme";

function Paso({
  hecho,
  titulo,
  children,
}: {
  hecho: boolean;
  titulo: string;
  children?: React.ReactNode;
}) {
  return (
    <div style={{ display: "flex", gap: 14, padding: "16px 0", borderBottom: `1px solid ${colors.sand}` }}>
      <div
        aria-hidden
        style={{
          width: 30,
          height: 30,
          borderRadius: "50%",
          flex: "none",
          display: "grid",
          placeItems: "center",
          background: hecho ? colors.sageDark : colors.sand,
          color: hecho ? "#fff" : colors.textMuted,
          fontWeight: 700,
          fontSize: 16,
        }}
      >
        {hecho ? "✓" : "·"}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 600, color: colors.ink, fontSize: 16 }}>
          {titulo}{" "}
          <span
            style={{
              fontSize: 12.5,
              fontWeight: 600,
              color: hecho ? colors.sageDark : colors.coralDark,
            }}
          >
            · {hecho ? "hecho" : "pendiente"}
          </span>
        </div>
        {children && (
          <div style={{ fontSize: 13.5, color: colors.textMuted, marginTop: 3 }}>{children}</div>
        )}
      </div>
    </div>
  );
}

export function PuestaEnMarchaPage() {
  const { session } = useAuth();
  const esAdmin = session?.rol === "admin_centro";
  const estado = useAsync<PuestaEnMarcha>((s) => puestaEnMarcha(s), []);

  if (!esAdmin) return <Navigate to="/" replace />;

  const d = estado.data;

  return (
    <div>
      <PageHeader
        eyebrow="Panel del centro"
        title="Puesta en marcha"
        subtitle="Lo que falta para dejar el centro funcionando. Cada paso te lleva a donde se hace; se marca solo cuando está de verdad."
      />

      {estado.loading && <Spinner label="Comprobando el estado del centro…" />}
      {estado.error && <StateMessage tone="error">{estado.error}</StateMessage>}

      {d && (
        <>
          {d.completo && (
            <Card style={{ marginBottom: 20, background: "#E8F5F2", border: `1px solid ${colors.sageDark}` }}>
              <strong style={{ color: colors.sageDark }}>¡Todo listo! 🎉</strong> El centro está en marcha:
              equipo, tablets, documentos, personas y una primera sesión. A partir de aquí, el día a día.
            </Card>
          )}

          <Card>
            <h2 style={{ fontSize: 17, marginBottom: 4 }}>Pasos para arrancar</h2>
            <Paso hecho={d.equipo_ok} titulo="1. Da de alta al equipo">
              Al menos una profesional (maestra) para operar las sesiones.{" "}
              {d.n_maestras > 0 ? `Tienes ${d.n_maestras}.` : "Aún ninguna."}{" "}
              <Link to="/equipo" style={{ color: colors.sageDark }}>Ir a Equipo</Link>
            </Paso>

            <Paso hecho={d.tablets_ok} titulo="2. Empareja las tablets">
              {d.n_tablets > 0 ? `${d.n_tablets} emparejada(s).` : "Aún ninguna."}{" "}
              <Link to="/dispositivos" style={{ color: colors.sageDark }}>Ir a Tablets</Link>
              {" · "}
              <a
                href="https://trazo-web-af2.pages.dev/instalar.html"
                target="_blank"
                rel="noopener"
                style={{ color: colors.sageDark }}
              >
                Cómo instalar la app (QR)
              </a>
            </Paso>

            <Paso hecho={d.dpa_ok} titulo="3. Sube el contrato de encargo (DPA)">
              El acuerdo RGPD entre el centro y Trazo. Sin él no se abren sesiones reales.{" "}
              <Link to="/cumplimiento" style={{ color: colors.sageDark }}>Ir a Cumplimiento</Link>
            </Paso>

            <Paso hecho={d.personas_ok} titulo="4. Da de alta a las personas con su consentimiento">
              {d.n_personas === 0
                ? "Aún no hay personas dadas de alta."
                : d.personas_sin_consentimiento > 0
                ? `${d.n_personas} personas, pero faltan ${d.personas_sin_consentimiento} consentimiento(s).`
                : `${d.n_personas} personas, todas con consentimiento.`}{" "}
              <Link to="/pacientes" style={{ color: colors.sageDark }}>Ir a Personas</Link>
            </Paso>

            <Paso hecho={d.suscripcion_ok} titulo="5. Suscripción activa">
              Estado: <strong>{d.estado_suscripcion}</strong>.{" "}
              {d.suscripcion_ok
                ? "El acceso está garantizado."
                : "Actívala para seguir usando Trazo."}{" "}
              <Link to="/cumplimiento" style={{ color: colors.sageDark }}>Gestionar</Link>
            </Paso>

            <Paso hecho={d.primera_sesion_ok} titulo="6. Primera sesión">
              {d.primera_sesion_ok
                ? "Ya se ha abierto al menos una sesión. ¡El circuito funciona!"
                : "En una tablet: entra como Maestra, crea una sala con participantes y arranca. Aparecerá aquí y en «En directo»."}
            </Paso>
          </Card>
        </>
      )}
    </div>
  );
}
