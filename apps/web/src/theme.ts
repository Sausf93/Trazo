/**
 * Tokens de diseño de Trazo.
 * Paleta y tipografía tomadas EXACTAMENTE de trazo-presentacion.html (:root)
 * para que el panel se sienta parte del mismo producto.
 */

export const colors = {
  ivory: "#FAF6EF",
  card: "#F2ECDF",
  ink: "#2B3A32",
  sage: "#7C9885",
  sageDark: "#5C7A66",
  coral: "#E8A87C",
  coralDark: "#C97B4A",
  sand: "#C9BFA4",
  white: "#FFFEFB",

  // Derivados usados en la presentación (texto secundario, fondos suaves).
  text: "#2B3A32",
  textMuted: "#4A5A50",
  textFaint: "#6E6752",
  alertBg: "#FBEFE4",
  alertText: "#6B5A48",
} as const;

export const fonts = {
  serif: "'Fraunces', Georgia, serif",
  sans: "'Inter', system-ui, sans-serif",
  mono: "'JetBrains Mono', ui-monospace, monospace",
} as const;

export const radius = {
  sm: "10px",
  md: "14px",
  lg: "18px",
} as const;

export const shadow = {
  soft: "0 20px 40px -18px rgba(43, 58, 50, 0.35)",
} as const;
