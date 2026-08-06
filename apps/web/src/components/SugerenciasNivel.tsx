/**
 * Sugerencias de nivel: el sistema las calcula, el PROFESIONAL decide.
 * Nunca se aplican solas. Cada tarjeta ofrece "Aplicar", que hace el PATCH
 * de nivel de la línea del plan y refresca la lista (la sugerencia desaparece).
 *
 * "Subir" se muestra en sage (↑) y "bajar" en coral (↓), sin depender solo
 * del color: cada tarjeta lleva icono y texto explícito.
 */
import { useState } from "react";
import { aplicarNivelLinea, sugerenciasUsuario } from "../api/endpoints";
import type { SugerenciaNivel } from "../api/types";
import { labelBloque, labelNivel } from "../api/vocab";
import { useAsync } from "../hooks/useAsync";
import { colors, radius } from "../theme";
import { fmtPorcentaje } from "../utils/format";
import { Badge, Button, Spinner, StateMessage } from "./ui";

export function SugerenciasNivel({ usuarioId }: { usuarioId: string }) {
  const sugerencias = useAsync<SugerenciaNivel[]>(
    (s) => sugerenciasUsuario(usuarioId, s),
    [usuarioId],
  );

  // Estado por línea: cuál se está aplicando y su posible error.
  const [aplicandoId, setAplicandoId] = useState<string | null>(null);
  const [errorId, setErrorId] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  async function aplicar(s: SugerenciaNivel) {
    setAplicandoId(s.plan_linea_id);
    setErrorId(null);
    setErrorMsg(null);
    try {
      await aplicarNivelLinea(s.plan_linea_id, s.nivel_propuesto);
      // Al refrescar, el backend deja de sugerir el cambio ya aplicado.
      sugerencias.reload();
    } catch (err) {
      setErrorId(s.plan_linea_id);
      setErrorMsg(err instanceof Error ? err.message : "No se pudo aplicar el cambio.");
    } finally {
      setAplicandoId(null);
    }
  }

  return (
    <section aria-labelledby="sugerencias-nivel" style={{ marginBottom: 26 }}>
      <h2 id="sugerencias-nivel" style={{ fontSize: 19, marginBottom: 4 }}>
        Sugerencias de nivel
      </h2>
      <p style={{ fontSize: 14, color: colors.textMuted, marginBottom: 14, maxWidth: 620 }}>
        El sistema propone estos ajustes a partir del rendimiento reciente. Nunca se
        aplican solos: decides tú si aceptarlos.
      </p>

      {sugerencias.loading && <Spinner label="Buscando sugerencias…" />}

      {sugerencias.error && (
        <StateMessage tone="error" title="No se pudieron cargar las sugerencias">
          {sugerencias.error}
        </StateMessage>
      )}

      {sugerencias.data && sugerencias.data.length === 0 && (
        <StateMessage title="Sin cambios de nivel sugeridos">
          De momento el sistema no propone ajustar ningún nivel.
        </StateMessage>
      )}

      {sugerencias.data && sugerencias.data.length > 0 && (
        <div style={{ display: "grid", gap: 14 }}>
          {sugerencias.data.map((s) => (
            <SugerenciaCard
              key={s.plan_linea_id}
              sugerencia={s}
              aplicando={aplicandoId === s.plan_linea_id}
              error={errorId === s.plan_linea_id ? errorMsg : null}
              onAplicar={() => aplicar(s)}
            />
          ))}
        </div>
      )}
    </section>
  );
}

function SugerenciaCard({
  sugerencia: s,
  aplicando,
  error,
  onAplicar,
}: {
  sugerencia: SugerenciaNivel;
  aplicando: boolean;
  error: string | null;
  onAplicar: () => void;
}) {
  const subir = s.sugerencia === "subir";
  const acento = subir ? colors.sage : colors.coral;
  const acentoFuerte = subir ? colors.sageDark : colors.coralDark;
  const icono = subir ? "↑" : "↓";
  const accion = subir ? "Subir" : "Bajar";

  return (
    <article
      style={{
        background: colors.white,
        border: `1px solid ${acento}`,
        borderRadius: radius.md,
        padding: "18px 20px",
        display: "flex",
        gap: 14,
        alignItems: "flex-start",
      }}
    >
      <span
        aria-hidden
        style={{
          flexShrink: 0,
          width: 34,
          height: 34,
          borderRadius: "50%",
          background: subir ? "rgba(124,152,133,0.16)" : colors.alertBg,
          color: acentoFuerte,
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 20,
          fontWeight: 700,
          lineHeight: 1,
        }}
      >
        {icono}
      </span>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap", marginBottom: 6 }}>
          <Badge tone={subir ? "sage" : "coral"}>{accion} de nivel</Badge>
          <Badge tone="neutral">{labelBloque(s.bloque)}</Badge>
        </div>

        <h3 style={{ fontSize: 17, marginBottom: 4, color: acentoFuerte }}>
          {accion} de {labelNivel(s.nivel_actual)} a {labelNivel(s.nivel_propuesto)}
        </h3>
        <p style={{ fontSize: 14.5, color: colors.textMuted, marginBottom: 10 }}>{s.motivo}</p>

        <dl style={contextGridStyle}>
          <ContextItem label="Media reciente" value={fmtPorcentaje(s.media_reciente)} />
          <ContextItem label="Intentos considerados" value={String(s.n_intentos)} />
        </dl>

        {error && (
          <div style={{ marginTop: 12 }}>
            <StateMessage tone="error" title="No se pudo aplicar">
              {error}
            </StateMessage>
          </div>
        )}

        <div style={{ marginTop: 14, display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap" }}>
          <Button
            variant={subir ? "primary" : "coral"}
            disabled={aplicando}
            onClick={onAplicar}
          >
            {aplicando ? "Aplicando…" : `Aplicar (poner nivel ${labelNivel(s.nivel_propuesto)})`}
          </Button>
          <span style={{ fontSize: 12.5, color: colors.textFaint }}>
            Se aplica solo si lo confirmas.
          </span>
        </div>
      </div>
    </article>
  );
}

const contextGridStyle: React.CSSProperties = {
  display: "grid",
  gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))",
  gap: 10,
  margin: 0,
};

function ContextItem({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        background: colors.card,
        border: `1px solid ${colors.sand}`,
        borderRadius: radius.sm,
        padding: "8px 12px",
      }}
    >
      <dt style={{ fontSize: 11.5, color: colors.textFaint, marginBottom: 2 }}>{label}</dt>
      <dd style={{ fontSize: 17, fontWeight: 600, margin: 0, color: colors.ink }}>{value}</dd>
    </div>
  );
}
