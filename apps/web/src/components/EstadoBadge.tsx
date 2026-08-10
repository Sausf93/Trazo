/** Badge para el estado de un intento. No depende solo del color: añade símbolo. */
import { labelEstado } from "../api/vocab";
import { Badge } from "./ui";
import type { EstadoIntento } from "../api/types";

const SIMBOLO: Record<string, string> = {
  logrado: "●",
  parcial: "◐",
  no_logrado: "○",
  sin_valorar: "·",
};

const TONO: Record<string, "sage" | "coral" | "neutral"> = {
  logrado: "sage",
  parcial: "coral",
  no_logrado: "coral",
  sin_valorar: "neutral",
};

export function EstadoBadge({ estado }: { estado: EstadoIntento | string | null | undefined }) {
  const key = estado ?? "";
  return (
    <Badge tone={TONO[key] ?? "neutral"}>
      <span aria-hidden style={{ marginRight: 6 }}>{SIMBOLO[key] ?? "·"}</span>
      {labelEstado(estado)}
    </Badge>
  );
}
