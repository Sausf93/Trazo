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
import type { Evolucion } from "../api/types";
import { EvolucionChart, type PuntoChart } from "./EvolucionChart";
import { colors, fonts } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

type Tendencia = "mejora" | "estable" | "empeora" | "insuficiente";

/**
 * Tendencia sencilla comparando la primera mitad de las sesiones con la última,
 * sobre el mismo criterio de precisión que muestra la gráfica.
 */
function calcularTendencia(serie: PuntoChart[]): Tendencia {
  const ys = serie.map((p) => p.precision);
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
}: {
  alias: string;
  bloqueLabel: string;
  evolucion: Evolucion;
  serie: PuntoChart[];
}) {
  const { puntos, resumen } = evolucion;

  // Periodo (fechas mínima y máxima de las sesiones registradas).
  const fechas = puntos.map((p) => p.fecha).filter(Boolean).sort();
  const desde = fechas[0];
  const hasta = fechas[fechas.length - 1];

  // Reparto solo / con ayuda / no completado sobre el total de sesiones.
  const total = puntos.length;
  const nSolo = puntos.filter((p) => p.estado === "solo").length;
  const nAyuda = puntos.filter((p) => p.estado === "con_ayuda").length;
  const nNoComp = puntos.filter((p) => p.estado === "no_completado").length;
  const pct = (n: number) => (total > 0 ? Math.round((n / total) * 100) : 0);

  const tendencia = calcularTendencia(serie);
  const tTexto = TENDENCIA_TEXTO[tendencia];
  const nAnomalos = serie.filter((p) => p.anomalo).length;

  const generado = new Date();

  return (
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
              Trazo · Estimulación cognitiva
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
          Cada punto es una sesión. La línea sube cuando acierta más y necesita menos ayuda.
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
          <Dato titulo="Sesiones realizadas" valor={String(total)} pie="en este periodo" />
          <Dato
            titulo="Lo hizo por sí mismo/a"
            valor={total > 0 ? `${pct(nSolo)} %` : "—"}
            pie={`${nSolo} de ${total} sesiones`}
          />
          <Dato
            titulo="Necesitó algo de ayuda"
            valor={total > 0 ? `${pct(nAyuda)} %` : "—"}
            pie={`${nAyuda} de ${total} sesiones`}
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
              Rendimiento medio del periodo: <strong style={{ color: colors.ink }}>{fmtPorcentaje(resumen.rendimiento_medio)}</strong>{" "}
              (combina aciertos y autonomía).
            </li>
            <li>
              Autonomía: hizo <strong style={{ color: colors.ink }}>{pct(nSolo)} %</strong> de las sesiones por sí
              mismo/a y necesitó ayuda en un <strong style={{ color: colors.ink }}>{pct(nAyuda)} %</strong>.
              {nNoComp > 0 && ` Quedaron sin completar ${pct(nNoComp)} %.`}
            </li>
            {nAnomalos > 0 && (
              <li>
                El equipo ha marcado{" "}
                <strong style={{ color: colors.ink }}>{nAnomalos}</strong>{" "}
                {nAnomalos === 1 ? "sesión" : "sesiones"} para revisar con más atención.
              </li>
            )}
          </ul>
        </div>
      </section>

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
          No constituye un diagnóstico ni sustituye la valoración del equipo profesional del centro,
          que es quien interpreta la evolución en su contexto. Para cualquier duda, consulte con el
          personal de referencia.
        </p>
        <p style={{ margin: "8px 0 0" }}>
          Documento generado por Trazo el {fmtFecha(generado.toISOString())}. Datos tratados conforme al
          RGPD: se identifica a la persona mediante un código interno, sin datos personales.
        </p>
      </footer>
    </article>
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
