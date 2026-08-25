/**
 * Consentimiento RGPD por persona: deja constancia en la app de que hay
 * consentimiento firmado (quién lo otorga y en qué calidad), imprescindible en un
 * centro de día con personas con capacidad modificada. El backend NO guarda el
 * documento: solo una referencia al archivador físico/escaneado.
 */
import { useState } from "react";
import { listarConsentimientos, registrarConsentimiento } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Consentimiento } from "../api/types";
import { useAsync } from "../hooks/useAsync";
import { useAuth } from "../auth/AuthContext";
import { Card, Spinner, StateMessage, Button } from "./ui";
import { colors, radius } from "../theme";
import { fmtFecha } from "../utils/format";
import { ConsentimientoImprimible, VERSION_CONSENTIMIENTO } from "./ConsentimientoImprimible";

const ROLES: { value: string; label: string }[] = [
  { value: "titular", label: "La propia persona" },
  { value: "representante_legal", label: "Representante legal" },
  { value: "tutor", label: "Tutor/a" },
  { value: "guardador_hecho", label: "Guardador/a de hecho" },
];
const TIPOS: { value: string; label: string }[] = [
  { value: "uso_y_seguimiento", label: "Uso y seguimiento" },
  { value: "imagen", label: "Imagen" },
];

function labelDe(list: { value: string; label: string }[], v: string): string {
  return list.find((x) => x.value === v)?.label ?? v;
}

export function ConsentimientoPaciente({ usuarioId, personaAlias }: { usuarioId: string; personaAlias?: string }) {
  const cons = useAsync<Consentimiento[]>((s) => listarConsentimientos(usuarioId, s), [usuarioId]);
  const { session } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);
  const [tipo, setTipo] = useState("uso_y_seguimiento");
  const [otorgadoPor, setOtorgadoPor] = useState("");
  const [rol, setRol] = useState("titular");
  const [docRef, setDocRef] = useState("");
  // Cuando != null, se monta el documento imprimible de ese tipo y se imprime.
  const [imprimirTipo, setImprimirTipo] = useState<string | null>(null);

  // ¿Falta el consentimiento básico de uso? (aviso visible para estar en regla)
  const tieneUso = (cons.data ?? []).some((c) => c.tipo === "uso_y_seguimiento");

  async function onGuardar(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (otorgadoPor.trim().length < 2) {
      setError("Indica quién otorga el consentimiento.");
      return;
    }
    setGuardando(true);
    try {
      await registrarConsentimiento(usuarioId, {
        tipo,
        otorgado_por: otorgadoPor.trim(),
        rol_otorgante: rol,
        documento_ref: docRef.trim() || null,
      });
      setOtorgadoPor("");
      setDocRef("");
      cons.reload();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo registrar el consentimiento.");
    } finally {
      setGuardando(false);
    }
  }

  return (
    <section aria-labelledby="consent-h" style={{ marginTop: 28 }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 6 }}>
        <h2 id="consent-h" style={{ fontSize: 20 }}>Consentimiento (RGPD)</h2>
        {cons.data && (
          tieneUso ? (
            <span style={{ fontSize: 12.5, color: colors.sageDark, fontWeight: 600 }}>· en regla</span>
          ) : (
            <span style={{ fontSize: 12.5, color: colors.coralDark, fontWeight: 600 }}>· falta el consentimiento de uso</span>
          )
        )}
      </div>
      <p style={{ color: colors.textMuted, fontSize: 14, marginBottom: 12 }}>
        Genera el documento ya rellenado, imprímelo o guárdalo en PDF y hazlo firmar. Después,
        registra abajo el consentimiento (queda con fecha y en el registro de auditoría) y anota
        dónde archivas el original.
      </p>
      <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center", marginBottom: 16 }}>
        <Button variant="ghost" onClick={() => setImprimirTipo("uso_y_seguimiento")}>
          Consentimiento de uso — PDF para firmar
        </Button>
        <Button variant="ghost" onClick={() => setImprimirTipo("imagen")}>
          Consentimiento de imagen — PDF
        </Button>
        <span style={{ fontSize: 12, color: colors.textFaint }}>
          Texto {VERSION_CONSENTIMIENTO} · borrador pendiente de revisión legal
        </span>
      </div>
      {imprimirTipo && (
        <ConsentimientoImprimible
          centro={session?.centro_nombre ?? ""}
          personaAlias={personaAlias ?? usuarioId}
          tipo={imprimirTipo}
          onHecho={() => setImprimirTipo(null)}
        />
      )}

      {error && <div style={{ marginBottom: 12 }}><StateMessage tone="error">{error}</StateMessage></div>}
      {cons.error && (
        <div style={{ marginBottom: 12 }}>
          <StateMessage tone="error" title="No se pudieron cargar los consentimientos">
            {cons.error}
          </StateMessage>
        </div>
      )}
      {cons.loading && <Spinner label="Cargando consentimientos…" />}

      {cons.data && cons.data.length > 0 && (
        <div style={{ display: "grid", gap: 10, marginBottom: 18 }}>
          {cons.data.map((c) => (
            <Card key={c.id} style={{ padding: "12px 16px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
                <div style={{ fontWeight: 600, color: colors.ink }}>{labelDe(TIPOS, c.tipo)}</div>
                <div style={{ fontSize: 12.5, color: colors.textFaint }}>{fmtFecha(c.fecha)}</div>
              </div>
              <div style={{ fontSize: 13.5, color: colors.textMuted, marginTop: 4 }}>
                Otorgado por <strong style={{ color: colors.ink }}>{c.otorgado_por}</strong> ({labelDe(ROLES, c.rol_otorgante)})
                {c.documento_ref && <> · doc.: {c.documento_ref}</>}
              </div>
            </Card>
          ))}
        </div>
      )}
      {cons.data && cons.data.length === 0 && (
        <div style={{ marginBottom: 16 }}>
          <StateMessage title="Sin consentimientos registrados">
            Registra el consentimiento de uso para tener a la persona en regla ante una inspección.
          </StateMessage>
        </div>
      )}

      <Card style={{ padding: "16px 18px" }}>
        <form onSubmit={onGuardar} style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4 }}>
            Tipo
            <select value={tipo} onChange={(e) => setTipo(e.target.value)}
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }}>
              {TIPOS.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>
          </label>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4, flex: "1 1 200px" }}>
            Otorgado por
            <input value={otorgadoPor} onChange={(e) => setOtorgadoPor(e.target.value)}
              placeholder="nombre de quien firma"
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }} />
          </label>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4 }}>
            En calidad de
            <select value={rol} onChange={(e) => setRol(e.target.value)}
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }}>
              {ROLES.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
            </select>
          </label>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4, flex: "1 1 160px" }}>
            Referencia del documento (opcional)
            <input value={docRef} onChange={(e) => setDocRef(e.target.value)}
              placeholder="p. ej. carpeta 2026, folio 12"
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }} />
          </label>
          <button type="submit" disabled={guardando}
            style={{
              padding: "10px 18px", borderRadius: radius.sm, border: `1.5px solid ${colors.sageDark}`,
              background: colors.sageDark, color: colors.white, fontWeight: 600, fontSize: 14,
              cursor: guardando ? "default" : "pointer", opacity: guardando ? 0.6 : 1,
            }}>
            {guardando ? "Registrando…" : "Registrar consentimiento"}
          </button>
        </form>
      </Card>
    </section>
  );
}
