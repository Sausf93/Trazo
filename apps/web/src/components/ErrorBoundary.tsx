/**
 * Límite de error de la aplicación. Si algo falla de forma inesperada durante
 * el render, muestra un mensaje amable en lugar de una pantalla en blanco.
 */
import { Component, type ErrorInfo, type ReactNode } from "react";
import { colors, radius } from "../theme";

type Props = { children: ReactNode };
type State = { hasError: boolean };

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    // Deja rastro en la consola para poder diagnosticar el fallo.
    console.error("Error no controlado en el panel:", error, info);
  }

  render(): ReactNode {
    if (!this.state.hasError) return this.props.children;

    return (
      <div
        role="alert"
        style={{
          minHeight: "100vh",
          display: "grid",
          placeItems: "center",
          padding: 24,
          background: colors.ivory,
        }}
      >
        <div
          style={{
            width: "100%",
            maxWidth: 420,
            textAlign: "center",
            background: colors.white,
            border: `1px solid ${colors.sand}`,
            borderRadius: radius.lg,
            padding: "30px 28px",
          }}
        >
          <h1 style={{ fontSize: 22, marginBottom: 8 }}>Ha ocurrido un error</h1>
          <p style={{ color: colors.textMuted, fontSize: 14.5, marginBottom: 20 }}>
            Ha ocurrido un error. Recarga la página para volver a intentarlo.
          </p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            style={{
              background: colors.sageDark,
              color: colors.white,
              border: `1.5px solid ${colors.sageDark}`,
              borderRadius: radius.sm,
              padding: "11px 20px",
              fontWeight: 600,
              fontSize: 15,
              cursor: "pointer",
            }}
          >
            Recargar la página
          </button>
        </div>
      </div>
    );
  }
}
