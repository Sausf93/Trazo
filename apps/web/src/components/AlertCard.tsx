/**
 * Tarjeta de alerta en coral, calcada del bloque .alert-card de la presentación.
 * Muestra qué cambió y desde cuándo, con contexto legible para el cuidador.
 */
import { labelBloque } from "../api/vocab";
import type { Alerta } from "../api/types";
import { colors, radius } from "../theme";
import { fmtFecha, fmtPorcentaje, haceCuanto } from "../utils/format";
import { Badge, Button } from "./ui";

export function AlertCard({
  alerta,
  aliasLabel,
  onRevisar,
  revisando,
}: {
  alerta: Alerta;
  /** Alias del usuario (pseudonimizado) para dar contexto en la bandeja. */
  aliasLabel?: string;
  onRevisar?: (alertaId: string, resultado: string) => void;
  revisando?: boolean;
}) {
  const ctx = alerta.contexto_json ?? {};
  const yaRevisada = alerta.fecha_revision != null;

  return (
    <article
      style={{
        background: colors.alertBg,
        border: `1px solid ${colors.coral}`,
        borderRadius: radius.md,
        padding: "18px 20px",
        display: "flex",
        gap: 14,
        alignItems: "flex-start",
      }}
    >
      <span
        aria-hidden
        style={{
          width: 10,
          height: 10,
          borderRadius: "50%",
          background: colors.coralDark,
          marginTop: 8,
          flexShrink: 0,
        }}
      />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap", marginBottom: 6 }}>
          {aliasLabel && <Badge tone="coral">{aliasLabel}</Badge>}
          {alerta.bloque_afectado && <Badge tone="neutral">{labelBloque(alerta.bloque_afectado)}</Badge>}
          {yaRevisada && <Badge tone="sage">Revisada</Badge>}
        </div>

        <h3 style={{ fontSize: 17, marginBottom: 4 }}>
          Cambio detectado {haceCuanto(alerta.fecha_generada)}
        </h3>
        <p style={{ fontSize: 14.5, color: colors.alertText, marginBottom: 10 }}>
          {alerta.descripcion}
        </p>

        {(ctx.baseline_media != null || ctx.reciente_media != null) && (
          <dl style={contextGridStyle}>
            {ctx.baseline_media != null && (
              <ContextItem label="Su patrón habitual" value={fmtPorcentaje(ctx.baseline_media)} />
            )}
            {ctx.reciente_media != null && (
              <ContextItem
                label={`Últimas ${ctx.n_reciente ?? ""} sesiones`.trim()}
                value={fmtPorcentaje(ctx.reciente_media)}
                alert
              />
            )}
            {ctx.umbral_inferior != null && (
              <ContextItem label="Umbral de aviso" value={fmtPorcentaje(ctx.umbral_inferior)} />
            )}
            {ctx.caida != null && ctx.caida > 0 && (
              <ContextItem label="Caída" value={`−${fmtPorcentaje(ctx.caida)}`} alert />
            )}
          </dl>
        )}

        <p style={{ fontSize: 12.5, color: colors.textFaint, marginTop: 10 }} className="mono">
          Generada el {fmtFecha(alerta.fecha_generada)}
          {yaRevisada && ` · revisada el ${fmtFecha(alerta.fecha_revision)}`}
          {yaRevisada && alerta.resultado ? ` · resultado: ${alerta.resultado}` : ""}
        </p>

        {onRevisar && !yaRevisada && (
          <div style={{ marginTop: 14, display: "flex", gap: 10, flexWrap: "wrap" }}>
            <Button
              variant="primary"
              disabled={revisando}
              onClick={() => onRevisar(alerta.id, "revisada")}
            >
              {revisando ? "Guardando…" : "Marcar revisada"}
            </Button>
            <Button
              variant="ghost"
              disabled={revisando}
              onClick={() => onRevisar(alerta.id, "derivada")}
            >
              Revisada y derivada
            </Button>
          </div>
        )}
      </div>
    </article>
  );
}

const contextGridStyle: React.CSSProperties = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(120px, 1fr))",
  gap: 10,
  margin: 0,
};

function ContextItem({ label, value, alert }: { label: string; value: string; alert?: boolean }) {
  return (
    <div
      style={{
        background: colors.white,
        border: `1px solid ${alert ? colors.coral : colors.sand}`,
        borderRadius: radius.sm,
        padding: "8px 12px",
      }}
    >
      <dt style={{ fontSize: 11.5, color: colors.textFaint, marginBottom: 2 }}>{label}</dt>
      <dd
        style={{
          fontSize: 17,
          fontWeight: 600,
          margin: 0,
          color: alert ? colors.coralDeep : colors.ink,
        }}
      >
        {value}
      </dd>
    </div>
  );
}
