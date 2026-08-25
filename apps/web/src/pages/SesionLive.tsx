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
import { cerrarSesion, listarSesiones, marcarAyuda, sesionLive } from "../api/endpoints";
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
          Cuando la tablet abra una sala (individual o en grupo), aparecerá aquí para seguirla en tiempo real.
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
  const [cerrando, setCerrando] = useState(false);
  // Override optimista del "con ayuda" por intento (hasta que el siguiente poll
  // lo confirme): así el toque se ve al instante sin esperar 4s.
  const [ayudaLocal, setAyudaLocal] = useState<Record<string, boolean>>({});
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  async function onAyuda(intentoId: string, actual: boolean) {
    const nuevo = !actual;
    setAyudaLocal((prev) => ({ ...prev, [intentoId]: nuevo }));
    try {
      await marcarAyuda(intentoId, nuevo);
    } catch {
      setAyudaLocal((prev) => ({ ...prev, [intentoId]: actual })); // revertir si falla
    }
  }

  async function cerrarSala() {
    if (cerrando) return;
    if (!window.confirm("¿Cerrar la sala? Se finalizará la sesión para todas las tablets. Los resultados quedan guardados.")) return;
    setCerrando(true);
    try {
      await cerrarSesion(sesionId);
      onSalir();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo cerrar la sala.");
      setCerrando(false);
    }
  }

  useEffect(() => {
    let cancelado = false;
    const controller = new AbortController();

    async function tick() {
      try {
        const data = await sesionLive(sesionId, controller.signal);
        if (cancelado) return;
        setLive(data);
        // Reconciliar el override optimista: en cuanto el servidor confirma el
        // mismo valor, se devuelve la autoridad al servidor (así un cambio hecho
        // desde otra facilitadora/tablet vuelve a verse y no queda "pegado").
        setAyudaLocal((prev) => {
          let cambio = false;
          const next = { ...prev };
          for (const f of data.fichas) {
            if (f.ultimo_intento_id && next[f.ultimo_intento_id] === f.ultimo_con_ayuda) {
              delete next[f.ultimo_intento_id];
              cambio = true;
            }
          }
          return cambio ? next : prev;
        });
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
              ? `${live.fichas.length} participante${live.fichas.length === 1 ? "" : "s"} · ${live.tipo === "grupo" ? "sesión en grupo" : "sesión individual"}`
              : undefined
          }
          actions={
            <div style={{ display: "inline-flex", alignItems: "center", gap: 16 }}>
              <span className="mono" style={{ fontSize: 12, color: colors.textFaint, display: "inline-flex", alignItems: "center", gap: 8 }}>
                <span aria-hidden style={{ width: 8, height: 8, borderRadius: "50%", background: colors.sage, display: "inline-block", animation: "trazo-pulse 1.6s ease-in-out infinite" }} />
                Actualizando cada {INTERVALO_MS / 1000}s
                <style>{`@keyframes trazo-pulse { 0%,100%{opacity:1} 50%{opacity:0.3} }`}</style>
              </span>
              <button
                onClick={cerrarSala}
                disabled={cerrando}
                style={{
                  padding: "8px 14px",
                  borderRadius: radius.sm,
                  border: `1.5px solid ${colors.coral}`,
                  background: "transparent",
                  color: colors.coralDark,
                  fontWeight: 600,
                  fontSize: 13.5,
                  cursor: cerrando ? "default" : "pointer",
                  opacity: cerrando ? 0.6 : 1,
                }}
              >
                {cerrando ? "Cerrando…" : "Cerrar sala"}
              </button>
            </div>
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
          {live.fichas.map((f) => {
            // El panel cuenta la misma historia que la tablet: quién terminó y
            // espera, por dónde va cada uno, su ronda y si se le ayudó.
            const borde = f.terminado ? colors.sage : f.atascado ? colors.coral : colors.sand;
            const enCurso = f.pos_actual > 0 && f.total_actual > 0;
            return (
              <div
                key={f.usuario_final_id}
                style={{
                  background: colors.white,
                  border: `${f.terminado || f.atascado ? 2 : 1}px solid ${borde}`,
                  borderRadius: radius.md,
                  padding: "18px 20px",
                }}
              >
                {f.terminado ? (
                  <div className="mono" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 11.5, color: colors.sageDark, marginBottom: 8 }}>
                    <span aria-hidden>✓</span>
                    Terminó · esperando a los demás
                  </div>
                ) : f.atascado ? (
                  <div className="mono" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 11.5, color: colors.coralDark, marginBottom: 8 }}>
                    <span aria-hidden>●</span>
                    Necesita ayuda · {fmtSegundos(f.segundos_desde_ultimo_intento)}
                  </div>
                ) : null}
                <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
                  <span style={{ fontFamily: fonts.serif, fontSize: 19 }}>{f.alias_interno}</span>
                  {f.ronda > 1 && (
                    <span className="mono" style={{ fontSize: 10.5, color: colors.sageDark, background: colors.ivory, border: `1px solid ${colors.sand}`, borderRadius: 6, padding: "1px 6px" }}>
                      Ronda {f.ronda}
                    </span>
                  )}
                </div>
                <div style={{ fontSize: 13, color: colors.textFaint, marginBottom: 14, minHeight: 18 }}>
                  {f.terminado
                    ? "Ha terminado su tanda"
                    : f.ejercicio_actual
                      ? `${f.ejercicio_actual}${enCurso ? ` · ${f.pos_actual} de ${f.total_actual}` : ""}`
                      : "Aún no ha empezado"}
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
                    {f.ultimo_estado ? <EstadoBadge estado={f.ultimo_estado} /> : <span style={{ fontSize: 13, color: colors.textFaint }}>—</span>}
                  </span>
                  <span className="mono" style={{ fontSize: 11.5, color: colors.textFaint }}>
                    {fmtSegundos(f.segundos_desde_ultimo_intento)}
                  </span>
                </div>
                {/* Marcar "le ayudé" en la última actividad, sin levantarse a la tablet. */}
                {f.ultimo_intento_id && (() => {
                  const conAyuda = ayudaLocal[f.ultimo_intento_id] ?? f.ultimo_con_ayuda;
                  return (
                    <button
                      onClick={() => onAyuda(f.ultimo_intento_id!, conAyuda)}
                      aria-pressed={conAyuda}
                      style={{
                        marginTop: 10,
                        width: "100%",
                        padding: "8px 10px",
                        borderRadius: radius.sm,
                        border: `1.5px solid ${conAyuda ? colors.sageDark : colors.sand}`,
                        background: conAyuda ? colors.sageDark : "transparent",
                        color: conAyuda ? colors.white : colors.textMuted,
                        fontWeight: 600,
                        fontSize: 13,
                        cursor: "pointer",
                      }}
                    >
                      {conAyuda ? "✓ Le ayudé" : "Le ayudé"}
                    </button>
                  );
                })()}
              </div>
            );
          })}
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
