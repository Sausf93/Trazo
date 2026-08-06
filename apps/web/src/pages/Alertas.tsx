/**
 * Bandeja de alertas del centro. Cada alerta muestra qué cambió y desde cuándo,
 * con un botón para marcarla revisada.
 */
import { useState } from "react";
import { listarAlertas, listarUsuarios, revisarAlerta } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Alerta, UsuarioFinal } from "../api/types";
import { AlertCard } from "../components/AlertCard";
import { PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, radius } from "../theme";

type Filtro = "pendientes" | "todas";

export function AlertasPage() {
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const [filtro, setFiltro] = useState<Filtro>("pendientes");
  const [revisandoId, setRevisandoId] = useState<string | null>(null);
  const [errorAccion, setErrorAccion] = useState<string | null>(null);

  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const alertas = useAsync<Alerta[]>(
    (s) =>
      listarAlertas(
        filtro === "pendientes" ? { centro_id: centroId, revisada: false } : { centro_id: centroId },
        s,
      ),
    [centroId, filtro],
  );

  const aliasPorId = new Map((usuarios.data ?? []).map((u) => [u.id, u.alias_interno]));

  async function onRevisar(alertaId: string, resultado: string) {
    setErrorAccion(null);
    setRevisandoId(alertaId);
    try {
      await revisarAlerta(alertaId, resultado);
      alertas.reload();
    } catch (err) {
      setErrorAccion(err instanceof ApiError ? err.message : "No se pudo marcar la alerta.");
    } finally {
      setRevisandoId(null);
    }
  }

  return (
    <div>
      <PageHeader
        eyebrow="Bandeja"
        title="Alertas"
        subtitle="Cambios que el sistema ha detectado en el patrón propio de cada persona. Compara siempre a cada quien consigo mismo, nunca con el resto."
        actions={
          <div style={{ display: "inline-flex", gap: 4, background: colors.card, padding: 4, borderRadius: radius.md }}>
            {(["pendientes", "todas"] as Filtro[]).map((f) => (
              <button
                key={f}
                onClick={() => setFiltro(f)}
                aria-pressed={filtro === f}
                style={{
                  padding: "8px 16px",
                  borderRadius: radius.sm,
                  border: "none",
                  fontWeight: 600,
                  fontSize: 14,
                  background: filtro === f ? colors.white : "transparent",
                  color: filtro === f ? colors.ink : colors.textMuted,
                  boxShadow: filtro === f ? "0 1px 3px rgba(43,58,50,0.12)" : "none",
                }}
              >
                {f === "pendientes" ? "Pendientes" : "Todas"}
              </button>
            ))}
          </div>
        }
      />

      {errorAccion && (
        <div style={{ marginBottom: 16 }}>
          <StateMessage tone="error">{errorAccion}</StateMessage>
        </div>
      )}

      {alertas.loading && <Spinner label="Cargando alertas…" />}
      {alertas.error && (
        <StateMessage tone="error" title="No se pudieron cargar las alertas">
          {alertas.error}
        </StateMessage>
      )}
      {alertas.data && alertas.data.length === 0 && (
        <StateMessage title={filtro === "pendientes" ? "Nada pendiente" : "Sin alertas"}>
          {filtro === "pendientes"
            ? "No hay alertas sin revisar ahora mismo."
            : "No se ha generado ninguna alerta en este centro."}
        </StateMessage>
      )}
      {alertas.data && alertas.data.length > 0 && (
        <div style={{ display: "grid", gap: 16 }}>
          {alertas.data.map((a) => (
            <AlertCard
              key={a.id}
              alerta={a}
              aliasLabel={aliasPorId.get(a.usuario_final_id)}
              onRevisar={onRevisar}
              revisando={revisandoId === a.id}
            />
          ))}
        </div>
      )}
    </div>
  );
}
