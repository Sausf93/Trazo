/**
 * Vista en vivo de una sesión (para la facilitadora).
 * Polling cada 4 s a GET /sesiones/{id}/live. Fichas por participante; se
 * resalta en coral quien lleva un rato "atascado".
 *
 * Sin id en la ruta se muestra la LISTA de sesiones abiertas del centro
 * (GET /sesiones?estado=abierta&centro_id=…); al elegir una se abre su monitor.
 */
import { useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { listarSesiones, sesionLive } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Live, SesionListItem } from "../api/types";
import { EstadoBadge } from "../components/EstadoBadge";
import { PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";
import { fmtFecha, fmtSegundos } from "../utils/format";

const INTERVALO_MS = 4000;

export function SesionLivePage() {
  const { id } = useParams();
  const navigate = useNavigate();

  if (!id) {
    return <SelectorSesionesAbiertas />;
  }

  return <LiveMonitor sesionId={id} onSalir={() => navigate("/sesion")} />;
}

function SelectorSesionesAbiertas() {
  const navigate = useNavigate();
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const sesiones = useAsync<SesionListItem[]>(
    (s) => listarSesiones({ centro_id: centroId, estado: "abierta" }, s),
    [centroId],
  );

  return (
    <div>
      <PageHeader
        eyebrow="En vivo"
        title="Sesión en directo"
        subtitle="Sigue una sesión en curso en tiempo real: qué hace cada persona y quién necesita ayuda."
      />

      {sesiones.loading && <Spinner label="Buscando sesiones abiertas…" />}
      {sesiones.error && (
        <StateMessage tone="error" title="No se pudieron cargar las sesiones">
          {sesiones.error}
        </StateMessage>
      )}
      {sesiones.data && sesiones.data.length === 0 && (
        <StateMessage title="No hay ninguna sesión en directo">
          Cuando la tablet inicie una actividad en grupo, aparecerá aquí para seguirla en tiempo real.
        </StateMessage>
      )}
      {sesiones.data && sesiones.data.length > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(260px, 1fr))", gap: 16 }}>
          {sesiones.data.map((s) => {
            const n = s.n_participantes;
            return (
              <button
                key={s.id}
                onClick={() => navigate(`/sesion/${encodeURIComponent(s.id)}`)}
                style={{
                  textAlign: "left",
                  cursor: "pointer",
                  background: colors.white,
                  border: `1px solid ${colors.sand}`,
                  borderRadius: radius.md,
                  padding: "18px 20px",
                  display: "flex",
                  flexDirection: "column",
                  gap: 10,
                }}
              >
                <span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                  <span aria-hidden style={{ width: 8, height: 8, borderRadius: "50%", background: colors.sage, display: "inline-block", animation: "trazo-pulse 1.6s ease-in-out infinite" }} />
                  <span className="mono" style={{ fontSize: 11.5, color: colors.sageDark, fontWeight: 600 }}>En directo</span>
                  <style>{`@keyframes trazo-pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }`}</style>
                </span>
                <span style={{ fontFamily: fonts.serif, fontSize: 21 }}>{s.nombre}</span>
                <span style={{ fontSize: 13, color: colors.textFaint }}>
                  {n} participante{n === 1 ? "" : "s"} · {fmtFecha(s.fecha)}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
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
