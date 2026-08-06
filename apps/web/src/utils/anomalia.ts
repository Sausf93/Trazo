/**
 * Detección de puntos "fuera del patrón" en el cliente, para resaltarlos en la
 * gráfica de evolución. Es un reflejo fiel del motor del backend
 * (app/services/anomalias.detectar_desviacion) para que el panel marque en
 * coral exactamente los mismos puntos que dispararían una alerta.
 *
 * Regla: la media de la ventana reciente cae por debajo de
 * (media_baseline - k*std_baseline) y además al menos `caida_minima` por debajo
 * de la media baseline. Cuando eso ocurre, los últimos `ventana_reciente`
 * puntos se consideran anómalos.
 */

interface Opciones {
  ventanaReciente?: number;
  minBaseline?: number;
  k?: number;
  caidaMinima?: number;
}

function media(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

/** Desviación estándar poblacional (como statistics.pstdev de Python). */
function pstdev(xs: number[]): number {
  if (xs.length <= 1) return 0;
  const m = media(xs);
  const varianza = xs.reduce((a, b) => a + (b - m) ** 2, 0) / xs.length;
  return Math.sqrt(varianza);
}

/**
 * Devuelve un array de booleanos (uno por punto) indicando si cae fuera del
 * patrón. `serie` va de más antiguo a más reciente.
 */
export function marcarFueraDePatron(
  serie: number[],
  opts: Opciones = {},
): boolean[] {
  const ventanaReciente = opts.ventanaReciente ?? 2;
  const minBaseline = opts.minBaseline ?? 4;
  const k = opts.k ?? 1.5;
  const caidaMinima = opts.caidaMinima ?? 0.08;

  const flags = new Array(serie.length).fill(false);
  if (serie.length < minBaseline + ventanaReciente) return flags;

  const baseline = serie.slice(0, serie.length - ventanaReciente);
  const reciente = serie.slice(serie.length - ventanaReciente);

  const mediaBase = media(baseline);
  const stdBase = pstdev(baseline);
  const mediaRec = media(reciente);
  const umbral = mediaBase - k * stdBase;

  const hay = mediaRec < umbral && mediaBase - mediaRec >= caidaMinima;
  if (hay) {
    for (let i = serie.length - ventanaReciente; i < serie.length; i++) {
      flags[i] = true;
    }
  }
  return flags;
}
