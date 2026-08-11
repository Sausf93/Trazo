/**
 * Gráfica temporal de precisión por sesión.
 * Los puntos que caen fuera del patrón propio de la persona se pintan en coral
 * (mismo criterio que el motor de alertas del backend), y no dependen solo del
 * color: se dibujan más grandes y con anillo.
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
import { marcarFueraDePatron } from "../utils/anomalia";
import { labelEstado } from "../api/vocab";

export interface PuntoChart {
  idx: number;
  fecha: string;
  precision: number;
  estado: string;
  anomalo: boolean;
}

export function construirSerie(puntos: PuntoEvolucion[]): PuntoChart[] {
  const conPrecision = puntos.filter(
    (p): p is PuntoEvolucion & { precision: number } => p.precision != null,
  );
  const flags = marcarFueraDePatron(conPrecision.map((p) => p.precision));
  return conPrecision.map((p, i) => ({
    idx: i,
    fecha: p.fecha,
    precision: p.precision,
    estado: p.estado,
    anomalo: flags[i],
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
      <div style={{ fontWeight: 600 }}>{fmtPorcentaje(p.precision)}</div>
      <div style={{ color: colors.textFaint }} className="mono">
        {fmtFecha(p.fecha)}
      </div>
      <div style={{ color: p.anomalo ? colors.coralDark : colors.textMuted, marginTop: 2 }}>
        {labelEstado(p.estado)}
        {p.anomalo ? " · fuera de patrón" : ""}
      </div>
    </div>
  );
}

export function EvolucionChart({ data }: { data: PuntoChart[] }) {
  if (data.length === 0) {
    return (
      <div style={{ color: colors.textFaint, fontSize: 14, padding: "24px 0" }}>
        No hay datos de precisión para mostrar en este bloque todavía.
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
            dataKey="precision"
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
