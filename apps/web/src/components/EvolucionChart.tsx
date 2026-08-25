/**
 * Gráfica temporal de precisión por sesión — una TENDENCIA para acompañar la
 * lectura. La detección real de "fuera de patrón" vive en el backend (motor de
 * alertas, por sesión y segmentado por dificultad) y se muestra como el veredicto
 * y las tarjetas de alerta; aquí NO se reimplementa una heurística aparte que
 * podría contradecirla (antes pintaba puntos coral que no casaban con una alerta).
 */
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { PuntoEvolucion } from "../api/types";
import { colors, fonts } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";
import { labelEstado } from "../api/vocab";

export interface PuntoChart {
  idx: number;
  fecha: string;
  /** Desempeño autocorregido 0..1 (logrado=1, parcial=0.5, no_logrado=0). Es
   * la MISMA señal que la cabecera y el motor de alertas: definida para las 8
   * plantillas, no solo las que dan "precisión". */
  desempeno: number;
  /** Precisión fina (solo trazo/memoria/búsqueda). Informativa, para el tooltip. */
  precision: number | null;
  estado: string;
  anomalo: boolean;
}

// Peso del resultado autocorregido, idéntico al backend (anomalias._PESO_RESULTADO).
const PESO_DESEMPENO: Record<string, number> = {
  logrado: 1,
  parcial: 0.5,
  no_logrado: 0,
};

export function construirSerie(puntos: PuntoEvolucion[]): PuntoChart[] {
  // Se toman TODOS los intentos ya valorados (no solo los que tienen "precisión"):
  // antes la gráfica y el informe quedaban vacíos con el 72% del catálogo pese a
  // haber hecho muchas actividades. Los "sin_valorar" no puntúan aún, se omiten.
  const valorados = puntos.filter((p) => p.estado in PESO_DESEMPENO);
  return valorados.map((p, i) => ({
    idx: i,
    fecha: p.fecha,
    desempeno: PESO_DESEMPENO[p.estado],
    precision: p.precision,
    estado: p.estado,
    anomalo: false, // la señal real de "fuera de patrón" la da el backend (alertas)
  }));
}

interface DotProps {
  cx?: number;
  cy?: number;
  payload?: PuntoChart;
}

function PuntoDot({ cx, cy, payload }: DotProps) {
  if (cx == null || cy == null || !payload) return null;
  const anomalo = payload.anomalo;
  return (
    <g>
      {anomalo && <circle cx={cx} cy={cy} r={9} fill="none" stroke={colors.coral} strokeWidth={2} />}
      <circle
        cx={cx}
        cy={cy}
        r={anomalo ? 5 : 4}
        fill={anomalo ? colors.coralDark : colors.sage}
        stroke={colors.white}
        strokeWidth={1.5}
      />
    </g>
  );
}

interface TooltipProps {
  active?: boolean;
  payload?: Array<{ payload: PuntoChart }>;
}

function ChartTooltip({ active, payload }: TooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  const p = payload[0].payload;
  return (
    <div
      style={{
        background: colors.white,
        border: `1px solid ${p.anomalo ? colors.coral : colors.sand}`,
        borderRadius: 10,
        padding: "8px 12px",
        fontSize: 13,
        boxShadow: "0 8px 20px -10px rgba(43,58,50,0.4)",
      }}
    >
      <div style={{ fontWeight: 600 }}>{labelEstado(p.estado)}</div>
      <div style={{ color: colors.textFaint }} className="mono">
        {fmtFecha(p.fecha)}
      </div>
      {p.precision != null && (
        <div style={{ color: colors.textMuted, marginTop: 2 }}>
          Precisión: {fmtPorcentaje(p.precision)}
        </div>
      )}
      {p.anomalo && (
        <div style={{ color: colors.coralDark, marginTop: 2 }}>fuera de patrón</div>
      )}
    </div>
  );
}

export function EvolucionChart({ data }: { data: PuntoChart[] }) {
  if (data.length === 0) {
    return (
      <div style={{ color: colors.textFaint, fontSize: 14, padding: "24px 0" }}>
        Aún no hay actividades valoradas en este bloque para mostrar.
      </div>
    );
  }

  return (
    <div style={{ width: "100%", height: 260 }}>
      <ResponsiveContainer>
        <LineChart data={data} margin={{ top: 12, right: 16, bottom: 8, left: -8 }}>
          <CartesianGrid stroke={colors.card} vertical={false} />
          <ReferenceLine y={0.5} stroke={colors.sand} strokeDasharray="3 3" />
          <XAxis
            dataKey="fecha"
            // Etiqueta corta (sin año) y separación mínima entre marcas: con varias
            // sesiones el mismo día, Recharts descarta las que se solaparían en vez
            // de amontonarlas/cortarlas. El tooltip sigue mostrando la fecha entera.
            tickFormatter={(v: string) => fmtFecha(v).replace(/\s\d{4}$/, "")}
            tick={{ fill: colors.textFaint, fontSize: 11, fontFamily: fonts.mono }}
            stroke={colors.sand}
            minTickGap={28}
            interval="preserveStartEnd"
          />
          <YAxis
            domain={[0, 1]}
            tickFormatter={(v: number) => `${Math.round(v * 100)}%`}
            tick={{ fill: colors.textFaint, fontSize: 11, fontFamily: fonts.mono }}
            stroke={colors.sand}
            width={44}
          />
          <Tooltip content={<ChartTooltip />} />
          <Line
            type="monotone"
            dataKey="desempeno"
            stroke={colors.sage}
            strokeWidth={2.5}
            dot={<PuntoDot />}
            activeDot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
