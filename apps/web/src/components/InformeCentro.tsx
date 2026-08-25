/**
 * Informe de ACTIVIDAD DEL CENTRO (para dirección, inspección, memorias y
 * financiadores). Documento agregado y anónimo: desempeño medio por área y
 * evidencia de uso/adherencia. Reutiliza el patrón de impresión de
 * InformeFamilia (clase `.trazo-informe` + portal a body + @media print);
 * "Imprimir → Guardar como PDF", sin librerías externas. RGPD: solo alias.
 */
import { createPortal } from "react-dom";
import type { ResumenArea, ResumenUso } from "../api/types";
import { labelBloque } from "../api/vocab";
import { colors, fonts } from "../theme";
import { fmtFecha } from "../utils/format";

export function InformeCentro({
  areas,
  uso,
  centroNombre,
}: {
  areas: ResumenArea[];
  uso: ResumenUso;
  centroNombre?: string | null;
}) {
  const generado = new Date();
  const areasOrden = [...areas].sort((a, b) => a.desempeno_medio - b.desempeno_medio);
  const tasaActivas =
    uso.personas_totales > 0
      ? Math.round((uso.personas_activas_30d / uso.personas_totales) * 100)
      : 0;

  return createPortal(
    <article
      className="trazo-informe"
      aria-label="Informe de actividad del centro"
      style={{
        background: colors.white,
        color: colors.ink,
        fontFamily: fonts.sans,
        fontSize: 14,
        lineHeight: 1.55,
        padding: "8px 4px",
      }}
    >
      <header style={{ borderBottom: `2px solid ${colors.sageDark}`, paddingBottom: 14, marginBottom: 20 }}>
        <div style={{ fontFamily: fonts.mono, fontSize: 11, letterSpacing: "0.14em", textTransform: "uppercase", color: colors.sageDark, marginBottom: 4 }}>
          {centroNombre?.trim() || "Estimulación cognitiva"}
        </div>
        <h1 style={{ fontFamily: fonts.serif, fontSize: 26, color: colors.ink, lineHeight: 1.15 }}>
          Informe de actividad del centro
        </h1>
        <div style={{ marginTop: 10, fontSize: 13, color: colors.textMuted }}>
          <strong style={{ color: colors.ink }}>Emitido:</strong> {fmtFecha(generado.toISOString())}
          {"  ·  "}
          <strong style={{ color: colors.ink }}>Personas dadas de alta:</strong> {uso.personas_totales}
        </div>
      </header>

      {/* Uso y adherencia */}
      <section style={{ marginBottom: 22, breakInside: "avoid" }}>
        <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 4, color: colors.ink }}>
          Uso del programa
        </h2>
        <p style={{ fontSize: 12.5, color: colors.textMuted, marginBottom: 10 }}>
          Cuánto se está utilizando el programa en el centro durante el último periodo.
        </p>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12 }}>
          <Dato titulo="Personas activas" valor={`${uso.personas_activas_30d} / ${uso.personas_totales}`} pie={`${tasaActivas} % participó en 30 días`} />
          <Dato titulo="Sesiones (últimos 7 días)" valor={String(uso.sesiones_7d)} pie="última semana" />
          <Dato titulo="Sesiones (últimos 30 días)" valor={String(uso.sesiones_30d)} pie="último mes" />
        </div>
      </section>

      {/* Desempeño por área */}
      {areasOrden.length > 0 && (
        <section style={{ marginBottom: 22, breakInside: "avoid" }}>
          <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 4, color: colors.ink }}>
            Desempeño por área
          </h2>
          <p style={{ fontSize: 12.5, color: colors.textMuted, marginBottom: 8 }}>
            Desempeño medio del centro en cada tipo de actividad (100 % = se resolvió siempre bien).
            De menor a mayor, para orientar dónde reforzar.
          </p>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ textAlign: "left", color: colors.textMuted }}>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Área</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Personas</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Desempeño medio</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>A revisar</th>
              </tr>
            </thead>
            <tbody>
              {areasOrden.map((a) => (
                <tr key={a.bloque}>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{labelBloque(a.bloque)}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{a.n_personas}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}`, fontWeight: 600 }}>{Math.round(a.desempeno_medio * 100)} %</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}`, color: a.n_por_debajo > 0 ? colors.coralDark : colors.textFaint }}>
                    {a.n_por_debajo > 0 ? `${a.n_por_debajo} persona${a.n_por_debajo === 1 ? "" : "s"}` : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      {/* Personas sin actividad reciente */}
      {uso.inactivas.length > 0 && (
        <section style={{ marginBottom: 22, breakInside: "avoid" }}>
          <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 4, color: colors.ink }}>
            Personas sin actividad reciente
          </h2>
          <p style={{ fontSize: 12.5, color: colors.textMuted, marginBottom: 8 }}>
            Conviene invitarlas a participar. Se identifican por su código interno (sin datos personales).
          </p>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ textAlign: "left", color: colors.textMuted }}>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Persona</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Sin participar</th>
              </tr>
            </thead>
            <tbody>
              {uso.inactivas.map((p) => (
                <tr key={p.usuario_final_id}>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{p.alias_interno}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>
                    {p.dias_sin_actividad == null ? "nunca ha participado" : `${p.dias_sin_actividad} días`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <footer style={{ marginTop: 8, paddingTop: 14, borderTop: `1px solid ${colors.sand}`, fontSize: 11.5, color: colors.textFaint }}>
        <p style={{ margin: 0 }}>
          Este informe refleja la <strong>actividad y el desempeño en los ejercicios</strong> del centro,
          no una medida de deterioro cognitivo ni un diagnóstico. Es un documento de gestión y seguimiento,
          orientativo, que interpreta el equipo profesional del centro en su contexto.
        </p>
        <p style={{ margin: "8px 0 0" }}>
          Documento generado por Trazo el {fmtFecha(generado.toISOString())}. Datos tratados conforme al RGPD:
          las personas se identifican mediante un código interno, sin datos personales.
        </p>
      </footer>
    </article>,
    document.body,
  );
}

function Dato({ titulo, valor, pie }: { titulo: string; valor: string; pie: string }) {
  return (
    <div style={{ border: `1px solid ${colors.sand}`, borderRadius: 12, padding: "12px 14px", background: colors.white }}>
      <div style={{ fontSize: 11.5, color: colors.textFaint, marginBottom: 3 }}>{titulo}</div>
      <div style={{ fontSize: 24, fontWeight: 700, color: colors.sageDark, lineHeight: 1.1 }}>{valor}</div>
      <div style={{ fontSize: 11, color: colors.textFaint, marginTop: 2 }}>{pie}</div>
    </div>
  );
}
