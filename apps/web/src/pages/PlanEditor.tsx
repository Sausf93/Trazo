/**
 * Editor del plan de trabajo de una persona.
 *  - Carga las líneas actuales (GET /usuarios/{id}/plan).
 *  - Permite añadir / quitar / reordenar líneas de tipo dominio o ejercicio.
 *  - Guarda reemplazando TODO el plan (PUT /usuarios/{id}/plan).
 *  - Vista previa opcional de la cola resultante (GET /usuarios/{id}/cola).
 */
import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  guardarPlan,
  listarEjercicios,
  listarUsuarios,
  obtenerCola,
  obtenerPlan,
} from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Cola, Ejercicio, PlanLinea, TipoLinea, UsuarioFinal } from "../api/types";
import {
  BLOQUES,
  NIVELES,
  labelBloque,
  labelNivel,
  labelPlantilla,
  TIPO_LINEA_LABEL,
} from "../api/vocab";
import { Badge, Button, Card, PageHeader, Spinner, StateMessage, inputStyle } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";

/** Línea con clave estable para el renderizado (no se envía a la API). */
type EditLinea = PlanLinea & { _key: string };

let keySeq = 0;
function nextKey(): string {
  keySeq += 1;
  return `l${keySeq}`;
}

function nuevaLinea(tipo: TipoLinea, ejercicioId: string | null): EditLinea {
  return {
    _key: nextKey(),
    tipo,
    bloque: tipo === "dominio" ? BLOQUES[0] : null,
    ejercicio_id: tipo === "ejercicio" ? ejercicioId : null,
    nivel: "bajo",
    n_por_sesion: 2,
    orden: 0,
    activo: true,
  };
}

export function PlanEditorPage() {
  const { id = "" } = useParams();
  const { session } = useAuth();
  const centroId = session!.centro_id;

  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const ejercicios = useAsync<Ejercicio[]>((s) => listarEjercicios({ activo: true }, s), []);
  const plan = useAsync<PlanLinea[]>((s) => obtenerPlan(id, s), [id]);

  const alias = usuarios.data?.find((u) => u.id === id)?.alias_interno ?? id;
  const ejercicioList = ejercicios.data ?? [];

  const [lineas, setLineas] = useState<EditLinea[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [guardando, setGuardando] = useState(false);

  // Sincroniza el estado editable cuando llega el plan del servidor.
  useEffect(() => {
    if (plan.data) {
      setLineas(plan.data.map((l) => ({ ...l, _key: nextKey() })));
    }
  }, [plan.data]);

  // ¿Hay cambios sin guardar? (compara el estado editado con el plan persistido,
  // ignorando la clave interna _key). Se usa para avisar antes de perder el
  // trabajo clínico al recargar/cerrar (hallazgo de auditoría de operación).
  const hayCambiosSinGuardar =
    plan.data != null &&
    JSON.stringify(lineas.map(({ _key, ...r }) => r)) !== JSON.stringify(plan.data);
  useEffect(() => {
    if (!hayCambiosSinGuardar) return;
    const avisar = (e: BeforeUnloadEvent) => {
      e.preventDefault();
      e.returnValue = "";
    };
    window.addEventListener("beforeunload", avisar);
    return () => window.removeEventListener("beforeunload", avisar);
  }, [hayCambiosSinGuardar]);

  function actualizar(key: string, cambios: Partial<EditLinea>) {
    setLineas((prev) => prev.map((l) => (l._key === key ? { ...l, ...cambios } : l)));
    setOk(false);
  }

  function quitar(key: string) {
    setLineas((prev) => prev.filter((l) => l._key !== key));
    setOk(false);
  }

  function mover(index: number, delta: number) {
    setLineas((prev) => {
      const next = [...prev];
      const destino = index + delta;
      if (destino < 0 || destino >= next.length) return prev;
      [next[index], next[destino]] = [next[destino], next[index]];
      return next;
    });
    setOk(false);
  }

  function anadir(tipo: TipoLinea) {
    setLineas((prev) => [...prev, nuevaLinea(tipo, ejercicioList[0]?.id ?? null)]);
    setOk(false);
  }

  async function guardar() {
    setError(null);
    setOk(false);
    // Validación mínima antes de enviar.
    for (const l of lineas) {
      if (l.tipo === "dominio" && !l.bloque) {
        setError("Cada área necesita que elijas cuál.");
        return;
      }
      if (l.tipo === "ejercicio" && !l.ejercicio_id) {
        setError("Cada actividad concreta necesita que elijas cuál.");
        return;
      }
    }
    // Normaliza orden según la posición y descarta la clave interna.
    const payload: PlanLinea[] = lineas.map((l, i) => ({
      tipo: l.tipo,
      bloque: l.tipo === "dominio" ? l.bloque : null,
      ejercicio_id: l.tipo === "ejercicio" ? l.ejercicio_id : null,
      nivel: l.nivel,
      n_por_sesion: l.n_por_sesion,
      orden: i,
      activo: l.activo,
    }));
    setGuardando(true);
    try {
      await guardarPlan(id, payload);
      setOk(true);
      plan.reload();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo guardar el plan.");
    } finally {
      setGuardando(false);
    }
  }

  const cargandoDatos = plan.loading || ejercicios.loading;

  return (
    <div>
      <Link
        to={`/usuarios/${id}`}
        onClick={(e) => {
          if (hayCambiosSinGuardar && !window.confirm("Hay cambios sin guardar en el plan. ¿Salir sin guardarlos?")) {
            e.preventDefault();
          }
        }}
        style={{ color: colors.sageDark, fontSize: 14, fontWeight: 600, textDecoration: "none" }}
      >
        ← Volver a la ficha
      </Link>

      <div style={{ marginTop: 10 }}>
        <PageHeader
          eyebrow="Plan de trabajo"
          title={alias}
          subtitle="Elige en qué trabaja esta persona. Puedes trabajar un área entera (el sistema elige las actividades y las va variando) o elegir tú una actividad concreta. «Cuántas por sesión» es lo que hace cada día."
        />
      </div>

      {cargandoDatos && <Spinner label="Cargando plan…" />}
      {plan.error && (
        <StateMessage tone="error" title="No se pudo cargar el plan">
          {plan.error}
        </StateMessage>
      )}
      {ejercicios.error && (
        <StateMessage tone="error" title="No se pudo cargar el catálogo de ejercicios">
          {ejercicios.error}
        </StateMessage>
      )}

      {!cargandoDatos && !plan.error && (
        <>
          <Card style={{ marginBottom: 22 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", flexWrap: "wrap", gap: 10, marginBottom: 16 }}>
              <h2 style={{ fontSize: 19 }}>Qué trabaja en cada sesión</h2>
              <span className="mono" style={{ fontSize: 12.5, color: colors.textFaint }}>
                {lineas.length} en el plan
              </span>
            </div>

            {lineas.length === 0 && (
              <StateMessage title="Plan vacío">
                Añade un área para trabajar, o elige actividades concretas para esta persona.
              </StateMessage>
            )}

            {lineas.length > 0 && (
              <div style={{ display: "grid", gap: 14 }}>
                {lineas.map((l, i) => (
                  <LineaEditor
                    key={l._key}
                    linea={l}
                    index={i}
                    total={lineas.length}
                    ejercicios={ejercicioList}
                    onChange={(c) => actualizar(l._key, c)}
                    onRemove={() => quitar(l._key)}
                    onMove={(d) => mover(i, d)}
                  />
                ))}
              </div>
            )}

            <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginTop: 18 }}>
              <Button variant="ghost" onClick={() => anadir("dominio")}>
                + Trabajar un área
              </Button>
              <Button
                variant="ghost"
                onClick={() => anadir("ejercicio")}
                disabled={ejercicioList.length === 0}
              >
                + Elegir una actividad
              </Button>
            </div>
            {ejercicioList.length === 0 && (
              <p style={{ fontSize: 12.5, color: colors.textFaint, marginTop: 8 }}>
                Aún no hay actividades en el catálogo; de momento solo puedes trabajar por áreas.
              </p>
            )}

            {error && (
              <div role="alert" style={{ background: colors.alertBg, border: `1px solid ${colors.coral}`, color: colors.coralDark, borderRadius: radius.sm, padding: "10px 12px", fontSize: 14, marginTop: 16 }}>
                {error}
              </div>
            )}
            {ok && (
              <div role="status" aria-live="polite" style={{ background: "rgba(124,152,133,0.16)", border: `1px solid ${colors.sage}`, color: colors.sageDark, borderRadius: radius.sm, padding: "10px 12px", fontSize: 14, marginTop: 16 }}>
                Plan guardado correctamente.
              </div>
            )}

            <div style={{ marginTop: 18 }}>
              <Button onClick={guardar} disabled={guardando}>
                {guardando ? "Guardando…" : "Guardar plan"}
              </Button>
            </div>
          </Card>

          <ColaPreview usuarioId={id} />
        </>
      )}
    </div>
  );
}

function LineaEditor({
  linea,
  index,
  total,
  ejercicios,
  onChange,
  onRemove,
  onMove,
}: {
  linea: EditLinea;
  index: number;
  total: number;
  ejercicios: Ejercicio[];
  onChange: (cambios: Partial<EditLinea>) => void;
  onRemove: () => void;
  onMove: (delta: number) => void;
}) {
  return (
    <div
      style={{
        border: `1px solid ${colors.sand}`,
        borderRadius: radius.md,
        padding: "16px 18px",
        background: colors.ivory,
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, marginBottom: 12 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <span className="mono" style={{ fontSize: 12, color: colors.textFaint }}>#{index + 1}</span>
          <Badge tone={linea.tipo === "dominio" ? "sage" : "neutral"}>
            {TIPO_LINEA_LABEL[linea.tipo]}
          </Badge>
        </div>
        <div style={{ display: "flex", gap: 6 }}>
          <IconBtn label="Subir" disabled={index === 0} onClick={() => onMove(-1)}>↑</IconBtn>
          <IconBtn label="Bajar" disabled={index === total - 1} onClick={() => onMove(1)}>↓</IconBtn>
          <IconBtn label="Quitar" onClick={onRemove} danger>×</IconBtn>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: "0 16px" }}>
        <MiniField label="Qué añadir">
          <select
            value={linea.tipo}
            onChange={(e) => {
              const tipo = e.target.value as TipoLinea;
              onChange(
                tipo === "dominio"
                  ? { tipo, bloque: BLOQUES[0], ejercicio_id: null }
                  : { tipo, bloque: null, ejercicio_id: ejercicios[0]?.id ?? null },
              );
            }}
            style={inputStyle}
          >
            <option value="dominio">{TIPO_LINEA_LABEL.dominio}</option>
            <option value="ejercicio" disabled={ejercicios.length === 0}>
              {TIPO_LINEA_LABEL.ejercicio}
            </option>
          </select>
        </MiniField>

        {linea.tipo === "dominio" ? (
          <MiniField label="Área">
            <select
              value={linea.bloque ?? ""}
              onChange={(e) => onChange({ bloque: e.target.value })}
              style={inputStyle}
            >
              {BLOQUES.map((b) => (
                <option key={b} value={b}>{labelBloque(b)}</option>
              ))}
            </select>
          </MiniField>
        ) : (
          <MiniField label="Actividad">
            <select
              value={linea.ejercicio_id ?? ""}
              onChange={(e) => onChange({ ejercicio_id: e.target.value })}
              style={inputStyle}
            >
              {ejercicios.map((ej) => (
                <option key={ej.id} value={ej.id}>
                  {ej.nombre} · {labelPlantilla(ej.plantilla_tipo)}
                </option>
              ))}
            </select>
          </MiniField>
        )}

        <MiniField label="Dificultad">
          <select
            value={linea.nivel}
            onChange={(e) => onChange({ nivel: e.target.value })}
            style={inputStyle}
          >
            {NIVELES.map((n) => (
              <option key={n} value={n}>{labelNivel(n)}</option>
            ))}
          </select>
        </MiniField>

        <MiniField label="Cuántas por sesión">
          <input
            type="number"
            min={1}
            value={linea.n_por_sesion}
            onChange={(e) => onChange({ n_por_sesion: Math.max(1, Number(e.target.value) || 1) })}
            style={inputStyle}
          />
        </MiniField>
      </div>

      <label style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 6, fontSize: 14 }}>
        <input
          type="checkbox"
          checked={linea.activo}
          onChange={(e) => onChange({ activo: e.target.checked })}
          style={{ width: 17, height: 17 }}
        />
        Incluir en el plan
      </label>
    </div>
  );
}

function ColaPreview({ usuarioId }: { usuarioId: string }) {
  const [ver, setVer] = useState(false);
  const cola = useAsync<Cola>((s) => obtenerCola(usuarioId, {}, s), [usuarioId, ver]);

  if (!ver) {
    return (
      <Card>
        <h2 style={{ fontSize: 19, marginBottom: 4 }}>Qué actividades le tocarán</h2>
        <p style={{ color: colors.textMuted, fontSize: 14, marginBottom: 14 }}>
          Muestra las actividades que la tablet le irá pidiendo con el plan YA GUARDADO. Guarda tus cambios antes para verlos reflejados aquí.
        </p>
        <Button variant="ghost" onClick={() => setVer(true)}>Ver qué le tocará</Button>
      </Card>
    );
  }

  return (
    <Card>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", flexWrap: "wrap", gap: 10, marginBottom: 12 }}>
        <h2 style={{ fontSize: 19 }}>Qué actividades le tocarán</h2>
        <Button variant="ghost" onClick={() => cola.reload()} disabled={cola.loading}>
          Actualizar
        </Button>
      </div>
      {cola.loading && <Spinner label="Resolviendo cola…" />}
      {cola.error && (
        <StateMessage tone="error" title="No se pudo resolver la cola">
          {cola.error}
        </StateMessage>
      )}
      {cola.data && cola.data.items.length === 0 && (
        <StateMessage title="Sin actividades">
          Con este plan no le tocaría ninguna actividad. Añade y guarda al menos un área o una actividad activa.
        </StateMessage>
      )}
      {cola.data && cola.data.items.length > 0 && (
        <div className="scroll-x">
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14.5, minWidth: 520 }}>
            <thead>
              <tr style={{ textAlign: "left", color: colors.textFaint, fontFamily: fonts.mono, fontSize: 12 }}>
                <th scope="col" style={{ padding: "10px 14px", fontWeight: 600 }}>Actividad</th>
                <th scope="col" style={{ padding: "10px 14px", fontWeight: 600 }}>Área</th>
                <th scope="col" style={{ padding: "10px 14px", fontWeight: 600 }}>Dificultad</th>
                <th scope="col" style={{ padding: "10px 14px", fontWeight: 600 }}>De dónde sale</th>
              </tr>
            </thead>
            <tbody>
              {cola.data.items.map((it, i) => (
                <tr key={`${it.ejercicio_id}-${i}`} style={{ borderTop: `1px solid ${colors.card}` }}>
                  <td style={{ padding: "10px 14px", fontWeight: 600 }}>{it.nombre}</td>
                  <td style={{ padding: "10px 14px" }}><Badge tone="sage">{labelBloque(it.bloque)}</Badge></td>
                  <td style={{ padding: "10px 14px" }}>{labelNivel(it.nivel)}</td>
                  <td style={{ padding: "10px 14px" }}><Badge tone="neutral">{it.origen}</Badge></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}

function MiniField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label style={{ display: "block", marginBottom: 12 }}>
      <span style={{ display: "block", fontSize: 13, fontWeight: 600, color: colors.textMuted, marginBottom: 5 }}>
        {label}
      </span>
      {children}
    </label>
  );
}

function IconBtn({
  children,
  label,
  onClick,
  disabled,
  danger,
}: {
  children: React.ReactNode;
  label: string;
  onClick: () => void;
  disabled?: boolean;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      title={label}
      style={{
        width: 34,
        height: 34,
        borderRadius: radius.sm,
        border: `1.5px solid ${danger ? colors.coral : colors.sand}`,
        background: colors.white,
        color: danger ? colors.coralDark : colors.textMuted,
        fontSize: 18,
        fontWeight: 600,
        cursor: disabled ? "not-allowed" : "pointer",
        opacity: disabled ? 0.4 : 1,
        lineHeight: 1,
      }}
    >
      {children}
    </button>
  );
}
