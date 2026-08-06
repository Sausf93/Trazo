/** Badge para el estado de un intento. No depende solo del color: añade símbolo. */
import { labelEstado } from "../api/vocab";
import { Badge } from "./ui";
import type { EstadoIntento } from "../api/types";

const SIMBOLO: Record<string, string> = {
  solo: "●",
  con_ayuda: "◐",
  no_completado: "○",
};

const TONO: Record<string, "sage" | "coral" | "neutral"> = {
  solo: "sage",
  con_ayuda: "neutral",
  no_completado: "coral",
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
