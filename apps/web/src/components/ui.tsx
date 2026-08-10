/** Piezas de UI reutilizables, alineadas con la paleta de Trazo. */
import type { ButtonHTMLAttributes, CSSProperties, ReactNode } from "react";
import { colors, fonts, radius } from "../theme";

export function Card({
  children,
  style,
  as: Tag = "div",
}: {
  children: ReactNode;
  style?: CSSProperties;
  as?: "div" | "section" | "article";
}) {
  return (
    <Tag
      style={{
        background: colors.white,
        border: `1px solid ${colors.sand}`,
        borderRadius: radius.md,
        padding: "22px 24px",
        ...style,
      }}
    >
      {children}
    </Tag>
  );
}

export function SectionLabel({ children }: { children: ReactNode }) {
  return <div className="eyebrow" style={{ marginBottom: 8 }}>{children}</div>;
}

export function PageHeader({
  eyebrow,
  title,
  subtitle,
  actions,
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <header
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "flex-end",
        gap: 16,
        flexWrap: "wrap",
        marginBottom: 24,
      }}
    >
      <div>
        {eyebrow && <SectionLabel>{eyebrow}</SectionLabel>}
        <h1 style={{ fontSize: "clamp(28px, 4vw, 38px)" }}>{title}</h1>
        {subtitle && (
          <p style={{ color: colors.textMuted, marginTop: 6, maxWidth: 620 }}>{subtitle}</p>
        )}
      </div>
      {actions && <div>{actions}</div>}
    </header>
  );
}

type Variant = "primary" | "ghost" | "coral";

export function Button({
  variant = "primary",
  children,
  style,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  const base: CSSProperties = {
    fontFamily: fonts.sans,
    fontWeight: 600,
    fontSize: 15,
    padding: "11px 20px",
    borderRadius: radius.sm,
    border: "1.5px solid transparent",
    transition: "filter 120ms ease, background 120ms ease",
  };
  const variants: Record<Variant, CSSProperties> = {
    primary: { background: colors.sageDark, color: colors.white, borderColor: colors.sageDark },
    coral: { background: colors.coralDeep, color: colors.white, borderColor: colors.coralDeep },
    ghost: { background: "transparent", color: colors.ink, borderColor: colors.sand },
  };
  const disabledStyle: CSSProperties = rest.disabled
    ? { opacity: 0.55, cursor: "not-allowed" }
    : {};
  return (
    <button {...rest} style={{ ...base, ...variants[variant], ...disabledStyle, ...style }}>
      {children}
    </button>
  );
}

export function Field({
  label,
  htmlFor,
  children,
  hint,
}: {
  label: string;
  htmlFor?: string;
  children: ReactNode;
  hint?: string;
}) {
  return (
    <label htmlFor={htmlFor} style={{ display: "block", marginBottom: 16 }}>
      <span
        style={{
          display: "block",
          fontSize: 14,
          fontWeight: 600,
          color: colors.textMuted,
          marginBottom: 6,
        }}
      >
        {label}
      </span>
      {children}
      {hint && (
        <span style={{ display: "block", fontSize: 12.5, color: colors.textFaint, marginTop: 4 }}>
          {hint}
        </span>
      )}
    </label>
  );
}

export const inputStyle: CSSProperties = {
  width: "100%",
  padding: "11px 13px",
  borderRadius: radius.sm,
  border: `1.5px solid ${colors.sand}`,
  background: colors.white,
  color: colors.ink,
};

export function Spinner({ label = "Cargando…" }: { label?: string }) {
  return (
    <div
      role="status"
      aria-live="polite"
      style={{ display: "flex", alignItems: "center", gap: 10, color: colors.textMuted, padding: "20px 0" }}
    >
      <span
        aria-hidden
        style={{
          width: 16,
          height: 16,
          borderRadius: "50%",
          border: `2.5px solid ${colors.sand}`,
          borderTopColor: colors.sageDark,
          display: "inline-block",
          animation: "trazo-spin 0.8s linear infinite",
        }}
      />
      {label}
      <style>{`@keyframes trazo-spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

export function StateMessage({
  tone = "neutral",
  title,
  children,
}: {
  tone?: "neutral" | "error";
  title?: string;
  children?: ReactNode;
}) {
  const isError = tone === "error";
  return (
    <div
      role={isError ? "alert" : undefined}
      style={{
        background: isError ? colors.alertBg : colors.card,
        border: `1px solid ${isError ? colors.coral : colors.sand}`,
        borderRadius: radius.md,
        padding: "16px 18px",
        color: isError ? colors.alertText : colors.textMuted,
      }}
    >
      {title && <strong style={{ display: "block", marginBottom: 4, color: colors.ink }}>{title}</strong>}
      {children}
    </div>
  );
}

export function Badge({
  children,
  tone = "sage",
}: {
  children: ReactNode;
  tone?: "sage" | "coral" | "neutral";
}) {
  const tones = {
    sage: { bg: "rgba(124,152,133,0.16)", fg: colors.sageDark, br: "rgba(124,152,133,0.4)" },
    coral: { bg: colors.alertBg, fg: colors.coralDark, br: colors.coral },
    neutral: { bg: colors.card, fg: colors.textMuted, br: colors.sand },
  }[tone];
  return (
    <span
      style={{
        display: "inline-block",
        fontSize: 12.5,
        fontWeight: 600,
        padding: "3px 10px",
        borderRadius: 999,
        background: tones.bg,
        color: tones.fg,
        border: `1px solid ${tones.br}`,
        whiteSpace: "nowrap",
      }}
    >
      {children}
    </span>
  );
}
