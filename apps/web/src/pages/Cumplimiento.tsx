/**
 * Página guiada de CUMPLIMIENTO (RGPD) para el admin del centro: una lista de
 * pasos a completar al implantar Trazo (para no olvidar nada) + subida de los
 * documentos del centro (DPA, RAT, DPIA) que quedan guardados en la app para las
 * auditorías. Los consentimientos por persona se gestionan en cada ficha.
 */
import { Link, Navigate } from "react-router-dom";
import { crearCheckoutSuscripcion, listarDocumentos, listarUsuarios } from "../api/endpoints";
import type { DocumentoLegal, UsuarioFinal } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { useState } from "react";
import { Button, Card, PageHeader, Spinner, StateMessage } from "../components/ui";
import { DocumentosLegales } from "../components/DocumentosLegales";
import { DpaImprimible } from "../components/DpaImprimible";
import { useAsync } from "../hooks/useAsync";
import { colors } from "../theme";

function Paso({ hecho, titulo, children }: { hecho: boolean; titulo: string; children?: React.ReactNode }) {
  return (
    <div style={{ display: "flex", gap: 12, padding: "12px 0", borderBottom: `1px solid ${colors.sand}` }}>
      <div aria-hidden style={{
        width: 26, height: 26, borderRadius: "50%", flex: "none", display: "grid", placeItems: "center",
        background: hecho ? colors.sageDark : colors.sand, color: hecho ? "#fff" : colors.textMuted,
        fontWeight: 700, fontSize: 15,
      }}>{hecho ? "✓" : "·"}</div>
      <div>
        <div style={{ fontWeight: 600, color: colors.ink }}>
          {titulo}{" "}
          <span style={{ fontSize: 12.5, fontWeight: 600, color: hecho ? colors.sageDark : colors.coralDark }}>
            · {hecho ? "hecho" : "pendiente"}
          </span>
        </div>
        {children && <div style={{ fontSize: 13.5, color: colors.textMuted, marginTop: 2 }}>{children}</div>}
      </div>
    </div>
  );
}

export function CumplimientoPage() {
  const { session } = useAuth();
  const esAdmin = session?.rol === "admin_centro";
  const centroId = session?.centro_id ?? "";
  const docs = useAsync<DocumentoLegal[]>((s) => listarDocumentos({ solo_centro: true }, s), []);
  const personas = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const [imprimirDpa, setImprimirDpa] = useState(false);
  const [pagando, setPagando] = useState(false);
  const [errorPago, setErrorPago] = useState<string | null>(null);

  async function activarSuscripcion() {
    setPagando(true);
    setErrorPago(null);
    try {
      const { url } = await crearCheckoutSuscripcion();
      window.location.href = url; // redirige a Stripe Checkout
    } catch (e) {
      setErrorPago(e instanceof Error ? e.message : "No se pudo iniciar el pago.");
      setPagando(false);
    }
  }

  if (!esAdmin) return <Navigate to="/" replace />;

  const tieneTipo = (t: string) => (docs.data ?? []).some((d) => d.tipo === t);
  const nPersonas = (personas.data ?? []).filter((p) => p.activo).length;

  return (
    <div>
      <PageHeader
        eyebrow="Panel del centro"
        title="Cumplimiento (RGPD)"
        subtitle="Pasos para dejar el centro en regla al implantar Trazo, y los documentos guardados en la app para cuando haya una auditoría."
      />

      <Card style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 17, marginBottom: 4 }}>Suscripción</h2>
        <p style={{ fontSize: 13.5, color: colors.textMuted, marginBottom: 12 }}>
          Trazo es de pago por centro (incluye hasta 30 personas; a partir de ahí, un pequeño extra
          por persona). Activa la suscripción para seguir usándolo cuando termine la prueba.
        </p>
        {errorPago && <StateMessage tone="error">{errorPago}</StateMessage>}
        <Button onClick={activarSuscripcion} disabled={pagando}>
          {pagando ? "Abriendo el pago…" : "Activar suscripción (pagar)"}
        </Button>
      </Card>

      <Card style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 17, marginBottom: 6 }}>Pasos a completar</h2>
        {(docs.loading || personas.loading) && <Spinner label="Comprobando…" />}
        {!docs.loading && (
          <div>
            <Paso hecho={tieneTipo("dpa")} titulo="1. Contrato de encargo del tratamiento (DPA) firmado con el centro">
              Súbelo abajo. Es el contrato Trazo ↔ centro; fírmalo <strong>antes</strong> de cargar datos reales.
            </Paso>
            <Paso hecho={tieneTipo("rat")} titulo="2. Registro de Actividades de Tratamiento (RAT)">
              El del centro (responsable). Súbelo abajo cuando lo tengáis.
            </Paso>
            <Paso hecho={tieneTipo("dpia")} titulo="3. Evaluación de Impacto (DPIA) revisada">
              Hay un borrador en la documentación; una vez revisado por vuestra asesoría, súbelo.
            </Paso>
            <Paso hecho={nPersonas > 0} titulo={`4. Consentimiento firmado de cada persona (${nPersonas} activas)`}>
              En la ficha de cada persona (<Link to="/pacientes" style={{ color: colors.sageDark }}>Personas</Link>):
              genera el PDF, hazlo firmar y súbelo. No des de alta a nadie sin su consentimiento documentado.
            </Paso>
          </div>
        )}
      </Card>

      <Card>
        <h2 style={{ fontSize: 17, marginBottom: 4 }}>Documentos del centro</h2>
        <p style={{ fontSize: 13.5, color: colors.textMuted, marginBottom: 12 }}>
          Guarda aquí el DPA, el RAT y la DPIA. Quedan en la app, con fecha y auditados, y se pueden descargar.
        </p>
        <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap", marginBottom: 14 }}>
          <Button variant="ghost" onClick={() => setImprimirDpa(true)}>
            Generar contrato de encargo (DPA) — PDF para firmar
          </Button>
          <span style={{ fontSize: 12, color: colors.textFaint }}>borrador pendiente de revisión legal</span>
        </div>
        {imprimirDpa && (
          <DpaImprimible centro={session?.centro_nombre ?? ""} onHecho={() => setImprimirDpa(false)} />
        )}
        {docs.error && <StateMessage tone="error">{docs.error}</StateMessage>}
        <DocumentosLegales
          tipos={[
            { value: "dpa", label: "Contrato de encargo (DPA)" },
            { value: "rat", label: "Registro de Actividades (RAT)" },
            { value: "dpia", label: "Evaluación de Impacto (DPIA)" },
            { value: "otro", label: "Otro" },
          ]}
        />
      </Card>
    </div>
  );
}
