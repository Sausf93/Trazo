/**
 * Vista en vivo de una sesión (para la facilitadora).
 * Polling cada 4 s a GET /sesiones/{id}/live. Fichas por participante; se
 * resalta en coral quien lleva un rato "atascado".
 *
 * Como el contrato no expone un listado de sesiones, se introduce el id de la
 * sesión a mano (lo crea la tablet / la integradora al iniciar la actividad).
 */
import { useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { sesionLive } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Live } from "../api/types";
import { EstadoBadge } from "../components/EstadoBadge";
import { Button, Card, Field, PageHeader, Spinner, StateMessage, inputStyle } from "../components/ui";
import { colors, fonts, radius } from "../theme";
import { fmtSegundos } from "../utils/format";

const INTERVALO_MS = 4000;

export function SesionLivePage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [sesionInput, setSesionInput] = useState("");

  if (!id) {
    return (
      <div>
        <PageHeader
          eyebrow="En vivo"
          title="Sesión en directo"
          subtitle="Sigue una sesión en curso en tiempo real: qué hace cada persona y quién necesita ayuda."
        />
        <Card style={{ maxWidth: 480 }}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (sesionInput.trim()) navigate(`/sesion/${encodeURIComponent(sesionInput.trim())}`);
            }}
          >
            <Field label="Identificador de la sesión" htmlFor="sesion-id" hint="Lo genera la tablet al iniciar la actividad.">
              <input
                id="sesion-id"
                value={sesionInput}
                onChange={(e) => setSesionInput(e.target.value)}
                style={inputStyle}
                placeholder="p. ej. 3f2a…"
              />
            </Field>
            <Button type="submit" disabled={!sesionInput.trim()}>Ver en directo</Button>
          </form>
        </Card>
      </div>
    );
  }

  return <LiveMonitor sesionId={id} onSalir={() => navigate("/sesion")} />;
}

function LiveMonitor({ sesionId, onSalir }: { sesionId: string; onSalir: () => void }) {
  const [live, setLive] = useState<Live | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [ultimaAct, setUltimaAct] = useState<Date | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    let cancelado = false;
    const controller = new AbortController();

    async function tick() {
      try {
        const data = await sesionLive(sesionId, controller.signal);
        if (cancelado) return;
        setLive(data);
        setError(null);
        setUltimaAct(new Date());
      } catch (err) {
        if (cancelado || (err as Error)?.name === "AbortError") return;
        setError(err instanceof ApiError ? err.message : "No se pudo actualizar la sesión.");
      } finally {
        if (!cancelado) setLoading(false);
      }
    }

    tick();
    timer.current = setInterval(tick, INTERVALO_MS);
    return () => {
      cancelado = true;
      controller.abort();
      if (timer.current) clearInterval(timer.current);
    };
  }, [sesionId]);

  return (
    <div>
      <button onClick={onSalir} style={{ background: "none", border: "none", padding: 0, margin: 0, textAlign: "left", cursor: "pointer", color: colors.sageDark, fontSize: 14, fontWeight: 600 }}>
        ← Elegir otra sesión
      </button>

      <div style={{ marginTop: 10 }}>
        <PageHeader
          eyebrow="En vivo"
          title="Sesión en directo"
          subtitle={
            live
              ? `${live.fichas.length} participante${live.fichas.length === 1 ? "" : "s"} · sesión ${live.tipo}`
              : undefined
          }
          actions={
            <span className="mono" style={{ fontSize: 12, color: colors.textFaint, display: "inline-flex", alignItems: "center", gap: 8 }}>
              <span aria-hidden style={{ width: 8, height: 8, borderRadius: "50%", background: colors.sage, display: "inline-block", animation: "trazo-pulse 1.6s ease-in-out infinite" }} />
              Actualizando cada {INTERVALO_MS / 1000}s
              <style>{`@keyframes trazo-pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }`}</style>
            </span>
          }
        />
      </div>

      {loading && !live && <Spinner label="Conectando con la sesión…" />}
      {error && !live && (
        <StateMessage tone="error" title="No se pudo cargar la sesión">
          {error}
        </StateMessage>
      )}
      {error && live && (
        <div style={{ marginBottom: 14 }}>
          <StateMessage tone="error">Reintentando… ({error})</StateMessage>
        </div>
      )}

      {live && live.fichas.length === 0 && (
        <StateMessage title="Sesión sin participantes activos">
          Esta sesión no tiene participantes registrados todavía.
        </StateMessage>
      )}

      {live && live.fichas.length > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 16 }}>
          {live.fichas.map((f) => (
            <div
              key={f.usuario_final_id}
              style={{
                background: colors.white,
                border: `${f.atascado ? 2 : 1}px solid ${f.atascado ? colors.coral : colors.sand}`,
                borderRadius: radius.md,
                padding: "18px 20px",
              }}
            >
              {f.atascado && (
                <div className="mono" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 11.5, color: colors.coralDark, marginBottom: 8 }}>
                  <span aria-hidden>🔊</span>
                  Atascado {fmtSegundos(f.segundos_desde_ultimo_intento)}
                </div>
              )}
              <div style={{ fontFamily: fonts.serif, fontSize: 19, marginBottom: 4 }}>{f.alias_interno}</div>
              <div style={{ fontSize: 13, color: colors.textFaint, marginBottom: 14, minHeight: 18 }}>
                {f.ejercicio_actual ?? "Sin ejercicio en curso"}
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                {f.ultimo_estado ? <EstadoBadge estado={f.ultimo_estado} /> : <span style={{ fontSize: 13, color: colors.textFaint }}>—</span>}
                <span className="mono" style={{ fontSize: 11.5, color: colors.textFaint }}>
                  {fmtSegundos(f.segundos_desde_ultimo_intento)}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}

      {ultimaAct && (
        <p className="mono" style={{ fontSize: 11.5, color: colors.textFaint, marginTop: 20 }}>
          Última actualización: {ultimaAct.toLocaleTimeString("es-ES")}
        </p>
      )}
    </div>
  );
}
