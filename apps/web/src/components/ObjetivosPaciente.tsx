/**
 * Objetivos/metas clínicas por persona: la integradora fija un desempeño objetivo
 * por área y el panel muestra 'objetivo vs situación actual'. Convierte Trazo en
 * un plan de intervención medible (diferenciador frente a un catálogo).
 */
import { useState } from "react";
import { borrarObjetivo, crearObjetivo, editarObjetivo, listarObjetivos } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Objetivo } from "../api/types";
import { BLOQUES, labelBloque } from "../api/vocab";
import { useAsync } from "../hooks/useAsync";
import { Card, Spinner, StateMessage } from "./ui";
import { colors, fonts, radius } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

export function ObjetivosPaciente({ usuarioId }: { usuarioId: string }) {
  const objetivos = useAsync<Objetivo[]>((s) => listarObjetivos(usuarioId, s), [usuarioId]);
  const [error, setError] = useState<string | null>(null);
  const [creando, setCreando] = useState(false);
  const [bloque, setBloque] = useState<string>(BLOQUES[0] ?? "");
  const [descripcion, setDescripcion] = useState("");
  const [objetivo, setObjetivo] = useState(70); // porcentaje

  async function onCrear(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setCreando(true);
    try {
      await crearObjetivo(usuarioId, {
        bloque,
        descripcion: descripcion.trim() || null,
        objetivo_desempeno: objetivo / 100,
      });
      setDescripcion("");
      objetivos.reload();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo crear el objetivo.");
    } finally {
      setCreando(false);
    }
  }

  async function onBorrar(id: string) {
    // Un toque accidental en la × borraba una meta clínica sin aviso; se confirma
    // como el resto de acciones destructivas del panel.
    if (!window.confirm("¿Quitar este objetivo de intervención?")) return;
    setError(null);
    try {
      await borrarObjetivo(id);
      objetivos.reload();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo borrar el objetivo.");
    }
  }

  return (
    <section aria-labelledby="objetivos-h" style={{ marginTop: 28 }}>
      <h2 id="objetivos-h" style={{ fontSize: 20, marginBottom: 6 }}>Objetivos de intervención</h2>
      <p style={{ color: colors.textMuted, fontSize: 14, marginBottom: 14 }}>
        Metas por área para esta persona. El panel compara el objetivo con su situación actual
        (media de desempeño, sin contar lo que está por revisar).
      </p>

      {error && <div style={{ marginBottom: 12 }}><StateMessage tone="error">{error}</StateMessage></div>}
      {objetivos.loading && <Spinner label="Cargando objetivos…" />}

      {objetivos.data && objetivos.data.length > 0 && (
        <div style={{ display: "grid", gap: 12, marginBottom: 18 }}>
          {objetivos.data.map((o) => (
            <TarjetaObjetivo
              key={o.id}
              objetivo={o}
              onBorrar={() => onBorrar(o.id)}
              onGuardado={() => objetivos.reload()}
              onError={setError}
            />
          ))}
        </div>
      )}
      {objetivos.data && objetivos.data.length === 0 && (
        <div style={{ marginBottom: 16 }}>
          <StateMessage title="Sin objetivos todavía">
            Fija una meta por área para seguir el progreso frente a un objetivo concreto.
          </StateMessage>
        </div>
      )}

      <Card style={{ padding: "16px 18px" }}>
        <form onSubmit={onCrear} style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4 }}>
            Área
            <select value={bloque} onChange={(e) => setBloque(e.target.value)}
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }}>
              {BLOQUES.map((b) => <option key={b} value={b}>{labelBloque(b)}</option>)}
            </select>
          </label>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4, flex: "1 1 220px" }}>
            Meta (texto libre, opcional)
            <input value={descripcion} onChange={(e) => setDescripcion(e.target.value)}
              placeholder="p. ej. mantener el cálculo, recuperar participación"
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }} />
          </label>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4 }}>
            Desempeño objetivo: {objetivo}%
            <input type="range" min={10} max={100} step={5} value={objetivo}
              onChange={(e) => setObjetivo(Number(e.target.value))} style={{ width: 160 }} />
          </label>
          <button type="submit" disabled={creando}
            style={{
              padding: "10px 18px", borderRadius: radius.sm, border: `1.5px solid ${colors.sageDark}`,
              background: colors.sageDark, color: colors.white, fontWeight: 600, fontSize: 14,
              cursor: creando ? "default" : "pointer", opacity: creando ? 0.6 : 1,
            }}>
            {creando ? "Añadiendo…" : "Añadir objetivo"}
          </button>
        </form>
      </Card>
    </section>
  );
}

function TarjetaObjetivo({
  objetivo: o,
  onBorrar,
  onGuardado,
  onError,
}: {
  objetivo: Objetivo;
  onBorrar: () => void;
  onGuardado: () => void;
  onError: (m: string | null) => void;
}) {
  const [editando, setEditando] = useState(false);
  const [desc, setDesc] = useState(o.descripcion ?? "");
  const [meta, setMeta] = useState(Math.round(o.objetivo_desempeno * 100));
  const [ocupado, setOcupado] = useState(false);

  async function guardar() {
    setOcupado(true);
    onError(null);
    try {
      await editarObjetivo(o.id, { descripcion: desc.trim() || null, objetivo_desempeno: meta / 100 });
      setEditando(false);
      onGuardado();
    } catch (err) {
      onError(err instanceof ApiError ? err.message : "No se pudo guardar el objetivo.");
    } finally {
      setOcupado(false);
    }
  }

  return (
    <Card style={{ padding: "16px 18px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12, flexWrap: "wrap" }}>
        <div style={{ fontFamily: fonts.serif, fontSize: 17 }}>{labelBloque(o.bloque)}</div>
        <div style={{ display: "inline-flex", gap: 10, alignItems: "center" }}>
          <button onClick={() => setEditando((v) => !v)}
            style={{ background: "none", border: "none", color: colors.sageDark, cursor: "pointer", fontSize: 13, fontWeight: 600 }}>
            {editando ? "Cancelar" : "Editar"}
          </button>
          <button onClick={onBorrar} aria-label="Quitar objetivo"
            style={{ background: "none", border: "none", color: colors.textFaint, cursor: "pointer", fontSize: 18 }}>
            ×
          </button>
        </div>
      </div>

      {editando ? (
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end", marginTop: 10 }}>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4, flex: "1 1 220px" }}>
            Meta (texto)
            <input value={desc} onChange={(e) => setDesc(e.target.value)}
              style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }} />
          </label>
          <label style={{ fontSize: 13, color: colors.textMuted, display: "flex", flexDirection: "column", gap: 4 }}>
            Desempeño objetivo: {meta}%
            <input type="range" min={10} max={100} step={5} value={meta}
              onChange={(e) => setMeta(Number(e.target.value))} style={{ width: 160 }} />
          </label>
          <button onClick={guardar} disabled={ocupado}
            style={{ padding: "9px 16px", borderRadius: radius.sm, border: `1.5px solid ${colors.sageDark}`,
              background: colors.sageDark, color: colors.white, fontWeight: 600, fontSize: 14, cursor: ocupado ? "default" : "pointer" }}>
            {ocupado ? "Guardando…" : "Guardar"}
          </button>
        </div>
      ) : (
        <>
          {o.descripcion && <div style={{ fontSize: 14, color: colors.ink, marginTop: 2 }}>{o.descripcion}</div>}
          <BarraObjetivo objetivo={o.objetivo_desempeno} actual={o.situacion_actual} />
          <div style={{ fontSize: 12.5, marginTop: 6, color: colors.textMuted }}>
            Objetivo: <strong>{fmtPorcentaje(o.objetivo_desempeno)}</strong> ·{" "}
            {o.situacion_actual == null ? (
              <span>aún sin datos valorados en esta área</span>
            ) : (
              <span style={{ color: o.cumple ? colors.sageDark : colors.coralDark, fontWeight: 600 }}>
                va por {fmtPorcentaje(o.situacion_actual)} ({o.n_valorados} valoradas)
                {o.cumple ? " · lo cumple" : " · por debajo"}
              </span>
            )}
          </div>
          <div style={{ fontSize: 11.5, color: colors.textFaint, marginTop: 4 }}>
            Fijado el {fmtFecha(o.creado_en)}
          </div>
        </>
      )}
    </Card>
  );
}

function BarraObjetivo({ objetivo, actual }: { objetivo: number; actual: number | null }) {
  const pct = actual == null ? 0 : Math.round(actual * 100);
  const meta = Math.round(objetivo * 100);
  const cumple = actual != null && actual >= objetivo;
  return (
    <div style={{ position: "relative", height: 14, background: colors.card, borderRadius: 999, marginTop: 10 }}>
      <div
        style={{
          width: `${pct}%`,
          height: "100%",
          background: cumple ? colors.sage : colors.coral,
          borderRadius: 999,
          transition: "width .3s",
        }}
      />
      {/* Marca del objetivo */}
      <div
        aria-hidden
        title={`Objetivo: ${meta}%`}
        style={{
          position: "absolute",
          left: `${meta}%`,
          top: -3,
          width: 2,
          height: 20,
          background: colors.ink,
        }}
      />
    </div>
  );
}
