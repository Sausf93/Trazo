/**
 * Informe de evolución para la FAMILIA de una persona usuaria.
 *
 * Se renderiza siempre en el DOM (posicionado fuera de pantalla) para que la
 * gráfica de Recharts pueda medir su ancho, y solo se hace visible al imprimir
 * gracias a las reglas `@media print` de index.css (clase `.trazo-informe`).
 *
 * Pensado para "Imprimir → Guardar como PDF": no usa librerías externas.
 * RGPD: solo se muestra el alias interno, nunca el nombre real.
 */
import { createPortal } from "react-dom";
import type { Evolucion, Objetivo } from "../api/types";
import { labelBloque } from "../api/vocab";
import { EvolucionChart, type PuntoChart } from "./EvolucionChart";
import { colors, fonts } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

type Tendencia = "mejora" | "estable" | "empeora" | "insuficiente";

/**
 * Tendencia sencilla comparando la primera mitad de las sesiones con la última,
 * sobre el mismo criterio de desempeño que muestra la gráfica (definido para
 * todas las plantillas, no solo las que dan "precisión").
 */
function calcularTendencia(serie: PuntoChart[]): Tendencia {
  const ys = serie.map((p) => p.desempeno);
  if (ys.length < 4) return "insuficiente";
  const mitad = Math.floor(ys.length / 2);
  const primeras = ys.slice(0, mitad);
  const ultimas = ys.slice(ys.length - mitad);
  const media = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;
  const diff = media(ultimas) - media(primeras);
  if (diff >= 0.05) return "mejora";
  if (diff <= -0.05) return "empeora";
  return "estable";
}

const TENDENCIA_TEXTO: Record<Tendencia, { titulo: string; detalle: string }> = {
  mejora: {
    titulo: "Tendencia de mejora",
    detalle:
      "En las últimas sesiones ha rendido, de media, mejor que al principio del periodo.",
  },
  estable: {
    titulo: "Evolución estable",
    detalle:
      "Su rendimiento se ha mantenido bastante constante a lo largo del periodo.",
  },
  empeora: {
    titulo: "Tendencia a revisar",
    detalle:
      "En las últimas sesiones ha rendido, de media, algo por debajo del inicio del periodo. El equipo lo tiene en seguimiento.",
  },
  insuficiente: {
    titulo: "Aún con pocos datos",
    detalle:
      "Todavía no hay suficientes sesiones registradas para hablar de una tendencia clara.",
  },
};

export function InformeFamilia({
  alias,
  bloqueLabel,
  evolucion,
  serie,
  objetivos = [],
  centroNombre,
}: {
  alias: string;
  bloqueLabel: string;
  evolucion: Evolucion;
  serie: PuntoChart[];
  objetivos?: Objetivo[];
  centroNombre?: string | null;
}) {
  const { puntos, resumen } = evolucion;

  // Periodo (fechas mínima y máxima de las sesiones registradas).
  const fechas = puntos.map((p) => p.fecha).filter(Boolean).sort();
  const desde = fechas[0];
  const hasta = fechas[fechas.length - 1];

  // Reparto del resultado (lo logró / a medias / no lo logró) sobre el total.
  const total = puntos.length;
  const nLogrado = puntos.filter((p) => p.estado === "logrado").length;
  const nParcial = puntos.filter((p) => p.estado === "parcial").length;
  const nNoLogrado = puntos.filter((p) => p.estado === "no_logrado").length;
  const pct = (n: number) => (total > 0 ? Math.round((n / total) * 100) : 0);

  const tendencia = calcularTendencia(serie);
  const tTexto = TENDENCIA_TEXTO[tendencia];

  // Desempeño por ÁREA (para la reunión con la familia: en qué anda mejor/peor).
  const PESO: Record<string, number> = { logrado: 1, parcial: 0.5, no_logrado: 0 };
  const porArea = new Map<string, { suma: number; n: number }>();
  for (const p of puntos) {
    if (!(p.estado in PESO)) continue;
    const a = porArea.get(p.bloque) ?? { suma: 0, n: 0 };
    a.suma += PESO[p.estado];
    a.n += 1;
    porArea.set(p.bloque, a);
  }
  const areas = [...porArea.entries()]
    .map(([bloque, { suma, n }]) => ({ bloque, n, desempeno: n > 0 ? suma / n : null }))
    // Al menos 2 actividades por área: un 0%/100% de una sola actividad daría una
    // impresión desproporcionada a la familia.
    .filter((a) => a.n >= 2)
    .sort((a, b) => (b.desempeno ?? 0) - (a.desempeno ?? 0));

  const generado = new Date();

  // Se saca fuera de la app (portal a body) para que al imprimir se pueda ocultar
  // TODA la app (#root) sin llevarse el informe -> se acaban las páginas en blanco.
  return createPortal(
    <article
      className="trazo-informe"
      aria-label="Informe de evolución para la familia"
      style={{
        background: colors.white,
        color: colors.ink,
        fontFamily: fonts.sans,
        fontSize: 14,
        lineHeight: 1.55,
        padding: "8px 4px",
      }}
    >
      {/* Cabecera */}
      <header
        style={{
          borderBottom: `2px solid ${colors.sageDark}`,
          paddingBottom: 14,
          marginBottom: 20,
        }}
      >
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "flex-end",
            gap: 16,
            flexWrap: "wrap",
          }}
        >
          <div>
            <div
              style={{
                fontFamily: fonts.mono,
                fontSize: 11,
                letterSpacing: "0.14em",
                textTransform: "uppercase",
                color: colors.sageDark,
                marginBottom: 4,
              }}
            >
              {centroNombre?.trim() || "Estimulación cognitiva"}
            </div>
            <h1 style={{ fontFamily: fonts.serif, fontSize: 26, color: colors.ink, lineHeight: 1.15 }}>
              Informe de evolución
            </h1>
          </div>
          <div style={{ textAlign: "right", fontSize: 12.5, color: colors.textMuted }}>
            <div>
              <strong style={{ color: colors.ink }}>Persona:</strong> {alias}
            </div>
            <div>
              <strong style={{ color: colors.ink }}>Área:</strong> {bloqueLabel}
            </div>
            <div>
              <strong style={{ color: colors.ink }}>Emitido:</strong> {fmtFecha(generado.toISOString())}
            </div>
          </div>
        </div>

        <div style={{ marginTop: 12, fontSize: 13, color: colors.textMuted }}>
          <strong style={{ color: colors.ink }}>Periodo:</strong>{" "}
          {desde ? `${fmtFecha(desde)} — ${fmtFecha(hasta)}` : "sin sesiones registradas todavía"}
          {"  ·  "}
          <strong style={{ color: colors.ink }}>Sesiones:</strong> {total}
        </div>
      </header>

      {/* Gráfica de evolución */}
      <section style={{ marginBottom: 22, breakInside: "avoid" }}>
        <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 4, color: colors.ink }}>
          Cómo ha ido en el tiempo
        </h2>
        <p style={{ fontSize: 12.5, color: colors.textMuted, marginBottom: 8 }}>
          Cada punto es una sesión. La línea sube cuando resuelve mejor las actividades.
          Siempre se compara a la persona consigo misma, nunca con otras.
        </p>
        <div
          style={{
            border: `1px solid ${colors.sand}`,
            borderRadius: 12,
            padding: "10px 12px 4px",
            background: colors.white,
          }}
        >
          <EvolucionChart data={serie} />
        </div>
      </section>

      {/* Objetivos de intervención: convierte el informe en un PLAN medible. */}
      {objetivos.filter((o) => o.activo).length > 0 && (
        <section style={{ marginBottom: 22, breakInside: "avoid" }}>
          <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 4, color: colors.ink }}>
            Objetivos de trabajo
          </h2>
          <p style={{ fontSize: 12.5, color: colors.textMuted, marginBottom: 8 }}>
            Metas que el equipo se ha marcado con {alias} en cada área, y cómo va respecto a ellas.
          </p>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ textAlign: "left", color: colors.textMuted }}>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Área</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Meta</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Objetivo</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Cómo va</th>
              </tr>
            </thead>
            <tbody>
              {objetivos.filter((o) => o.activo).map((o) => (
                <tr key={o.id}>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{labelBloque(o.bloque)}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{o.descripcion ?? "—"}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{Math.round(o.objetivo_desempeno * 100)} %</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}`, color: o.cumple ? colors.sageDark : colors.coralDark }}>
                    {o.situacion_actual == null
                      ? "aún sin datos"
                      : `${Math.round(o.situacion_actual * 100)} %${o.cumple ? " · lo cumple" : " · por debajo"}`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      {/* Resumen en lenguaje llano */}
      <section style={{ marginBottom: 22, breakInside: "avoid" }}>
        <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 10, color: colors.ink }}>
          Un resumen sencillo
        </h2>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, 1fr)",
            gap: 12,
            marginBottom: 14,
          }}
        >
          <Dato titulo="Actividades realizadas" valor={String(total)} pie="en este periodo" />
          <Dato
            titulo="Las resolvió bien"
            valor={total > 0 ? `${pct(nLogrado)} %` : "—"}
            pie={`${nLogrado} de ${total}`}
          />
          <Dato
            titulo="A medias"
            valor={total > 0 ? `${pct(nParcial)} %` : "—"}
            pie={`${nParcial} de ${total}`}
          />
        </div>

        <div
          style={{
            border: `1px solid ${colors.sand}`,
            background: colors.card,
            borderRadius: 12,
            padding: "14px 16px",
          }}
        >
          <div style={{ fontFamily: fonts.serif, fontSize: 16, color: colors.ink, marginBottom: 4 }}>
            {tTexto.titulo}
          </div>
          <p style={{ fontSize: 13.5, color: colors.textMuted, margin: 0 }}>{tTexto.detalle}</p>

          <ul style={{ margin: "10px 0 0", paddingLeft: 18, fontSize: 13, color: colors.textMuted }}>
            <li>
              Desempeño medio del periodo: <strong style={{ color: colors.ink }}>{fmtPorcentaje(resumen.rendimiento_medio)}</strong>{" "}
              (combina aciertos y grado de logro).
            </li>
            <li>
              Resolvió bien un <strong style={{ color: colors.ink }}>{pct(nLogrado)} %</strong> de las
              actividades y a medias un <strong style={{ color: colors.ink }}>{pct(nParcial)} %</strong>.
              {nNoLogrado > 0 && ` No logró un ${pct(nNoLogrado)} %.`}
            </li>
          </ul>
        </div>
      </section>

      {/* Cómo va cada área (si hay datos de más de un área en el periodo). */}
      {areas.length > 1 && (
        <section style={{ marginBottom: 22, breakInside: "avoid" }}>
          <h2 style={{ fontFamily: fonts.serif, fontSize: 18, marginBottom: 4, color: colors.ink }}>
            Cómo va cada área
          </h2>
          <p style={{ fontSize: 12.5, color: colors.textMuted, marginBottom: 8 }}>
            Desempeño en cada tipo de actividad durante el periodo (100 % = lo resolvió siempre bien).
          </p>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ textAlign: "left", color: colors.textMuted }}>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Área</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Actividades</th>
                <th style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.sand}` }}>Desempeño</th>
              </tr>
            </thead>
            <tbody>
              {areas.map((a) => (
                <tr key={a.bloque}>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{labelBloque(a.bloque)}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}` }}>{a.n}</td>
                  <td style={{ padding: "6px 8px", borderBottom: `1px solid ${colors.card}`, fontWeight: 600 }}>
                    {a.desempeno == null ? "—" : `${Math.round(a.desempeno * 100)} %`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      {/* Nota orientativa */}
      <footer
        style={{
          marginTop: 8,
          paddingTop: 14,
          borderTop: `1px solid ${colors.sand}`,
          fontSize: 11.5,
          color: colors.textFaint,
        }}
      >
        <p style={{ margin: 0 }}>
          Este informe es <strong>orientativo</strong> y tiene una finalidad divulgativa para la familia.
          Refleja el <strong>desempeño en las actividades</strong>, no una medida de deterioro cognitivo:
          un cambio puede deberse a muchas causas ajenas a lo cognitivo (vista u oído, dolor, medicación,
          ánimo, un día malo o una infección pasajera). No constituye un diagnóstico ni sustituye la
          valoración del equipo profesional del centro, que es quien la interpreta en su contexto. Para
          cualquier duda, consulte con el personal de referencia.
        </p>
        <p style={{ margin: "8px 0 0" }}>
          Documento generado por Trazo el {fmtFecha(generado.toISOString())}. Datos tratados conforme al
          RGPD: se identifica a la persona mediante un código interno, sin datos personales.
        </p>
      </footer>
    </article>,
    document.body,
  );
}

function Dato({ titulo, valor, pie }: { titulo: string; valor: string; pie: string }) {
  return (
    <div
      style={{
        border: `1px solid ${colors.sand}`,
        borderRadius: 12,
        padding: "12px 14px",
        background: colors.white,
      }}
    >
      <div style={{ fontSize: 11.5, color: colors.textFaint, marginBottom: 3 }}>{titulo}</div>
      <div style={{ fontSize: 24, fontWeight: 700, color: colors.sageDark, lineHeight: 1.1 }}>{valor}</div>
      <div style={{ fontSize: 11, color: colors.textFaint, marginTop: 2 }}>{pie}</div>
    </div>
  );
}
