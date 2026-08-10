/**
 * Historial de sesiones cerradas del centro.
 * Lista GET /sesiones?estado=cerrada; al elegir una se muestra su resumen
 * (GET /sesiones/{id}/resumen) con una barra por persona repartida en
 * solo / con ayuda / no pudo. Siempre se usa alias_interno (RGPD).
 */
import { useState } from "react";
import { listarSesiones, resumenSesion } from "../api/endpoints";
import type { FichaResumen, ResumenSesion, SesionListItem } from "../api/types";
import { PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";
import { fmtFecha } from "../utils/format";

export function SesionesPage() {
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const [sesionSel, setSesionSel] = useState<SesionListItem | null>(null);

  const sesiones = useAsync<SesionListItem[]>(
    (s) => listarSesiones({ centro_id: centroId, estado: "cerrada" }, s),
    [centroId],
  );

  if (sesionSel) {
    return <ResumenDetalle sesion={sesionSel} onVolver={() => setSesionSel(null)} />;
  }

  return (
    <div>
      <PageHeader
        eyebrow="Historial"
        title="Sesiones"
        subtitle="Repasa cómo fue cada sesión ya cerrada: cuántas personas participaron y cómo le fue a cada una."
      />

      {sesiones.loading && <Spinner label="Cargando historial…" />}
      {sesiones.error && (
        <StateMessage tone="error" title="No se pudo cargar el historial">
          {sesiones.error}
        </StateMessage>
      )}
      {sesiones.data && sesiones.data.length === 0 && (
        <StateMessage title="Todavía no hay sesiones cerradas">
          Cuando termine una sesión, quedará guardada aquí para consultarla más tarde.
        </StateMessage>
      )}
      {sesiones.data && sesiones.data.length > 0 && (
        <div style={{ display: "grid", gap: 12 }}>
          {sesiones.data.map((s) => {
            const n = s.n_participantes;
            return (
              <button
                key={s.id}
                onClick={() => setSesionSel(s)}
                style={{
                  textAlign: "left",
                  cursor: "pointer",
                  background: colors.white,
                  border: `1px solid ${colors.sand}`,
                  borderRadius: radius.md,
                  padding: "16px 20px",
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  gap: 16,
                }}
              >
                <span>
                  <span style={{ display: "block", fontFamily: fonts.serif, fontSize: 20 }}>{s.nombre}</span>
                  <span style={{ fontSize: 13, color: colors.textFaint }}>{fmtFecha(s.fecha)}</span>
                </span>
                <span style={{ fontSize: 13, color: colors.textMuted, whiteSpace: "nowrap" }}>
                  {n} participante{n === 1 ? "" : "s"} →
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

const SEGMENTOS = [
  { key: "logrado", label: "Lo logró", color: colors.sage },
  { key: "parcial", label: "A medias", color: colors.coral },
  { key: "no_logrado", label: "No lo logró", color: colors.sand },
] as const;

function ResumenDetalle({ sesion, onVolver }: { sesion: SesionListItem; onVolver: () => void }) {
  const resumen = useAsync<ResumenSesion>((s) => resumenSesion(sesion.id, s), [sesion.id]);

  return (
    <div>
      <button
        onClick={onVolver}
        style={{ background: "none", border: "none", padding: 0, margin: 0, textAlign: "left", cursor: "pointer", color: colors.sageDark, fontSize: 14, fontWeight: 600 }}
      >
        ← Volver al historial
      </button>

      <div style={{ marginTop: 10 }}>
        <PageHeader
          eyebrow="Resumen de sesión"
          title={sesion.nombre}
          subtitle={fmtFecha(sesion.fecha)}
        />
      </div>

      {resumen.loading && <Spinner label="Cargando resumen…" />}
      {resumen.error && (
        <StateMessage tone="error" title="No se pudo cargar el resumen">
          {resumen.error}
        </StateMessage>
      )}
      {resumen.data && resumen.data.fichas.length === 0 && (
        <StateMessage title="Sesión sin participantes">
          Esta sesión no registró intentos de ninguna persona.
        </StateMessage>
      )}
      {resumen.data && resumen.data.notas && (
        <div
          style={{
            background: colors.white,
            border: `1px solid ${colors.sand}`,
            borderRadius: radius.md,
            padding: "14px 18px",
            marginBottom: 18,
          }}
        >
          <div style={{ fontSize: 12, color: colors.textMuted, marginBottom: 6, textTransform: "uppercase", letterSpacing: 0.4 }}>
            Observaciones de la facilitadora
          </div>
          <div style={{ whiteSpace: "pre-wrap", color: colors.text }}>{resumen.data.notas}</div>
        </div>
      )}
      {resumen.data && resumen.data.fichas.length > 0 && (
        <div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 16, marginBottom: 18 }}>
            {SEGMENTOS.map((seg) => (
              <span key={seg.key} style={{ display: "inline-flex", alignItems: "center", gap: 8, fontSize: 13, color: colors.textMuted }}>
                <span aria-hidden style={{ width: 12, height: 12, borderRadius: 3, background: seg.color, display: "inline-block" }} />
                {seg.label}
              </span>
            ))}
          </div>
          <div style={{ display: "grid", gap: 14 }}>
            {resumen.data.fichas.map((f) => (
              <FichaBarra key={f.usuario_final_id} ficha={f} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function FichaBarra({ ficha }: { ficha: FichaResumen }) {
  const total = ficha.logrado + ficha.parcial + ficha.no_logrado;
  return (
    <div
      style={{
        background: colors.white,
        border: `1px solid ${colors.sand}`,
        borderRadius: radius.md,
        padding: "16px 20px",
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 10, gap: 12 }}>
        <span style={{ fontFamily: fonts.serif, fontSize: 18 }}>{ficha.alias_interno}</span>
        <span className="mono" style={{ fontSize: 12, color: colors.textFaint }}>
          {ficha.n_intentos} intento{ficha.n_intentos === 1 ? "" : "s"}
        </span>
      </div>

      <div
        role="img"
        aria-label={`${ficha.alias_interno}: ${ficha.logrado} lo logró, ${ficha.parcial} a medias, ${ficha.no_logrado} no lo logró`}
        style={{ display: "flex", height: 16, borderRadius: 999, overflow: "hidden", background: colors.card }}
      >
        {total > 0 &&
          SEGMENTOS.map((seg) => {
            const valor = ficha[seg.key];
            if (valor <= 0) return null;
            return (
              <span
                key={seg.key}
                style={{ width: `${(valor / total) * 100}%`, background: seg.color, display: "block" }}
              />
            );
          })}
      </div>

      <div style={{ display: "flex", gap: 18, marginTop: 8 }}>
        {SEGMENTOS.map((seg) => (
          <span key={seg.key} style={{ fontSize: 12.5, color: colors.textMuted }}>
            <span aria-hidden style={{ display: "inline-block", width: 8, height: 8, borderRadius: 2, background: seg.color, marginRight: 6 }} />
            {seg.label}: <strong style={{ color: colors.ink }}>{ficha[seg.key]}</strong>
          </span>
        ))}
      </div>
    </div>
  );
}
