/**
 * Tokens de diseño de Trazo.
 * Paleta y tipografía tomadas EXACTAMENTE de trazo-presentacion.html (:root)
 * para que el panel se sienta parte del mismo producto.
 */

// Paleta oficial "Aqua Green" (elegida por Saulo). Nombres conservados.
export const colors = {
  ivory: "#F5FBFA",
  card: "#E8F5F2",
  ink: "#12312E",
  sage: "#12A99B",
  sageDark: "#1F7A70",
  coral: "#F08A6B",
  coralDark: "#C4553A",
  // Coral profundo para texto/botones con texto blanco (contraste WCAG AA).
  coralDeep: "#A8431F",
  sand: "#D2E6E2",
  // Borde de CONTROL en reposo (inputs, selects): sand ~1.1:1 sobre blanco
  // fallaba WCAG 1.4.11 (control debe tener >=3:1). Mismo teal que la tablet.
  bordeControl: "#5F918A",
  white: "#FFFEFB",

  // Azul de acento (petición de Saulo para CTA/enlaces).
  azul: "#2C7595",
  azulDark: "#215A73",

  // Derivados usados en la presentación (texto secundario, fondos suaves).
  text: "#12312E",
  textMuted: "#5A716E",
  textFaint: "#4E635F",
  alertBg: "#FDEEE8",
  alertText: "#7A4A3A",
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
  soft: "0 20px 40px -18px rgba(18, 49, 46, 0.30)",
} as const;
