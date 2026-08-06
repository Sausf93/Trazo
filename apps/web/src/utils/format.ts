/** Utilidades de formato para el panel (fechas, porcentajes). */

const fFecha = new Intl.DateTimeFormat("es-ES", {
  day: "2-digit",
  month: "short",
  year: "numeric",
});

const fFechaHora = new Intl.DateTimeFormat("es-ES", {
  day: "2-digit",
  month: "short",
  hour: "2-digit",
  minute: "2-digit",
});

export function fmtFecha(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return fFecha.format(d);
}

export function fmtFechaHora(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return fFechaHora.format(d);
}

/** 0..1 -> "82 %". Devuelve "—" si es null. */
export function fmtPorcentaje(x: number | null | undefined, decimales = 0): string {
  if (x === null || x === undefined || Number.isNaN(x)) return "—";
  return `${(x * 100).toFixed(decimales)} %`;
}

/** Cuánto hace desde ahora, en texto corto ("hace 3 días"). */
export function haceCuanto(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  const seg = Math.floor((Date.now() - d.getTime()) / 1000);
  if (seg < 60) return "hace un momento";
  const min = Math.floor(seg / 60);
  if (min < 60) return `hace ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 24) return `hace ${h} h`;
  const dias = Math.floor(h / 24);
  if (dias < 7) return `hace ${dias} día${dias === 1 ? "" : "s"}`;
  const sem = Math.floor(dias / 7);
  return `hace ${sem} sem`;
}

export function fmtSegundos(s: number | null | undefined): string {
  if (s === null || s === undefined || Number.isNaN(s)) return "—";
  if (s < 60) return `${Math.round(s)} s`;
  const min = Math.floor(s / 60);
  const resto = Math.round(s % 60);
  return `${min} min ${resto} s`;
}
