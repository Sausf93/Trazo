/**
 * Cola de revisión: intentos que la app no supo juzgar sola (respuesta oral,
 * trazo dudoso, actividad no autocorregible) y que quedan 'sin_valorar'. Mientras
 * no se revisen, NO cuentan en la evolución, las medias ni las alertas — por eso
 * es la pieza que cierra el bucle de medición. La integradora decide cómo fue,
 * viendo qué respondió la persona, y puede cambiar su decisión (deshacer).
 */
import { useState } from "react";
import { listarPendientes, marcarResultado } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { PendienteRevision } from "../api/types";
import { PageHeader, Spinner, StateMessage, Card } from "../components/ui";
import { useAsync } from "../hooks/useAsync";
import { labelBloque } from "../api/vocab";
import { colors, fonts, radius } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

type Resultado = "logrado" | "parcial" | "no_logrado";

// `color` = borde/fondo activo; `texto` = color del texto en reposo (con
// contraste AA). Para "A medias", el coral claro (#F08A6B) sobre blanco daba
// ~2.3:1 (falla AA); el texto usa coralDeep (ronda 3 QA).
const OPCIONES: { valor: Resultado; label: string; color: string; texto: string }[] = [
  { valor: "logrado", label: "Lo logró", color: colors.sageDark, texto: colors.sageDark },
  { valor: "parcial", label: "A medias", color: colors.coral, texto: colors.coralDeep },
  { valor: "no_logrado", label: "No lo logró", color: colors.coralDark, texto: colors.coralDark },
];

/** Resumen legible de QUÉ hizo la persona, para decidir con criterio (no a ciegas). */
function resumenRespuesta(p: PendienteRevision): string | null {
  const v = p.valores_json ?? {};
  const o = p.cantidad_objetivo_json ?? {};
  const s = (x: unknown) => (x == null ? "" : String(x));
  switch (p.plantilla_tipo) {
    case "seleccion_multiple":
      return v.eleccion != null
        ? `Eligió: ${s(v.eleccion)}${o.correcta != null ? ` · Correcta: ${s(o.correcta)}` : ""}`
        : null;
    case "trazo":
      return v.precision != null ? `Precisión del trazo: ${fmtPorcentaje(Number(v.precision))}` : null;
    case "manejo_cantidad":
      if (v.hora_elegida != null)
        return `Marcó las ${s(v.hora_elegida)}:${String(v.minuto_elegido ?? 0).padStart(2, "0")}` +
          (o.hora != null ? ` · Era ${s(o.hora)}:${String(o.minuto ?? 0).padStart(2, "0")}` : "");
      if (v.total_compuesto != null) return `Reunió: ${s(v.total_compuesto)} €`;
      return null;
    case "conteo_comparacion": {
      // La tablet emite la respuesta bajo la clave 'respuesta' (número, o
      // {grupo, objeto} en las comparaciones).
      const r = v.respuesta;
      if (r == null) return null;
      if (typeof r === "object") {
        const obj = r as Record<string, unknown>;
        return obj.objeto != null ? `Tocó: ${s(obj.objeto)}` : obj.grupo != null ? `Tocó el grupo ${s(obj.grupo)}` : null;
      }
      return `Respondió: ${s(r)}`;
    }
    case "memoria_visual":
    case "busqueda_visual":
      return v.aciertos != null ? `Aciertos: ${s(v.aciertos)}${v.fallos != null ? ` · Fallos: ${s(v.fallos)}` : ""}` : null;
    case "parejas":
      return v.pares_encontrados != null
        ? `Parejas: ${s(v.pares_encontrados)}${o.n_pares != null ? ` de ${s(o.n_pares)}` : ""}${v.errores != null ? ` · Errores: ${s(v.errores)}` : ""}`
        : null;
    default:
      return null;
  }
}

export function RevisarPage() {
  const pendientes = useAsync<PendienteRevision[]>((s) => listarPendientes({}, s), []);
  const [guardandoId, setGuardandoId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  // id -> resultado ya marcado (queda visible con opción a cambiarlo: red de
  // seguridad ante un toque por error, sin perder el "voy avanzando").
  const [marcados, setMarcados] = useState<Record<string, Resultado>>({});

  async function onMarcar(id: string, resultado: Resultado | "sin_valorar") {
    setError(null);
    setGuardandoId(id);
    try {
      await marcarResultado(id, resultado);
      setMarcados((prev) => {
        const next = { ...prev };
        if (resultado === "sin_valorar") delete next[id]; // vuelve a pendiente
        else next[id] = resultado;
        return next;
      });
      // Avisa al menú para que refresque el contador de "por revisar".
      window.dispatchEvent(new CustomEvent("trazo:pendientes-cambiaron"));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo guardar. Inténtalo de nuevo.");
    } finally {
      setGuardandoId(null);
    }
  }

  const lista = pendientes.data ?? [];
  const porRevisar = lista.filter((p) => !marcados[p.id]).length;

  return (
    <div>
      <PageHeader
        eyebrow="Bandeja"
        title="Por revisar"
        subtitle="Actividades que la app no pudo puntuar sola (una respuesta hablada, un trazo dudoso…). Hasta que las revises, no cuentan en la evolución ni en las alertas."
        actions={
          lista.length > 0 ? (
            <span className="mono" style={{ fontSize: 13, color: colors.textMuted }}>
              {porRevisar} sin revisar de {lista.length}
            </span>
          ) : undefined
        }
      />

      {error && (
        <div style={{ marginBottom: 16 }}>
          <StateMessage tone="error">{error}</StateMessage>
        </div>
      )}

      {pendientes.loading && <Spinner label="Buscando actividades por revisar…" />}
      {pendientes.error && (
        <StateMessage tone="error" title="No se pudo cargar la cola de revisión">
          {pendientes.error}
        </StateMessage>
      )}
      {pendientes.data && lista.length === 0 && (
        <StateMessage title="Todo revisado">
          No hay actividades pendientes de valorar. Cada medición está contando en la evolución.
        </StateMessage>
      )}

      {lista.length > 0 && (
        <div style={{ display: "grid", gap: 14 }}>
          {lista.map((p) => {
            const marcado = marcados[p.id];
            const resumen = resumenRespuesta(p);
            return (
              <Card
                key={p.id}
                style={{
                  display: "flex",
                  flexWrap: "wrap",
                  gap: 16,
                  alignItems: "center",
                  justifyContent: "space-between",
                  opacity: marcado ? 0.7 : 1,
                }}
              >
                <div style={{ minWidth: 240 }}>
                  <div style={{ fontFamily: fonts.serif, fontSize: 20 }}>{p.alias_interno}</div>
                  <div style={{ fontSize: 14.5, color: colors.ink, marginTop: 2 }}>{p.ejercicio}</div>
                  {resumen && (
                    <div style={{ fontSize: 13.5, color: colors.textMuted, marginTop: 3 }}>{resumen}</div>
                  )}
                  <div style={{ fontSize: 12.5, color: colors.textFaint, marginTop: 2 }}>
                    {labelBloque(p.bloque)} · {fmtFecha(p.cuando)}
                  </div>
                </div>
                <div style={{ display: "inline-flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
                  {marcado && (
                    <>
                      <span className="mono" style={{ fontSize: 11.5, color: colors.sageDark, marginRight: 4 }}>
                        ✓ guardado
                      </span>
                      <button
                        onClick={() => onMarcar(p.id, "sin_valorar")}
                        disabled={guardandoId === p.id}
                        title="Devolverlo a la cola para decidir más tarde"
                        style={{
                          padding: "10px 12px",
                          borderRadius: radius.sm,
                          border: `1.5px solid ${colors.sand}`,
                          background: "transparent",
                          color: colors.textMuted,
                          fontWeight: 600,
                          fontSize: 13,
                          cursor: "pointer",
                        }}
                      >
                        Dejar sin puntuar
                      </button>
                    </>
                  )}
                  {OPCIONES.map((o) => {
                    const activo = marcado === o.valor;
                    return (
                      <button
                        key={o.valor}
                        onClick={() => onMarcar(p.id, o.valor)}
                        disabled={guardandoId === p.id}
                        style={{
                          padding: "10px 16px",
                          borderRadius: radius.sm,
                          border: `1.5px solid ${o.color}`,
                          background: activo ? o.color : "transparent",
                          color: activo ? colors.white : o.texto,
                          fontWeight: 600,
                          fontSize: 14,
                          cursor: guardandoId === p.id ? "default" : "pointer",
                          opacity: guardandoId === p.id ? 0.5 : 1,
                        }}
                      >
                        {o.label}
                      </button>
                    );
                  })}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
