/**
 * Evolución individual de una persona:
 *  - selector de bloque
 *  - gráfica temporal de precisión (puntos fuera de patrón en coral)
 *  - resumen (rendimiento medio, tasa de ayuda)
 *  - sus alertas
 */
import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { alertasUsuario, evolucionUsuario, listarUsuarios } from "../api/endpoints";
import type { Alerta, Evolucion, UsuarioFinal } from "../api/types";
import { BLOQUES, labelBloque } from "../api/vocab";
import { AlertCard } from "../components/AlertCard";
import { EstadoBadge } from "../components/EstadoBadge";
import { EvolucionChart, construirSerie } from "../components/EvolucionChart";
import { Card, PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

export function UsuarioEvolucionPage() {
  const { id = "" } = useParams();
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const [bloque, setBloque] = useState<string>("");

  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const evolucion = useAsync<Evolucion>(
    (s) => evolucionUsuario(id, bloque ? { bloque } : {}, s),
    [id, bloque],
  );
  const alertas = useAsync<Alerta[]>((s) => alertasUsuario(id, s), [id]);

  const alias = usuarios.data?.find((u) => u.id === id)?.alias_interno ?? id;

  const serie = useMemo(
    () => (evolucion.data ? construirSerie(evolucion.data.puntos) : []),
    [evolucion.data],
  );
  const nAnomalos = serie.filter((p) => p.anomalo).length;

  return (
    <div>
      <Link to="/" style={{ color: colors.sageDark, fontSize: 14, fontWeight: 600, textDecoration: "none" }}>
        ← Volver al panel
      </Link>

      <div style={{ marginTop: 10 }}>
        <PageHeader
          eyebrow="Vista individual"
          title={alias}
          subtitle="Evolución en el tiempo comparada con su propio patrón, nunca con otras personas."
          actions={
            <Link
              to={`/usuarios/${id}/plan`}
              style={{
                display: "inline-block",
                fontFamily: fonts.sans,
                fontWeight: 600,
                fontSize: 15,
                padding: "11px 20px",
                borderRadius: radius.sm,
                border: `1.5px solid ${colors.sage}`,
                background: colors.sage,
                color: colors.white,
                textDecoration: "none",
              }}
            >
              Editar plan de trabajo
            </Link>
          }
        />
      </div>

      {/* Selector de bloque */}
      <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap", marginBottom: 20 }}>
        <label htmlFor="bloque" style={{ fontSize: 14, fontWeight: 600, color: colors.textMuted }}>
          Bloque cognitivo
        </label>
        <select
          id="bloque"
          value={bloque}
          onChange={(e) => setBloque(e.target.value)}
          style={{
            padding: "10px 13px",
            borderRadius: radius.sm,
            border: `1.5px solid ${colors.sand}`,
            background: colors.white,
            color: colors.ink,
            minWidth: 220,
          }}
        >
          <option value="">Todos los bloques</option>
          {BLOQUES.map((b) => (
            <option key={b} value={b}>
              {labelBloque(b)}
            </option>
          ))}
        </select>
      </div>

      {/* Resumen */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
          gap: 14,
          marginBottom: 22,
        }}
      >
        <ResumenTile
          label="Rendimiento medio"
          value={fmtPorcentaje(evolucion.data?.resumen.rendimiento_medio ?? null)}
          hint="Combina acierto y nivel de ayuda"
        />
        <ResumenTile
          label="Tasa de ayuda"
          value={fmtPorcentaje(evolucion.data?.resumen.tasa_ayuda ?? null)}
          hint="Proporción de intentos con ayuda"
          alert={(evolucion.data?.resumen.tasa_ayuda ?? 0) >= 0.3}
        />
        <ResumenTile
          label="Intentos registrados"
          value={String(evolucion.data?.resumen.n_intentos ?? "—")}
          hint={bloque ? labelBloque(bloque) : "Todos los bloques"}
        />
        <ResumenTile
          label="Puntos fuera de patrón"
          value={String(nAnomalos)}
          hint="Sesiones marcadas para revisar"
          alert={nAnomalos > 0}
        />
      </div>

      {/* Gráfica */}
      <Card style={{ marginBottom: 26 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 6 }}>
          <h2 style={{ fontSize: 19 }}>Precisión por sesión</h2>
          <span className="mono" style={{ fontSize: 12, color: colors.textFaint }}>
            {labelBloque(bloque)}
          </span>
        </div>
        {evolucion.loading && <Spinner label="Cargando evolución…" />}
        {evolucion.error && (
          <StateMessage tone="error" title="No se pudo cargar la evolución">
            {evolucion.error}
          </StateMessage>
        )}
        {evolucion.data && <EvolucionChart data={serie} />}
        {evolucion.data && (
          <div style={{ display: "flex", gap: 18, flexWrap: "wrap", marginTop: 10, fontSize: 12.5, color: colors.textFaint }}>
            <LegendDot color={colors.sage} label="Dentro de su patrón" />
            <LegendDot color={colors.coralDark} ring label="Fuera de patrón (revisar)" />
          </div>
        )}
      </Card>

      {/* Alertas de la persona */}
      <section aria-labelledby="alertas-persona" style={{ marginBottom: 26 }}>
        <h2 id="alertas-persona" style={{ fontSize: 19, marginBottom: 12 }}>Alertas de esta persona</h2>
        {alertas.loading && <Spinner label="Cargando alertas…" />}
        {alertas.error && (
          <StateMessage tone="error" title="No se pudieron cargar las alertas">
            {alertas.error}
          </StateMessage>
        )}
        {alertas.data && alertas.data.length === 0 && (
          <StateMessage title="Sin alertas">
            No hay cambios marcados para esta persona.
          </StateMessage>
        )}
        {alertas.data && alertas.data.length > 0 && (
          <div style={{ display: "grid", gap: 14 }}>
            {alertas.data.map((a) => (
              <AlertCard key={a.id} alerta={a} />
            ))}
          </div>
        )}
      </section>

      {/* Detalle de intentos */}
      {evolucion.data && evolucion.data.puntos.length > 0 && (
        <section aria-labelledby="detalle-intentos">
          <h2 id="detalle-intentos" style={{ fontSize: 19, marginBottom: 12 }}>Detalle de sesiones</h2>
          <Card style={{ padding: 0 }}>
            <div className="scroll-x">
              <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14.5, minWidth: 480 }}>
                <thead>
                  <tr style={{ textAlign: "left", color: colors.textFaint, fontFamily: fonts.mono, fontSize: 12 }}>
                    <Th>Fecha</Th>
                    <Th>Bloque</Th>
                    <Th>Estado</Th>
                    <Th>Precisión</Th>
                  </tr>
                </thead>
                <tbody>
                  {[...evolucion.data.puntos].reverse().map((p, i) => (
                    <tr key={`${p.ejercicio_id}-${p.fecha}-${i}`} style={{ borderTop: `1px solid ${colors.card}` }}>
                      <Td>{fmtFecha(p.fecha)}</Td>
                      <Td>{labelBloque(p.bloque)}</Td>
                      <Td><EstadoBadge estado={p.estado} /></Td>
                      <Td>{fmtPorcentaje(p.precision)}</Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </section>
      )}
    </div>
  );
}

function ResumenTile({
  label,
  value,
  hint,
  alert,
}: {
  label: string;
  value: string;
  hint?: string;
  alert?: boolean;
}) {
  return (
    <div
      style={{
        background: colors.white,
        border: `1px solid ${alert ? colors.coral : colors.sand}`,
        borderRadius: radius.md,
        padding: "16px 18px",
      }}
    >
      <div style={{ fontSize: 13, color: colors.textFaint, marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 28, fontWeight: 600, color: alert ? colors.coralDark : colors.ink }}>
        {value}
      </div>
      {hint && <div style={{ fontSize: 12, color: colors.textFaint, marginTop: 2 }}>{hint}</div>}
    </div>
  );
}

function LegendDot({ color, label, ring }: { color: string; label: string; ring?: boolean }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
      <span style={{ position: "relative", width: 14, height: 14, display: "inline-block" }} aria-hidden>
        {ring && (
          <span
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              border: `2px solid ${colors.coral}`,
            }}
          />
        )}
        <span
          style={{
            position: "absolute",
            inset: 4,
            borderRadius: "50%",
            background: color,
          }}
        />
      </span>
      {label}
    </span>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th style={{ padding: "12px 16px", fontWeight: 600 }}>{children}</th>;
}
function Td({ children }: { children: React.ReactNode }) {
  return <td style={{ padding: "12px 16px" }}>{children}</td>;
}
