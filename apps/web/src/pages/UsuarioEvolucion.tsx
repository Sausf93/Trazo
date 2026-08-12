/**
 * Evolución individual de una persona:
 *  - selector de bloque
 *  - gráfica temporal de precisión (puntos fuera de patrón en coral)
 *  - resumen (rendimiento medio, tasa de ayuda)
 *  - sus alertas
 */
import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { alertasUsuario, evolucionUsuario, listarUsuarios } from "../api/endpoints";
import type { Alerta, Evolucion, UsuarioFinal } from "../api/types";
import { BLOQUES, labelBloque } from "../api/vocab";
import { AlertCard } from "../components/AlertCard";
import { EstadoBadge } from "../components/EstadoBadge";
import { EvolucionChart, construirSerie } from "../components/EvolucionChart";
import { InformeFamilia } from "../components/InformeFamilia";
import { SugerenciasNivel } from "../components/SugerenciasNivel";
import { Card, PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

export function UsuarioEvolucionPage() {
  const { id = "" } = useParams();
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const [bloque, setBloque] = useState<string>("");
  const [verDetalle, setVerDetalle] = useState(false);

  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const evolucion = useAsync<Evolucion>(
    (s) => evolucionUsuario(id, bloque ? { bloque } : {}, s),
    [id, bloque],
  );
  const alertas = useAsync<Alerta[]>((s) => alertasUsuario(id, s), [id]);

  const alias = usuarios.data?.find((u) => u.id === id)?.alias_interno ?? id;

  const serie = useMemo(
    () => (evolucion.data ? construirSerie(evolucion.data.puntos) : []),
    [evolucion.data],
  );
  const nAnomalos = serie.filter((p) => p.anomalo).length;
  // Alerta "pendiente" = generada y aún sin revisar. Es lo que decide el veredicto.
  const pendientes = useMemo(
    () => (alertas.data ?? []).filter((a) => a.fecha_revision == null),
    [alertas.data],
  );
  // ¿La alerta es de PARTICIPACIÓN (deja actividades sin intentar)? Entonces la
  // gráfica de precisión engaña (solo cuenta lo intentado) y hay que avisarlo.
  const hayDesconexion = useMemo(
    () => pendientes.some((a) => String(a.contexto_json?.senal ?? "").includes("desconexion")),
    [pendientes],
  );

  return (
    <div>
      <Link to="/" style={{ color: colors.sageDark, fontSize: 14, fontWeight: 600, textDecoration: "none" }}>
        ← Volver al panel
      </Link>

      <div style={{ marginTop: 10 }}>
        <PageHeader
          eyebrow="Vista individual"
          title={alias}
          subtitle="Evolución en el tiempo comparada con su propio patrón, nunca con otras personas."
          actions={
            <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
              <button
                type="button"
                onClick={() => window.print()}
                disabled={!evolucion.data || evolucion.data.puntos.length === 0}
                title="Genera una hoja imprimible que puedes guardar como PDF"
                style={{
                  fontFamily: fonts.sans,
                  fontWeight: 600,
                  fontSize: 15,
                  padding: "11px 20px",
                  borderRadius: radius.sm,
                  border: `1.5px solid ${colors.sageDark}`,
                  background: colors.sageDark,
                  color: colors.white,
                  opacity: !evolucion.data || evolucion.data.puntos.length === 0 ? 0.55 : 1,
                  cursor:
                    !evolucion.data || evolucion.data.puntos.length === 0 ? "not-allowed" : "pointer",
                }}
              >
                Informe para la familia (PDF)
              </button>
              <Link
                to={`/usuarios/${id}/plan`}
                style={{
                  display: "inline-block",
                  fontFamily: fonts.sans,
                  fontWeight: 600,
                  fontSize: 15,
                  padding: "11px 20px",
                  borderRadius: radius.sm,
                  border: `1.5px solid ${colors.sage}`,
                  background: colors.sage,
                  color: colors.white,
                  textDecoration: "none",
                }}
              >
                Editar plan de trabajo
              </Link>
            </div>
          }
        />
      </div>

      {/* ── LO PRIMERO: cómo va, en una frase ────────────────────────────── */}
      <Veredicto
        alias={alias}
        cargando={evolucion.loading || alertas.loading}
        rendimiento={evolucion.data?.resumen.rendimiento_medio ?? null}
        nIntentos={evolucion.data?.resumen.n_intentos ?? 0}
        pendientes={pendientes}
      />

      {/* La alerta accionable, si la hay: es lo único que pide una decisión hoy. */}
      {pendientes.length > 0 && (
        <div style={{ display: "grid", gap: 14, marginBottom: 22 }}>
          {pendientes.map((a) => (
            <AlertCard key={a.id} alerta={a} />
          ))}
        </div>
      )}

      {/* ── El detalle (números, gráfica, tabla) queda plegado ───────────── */}
      <button
        type="button"
        onClick={() => setVerDetalle((v) => !v)}
        aria-expanded={verDetalle}
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 8,
          fontFamily: fonts.sans,
          fontWeight: 600,
          fontSize: 15,
          padding: "10px 16px",
          borderRadius: radius.sm,
          border: `1.5px solid ${colors.sand}`,
          background: colors.white,
          color: colors.sageDark,
          marginBottom: verDetalle ? 20 : 0,
        }}
      >
        {verDetalle ? "Ocultar el detalle ▴" : "Ver el detalle (números y gráfica) ▾"}
      </button>

      {verDetalle && (
        <div>
          {/* Encuadre responsable: qué es y qué NO es esta pantalla */}
          <div
            style={{
              border: `1px solid ${colors.sand}`,
              background: colors.card,
              borderRadius: 12,
              padding: "12px 16px",
              marginBottom: 18,
              fontSize: 13,
              color: colors.textMuted,
            }}
          >
            Estos datos reflejan el <strong style={{ color: colors.ink }}>desempeño en las actividades</strong>,
            no una medida de deterioro cognitivo. Un cambio puede deberse a vista u oído, dolor, medicación,
            ánimo o un día malo: úsalo como apoyo para <strong style={{ color: colors.ink }}>mirar con más
            atención</strong> y decidir con tu criterio, descartando antes esas causas.
          </div>

          {/* Selector de bloque */}
          <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap", marginBottom: 20 }}>
            <label htmlFor="bloque" style={{ fontSize: 14, fontWeight: 600, color: colors.textMuted }}>
              Ver solo un área
            </label>
            <select
              id="bloque"
              value={bloque}
              onChange={(e) => setBloque(e.target.value)}
              style={{
                padding: "10px 13px",
                borderRadius: radius.sm,
                border: `1.5px solid ${colors.sand}`,
                background: colors.white,
                color: colors.ink,
                minWidth: 220,
              }}
            >
              <option value="">Todas las áreas</option>
              {BLOQUES.map((b) => (
                <option key={b} value={b}>
                  {labelBloque(b)}
                </option>
              ))}
            </select>
          </div>

          {/* Resumen — etiquetas en lenguaje llano */}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
              gap: 14,
              marginBottom: 22,
            }}
          >
            <ResumenTile
              label="Le salen bien"
              value={fmtPorcentaje(evolucion.data?.resumen.rendimiento_medio ?? null)}
              hint="De media, cuánto le sale bien"
            />
            <ResumenTile
              label="Ayuda que necesita"
              value={fmtPorcentaje(evolucion.data?.resumen.tasa_ayuda ?? null)}
              hint="Parte de las veces en que hizo falta echarle una mano"
            />
            <ResumenTile
              label="Actividades hechas"
              value={String(evolucion.data?.resumen.n_intentos ?? "—")}
              hint={bloque ? labelBloque(bloque) : "Todas las áreas"}
            />
            <ResumenTile
              label="Sin puntuar"
              value={String(evolucion.data?.resumen.n_sin_valorar ?? "—")}
              hint="No las intentó o están por revisar (no cuentan)"
            />
            <ResumenTile
              label="Días a mirar"
              value={String(nAnomalos)}
              hint="El sistema sugiere mirarlos; no es un juicio"
              alert={nAnomalos > 0}
            />
          </div>

          {/* Gráfica */}
          <Card style={{ marginBottom: 26 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
              <h2 style={{ fontSize: 19 }}>Cómo le va sesión a sesión</h2>
              <span className="mono" style={{ fontSize: 12, color: colors.textFaint }}>
                {bloque ? labelBloque(bloque) : "Todas las áreas"}
              </span>
            </div>
            <p style={{ fontSize: 12.5, color: colors.textFaint, marginBottom: hayDesconexion ? 10 : 8 }}>
              Cuenta solo las actividades que <strong>intentó</strong>; las que deja sin hacer no salen aquí.
            </p>
            {hayDesconexion && (
              <div
                style={{
                  background: colors.alertBg,
                  border: `1px solid ${colors.coral}`,
                  borderRadius: radius.sm,
                  padding: "10px 12px",
                  fontSize: 13.5,
                  color: colors.ink,
                  marginBottom: 12,
                }}
              >
                Ojo: esta línea puede verse bien e incluso subir, porque solo mide lo que intenta. Lo que
                ha cambiado es que <strong>intenta menos</strong> — fíjate en «Sin puntuar», arriba.
              </div>
            )}
            {evolucion.loading && <Spinner label="Cargando evolución…" />}
            {evolucion.error && (
              <StateMessage tone="error" title="No se pudo cargar la evolución">
                {evolucion.error}
              </StateMessage>
            )}
            {evolucion.data && <EvolucionChart data={serie} />}
            {evolucion.data && (
              <div style={{ display: "flex", gap: 18, flexWrap: "wrap", marginTop: 10, fontSize: 12.5, color: colors.textFaint }}>
                <LegendDot color={colors.sage} label="Como de costumbre" />
                <LegendDot color={colors.coralDark} ring label="Se sale de lo habitual (mirar)" />
              </div>
            )}
          </Card>

          {/* Sugerencias de nivel (el profesional decide) */}
          <SugerenciasNivel usuarioId={id} />

          {/* Detalle de intentos */}
          {evolucion.data && evolucion.data.puntos.length > 0 && (
            <section aria-labelledby="detalle-intentos">
              <h2 id="detalle-intentos" style={{ fontSize: 19, marginBottom: 12 }}>Actividad por actividad</h2>
              <Card style={{ padding: 0 }}>
                <div className="scroll-x">
                  <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14.5, minWidth: 480 }}>
                    <thead>
                      <tr style={{ textAlign: "left", color: colors.textFaint, fontFamily: fonts.mono, fontSize: 12 }}>
                        <Th>Fecha</Th>
                        <Th>Área</Th>
                        <Th>Cómo le fue</Th>
                        <Th>Acierto</Th>
                      </tr>
                    </thead>
                    <tbody>
                      {[...evolucion.data.puntos].reverse().map((p, i) => (
                        <tr key={`${p.ejercicio_id}-${p.fecha}-${i}`} style={{ borderTop: `1px solid ${colors.card}` }}>
                          <Td>{fmtFecha(p.fecha)}</Td>
                          <Td>{labelBloque(p.bloque)}</Td>
                          <Td><EstadoBadge estado={p.estado} /></Td>
                          <Td>{fmtPorcentaje(p.precision)}</Td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </Card>
            </section>
          )}
        </div>
      )}

      {/* Informe imprimible para la familia: oculto en pantalla, visible al imprimir. */}
      {evolucion.data && evolucion.data.puntos.length > 0 && (
        <InformeFamilia
          alias={alias}
          bloqueLabel={labelBloque(bloque)}
          evolucion={evolucion.data}
          serie={serie}
        />
      )}
    </div>
  );
}

/**
 * Lo primero que se lee: cómo va la persona, en una frase, con color y un consejo.
 * El 90% de las visitas se resuelven aquí sin mirar un solo número.
 *   · ámbar  -> hay una alerta sin revisar (algo que decidir hoy)
 *   · verde  -> va como siempre
 *   · neutro -> aún no hay datos
 */
function Veredicto({
  alias,
  cargando,
  rendimiento,
  nIntentos,
  pendientes,
}: {
  alias: string;
  cargando: boolean;
  rendimiento: number | null;
  nIntentos: number;
  pendientes: Alerta[];
}) {
  let tono: "verde" | "ambar" | "neutro" = "neutro";
  let titulo = `Cargando cómo va ${alias}…`;
  let detalle = "";
  let consejo: string | null = null;

  if (!cargando) {
    if (pendientes.length > 0) {
      const areasTxt = [
        ...new Set(
          pendientes
            .map((a) => (a.bloque_afectado ? labelBloque(a.bloque_afectado) : null))
            .filter((x): x is string => x != null),
        ),
      ].join(" y ");
      // La "señal" dice QUÉ cambió, y evita la contradicción con la gráfica:
      // la precisión sube porque solo cuenta lo que intenta; si lo que baja es la
      // PARTICIPACIÓN, hay que decirlo con esas palabras, no "va peor".
      const clases = new Set(
        pendientes.flatMap((a) => String(a.contexto_json?.senal ?? "").split("_y_")),
      );
      const menosParticipacion = clases.has("desconexion");
      const peorAcierto = clases.has("rendimiento");
      const masLento = clases.has("latencia");

      tono = "ambar";
      titulo = `Conviene mirar a ${alias} esta semana`;
      if (menosParticipacion && !peorAcierto) {
        detalle =
          "Le sale bien lo que hace, pero participa cada vez menos: últimamente deja bastantes actividades sin intentar. Eso es lo que conviene mirar (no el acierto).";
      } else if (peorAcierto) {
        detalle = `Le cuesta más que de costumbre${areasTxt ? ` en ${areasTxt}` : ""}${
          menosParticipacion ? ", y además participa menos" : ""
        }.`;
      } else if (masLento) {
        detalle = `Tarda más de lo habitual${areasTxt ? ` en ${areasTxt}` : ""}.`;
      } else {
        detalle = areasTxt
          ? `Ha habido un cambio en ${areasTxt}.`
          : "Ha habido un cambio en su forma habitual de participar.";
      }
      consejo =
        "Antes de nada, descarta causas frecuentes (vista u oído, dolor, medicación, ánimo, un día malo). Justo abajo tienes qué ha cambiado.";
    } else if (nIntentos === 0 || rendimiento == null) {
      tono = "neutro";
      titulo = `Aún no hay datos de ${alias}`;
      detalle = "Cuando haga sus primeras actividades, aquí verás de un vistazo cómo le va.";
    } else {
      tono = "verde";
      titulo = `${alias} va como siempre`;
      detalle = "Le salen bien la mayoría de las actividades y participa con normalidad.";
      consejo = "No hace falta nada especial ahora mismo.";
    }
  }

  const paleta = {
    verde: { bg: "#EDF3EE", borde: colors.sage, punto: colors.sage },
    ambar: { bg: colors.alertBg, borde: colors.coral, punto: colors.coralDark },
    neutro: { bg: colors.card, borde: colors.sand, punto: colors.sand },
  }[tono];

  return (
    <div
      style={{
        background: paleta.bg,
        border: `1.5px solid ${paleta.borde}`,
        borderRadius: radius.md,
        padding: "22px 24px",
        marginBottom: 22,
        display: "flex",
        gap: 16,
        alignItems: "flex-start",
      }}
    >
      <span
        aria-hidden
        style={{
          width: 16,
          height: 16,
          borderRadius: "50%",
          background: paleta.punto,
          marginTop: 6,
          flexShrink: 0,
        }}
      />
      <div>
        <div style={{ fontFamily: fonts.serif, fontSize: 26, fontWeight: 500, color: colors.ink }}>
          {titulo}
        </div>
        {detalle && (
          <div style={{ fontSize: 16, color: colors.textMuted, marginTop: 6, lineHeight: 1.5 }}>
            {detalle}
          </div>
        )}
        {consejo && (
          <div style={{ fontSize: 15, color: colors.ink, marginTop: 10, fontWeight: 500 }}>
            {consejo}
          </div>
        )}
      </div>
    </div>
  );
}

function ResumenTile({
  label,
  value,
  hint,
  alert,
}: {
  label: string;
  value: string;
  hint?: string;
  alert?: boolean;
}) {
  return (
    <div
      style={{
        background: colors.white,
        border: `1px solid ${alert ? colors.coral : colors.sand}`,
        borderRadius: radius.md,
        padding: "16px 18px",
      }}
    >
      <div style={{ fontSize: 13, color: colors.textFaint, marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 28, fontWeight: 600, color: alert ? colors.coralDark : colors.ink }}>
        {value}
      </div>
      {hint && <div style={{ fontSize: 12, color: colors.textFaint, marginTop: 2 }}>{hint}</div>}
    </div>
  );
}

function LegendDot({ color, label, ring }: { color: string; label: string; ring?: boolean }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
      <span style={{ position: "relative", width: 14, height: 14, display: "inline-block" }} aria-hidden>
        {ring && (
          <span
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              border: `2px solid ${colors.coral}`,
            }}
          />
        )}
        <span
          style={{
            position: "absolute",
            inset: 4,
            borderRadius: "50%",
            background: color,
          }}
        />
      </span>
      {label}
    </span>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th scope="col" style={{ padding: "12px 16px", fontWeight: 600 }}>{children}</th>;
}
function Td({ children }: { children: React.ReactNode }) {
  return <td style={{ padding: "12px 16px" }}>{children}</td>;
}
