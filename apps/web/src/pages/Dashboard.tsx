/**
 * Panel principal: lista de personas usuarias del centro + bandeja de alertas
 * pendientes (destacadas en coral, como en la presentación).
 */
import { Link, useNavigate } from "react-router-dom";
import { listarAlertas, listarDispositivos, listarStaff, listarUsuarios, resumenAreas, resumenUso } from "../api/endpoints";
import type { Alerta, Dispositivo, ResumenArea, ResumenUso, Staff, UsuarioFinal } from "../api/types";
import { AlertCard } from "../components/AlertCard";
import { InformeCentro } from "../components/InformeCentro";
import { Card, PageHeader, Spinner, StateMessage } from "../components/ui";
import { labelBloque } from "../api/vocab";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";
import { fmtFecha, fmtPorcentaje } from "../utils/format";

export function DashboardPage() {
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const navigate = useNavigate();

  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const alertas = useAsync<Alerta[]>(
    (s) => listarAlertas({ centro_id: centroId, revisada: false }, s),
    [centroId],
  );

  const areas = useAsync<ResumenArea[]>((s) => resumenAreas(centroId, s), [centroId]);
  const uso = useAsync<ResumenUso>((s) => resumenUso(centroId, s), [centroId]);
  const dispositivos = useAsync<Dispositivo[]>((s) => listarDispositivos({ centro_id: centroId }, s), [centroId]);
  const equipo = useAsync<Staff[]>((s) => listarStaff(s), [centroId]);

  // Onboarding: mientras falten hitos básicos de arranque, guiamos al centro nuevo.
  const hayEquipo = (equipo.data?.filter((m) => m.rol !== "admin_centro").length ?? 0) > 0;
  const hayPersonas = (usuarios.data?.length ?? 0) > 0;
  const hayTablets = (dispositivos.data?.length ?? 0) > 0;
  const listasCargadas = usuarios.data != null && dispositivos.data != null && equipo.data != null;
  const mostrarOnboarding = listasCargadas && (!hayEquipo || !hayPersonas || !hayTablets);

  const aliasPorId = new Map((usuarios.data ?? []).map((u) => [u.id, u.alias_interno]));

  return (
    <div>
      <PageHeader
        eyebrow="Panel del centro"
        title={`Hola, ${session!.nombre.split(" ")[0]}`}
        subtitle="Un vistazo a las personas del centro y a lo que conviene revisar hoy."
      />

      {/* Primeros pasos: guía de arranque para un centro nuevo (hasta completarla). */}
      {mostrarOnboarding && (
        <section style={{ marginBottom: 36 }} aria-labelledby="onboarding-h">
          <Card style={{ padding: "20px 22px", borderColor: colors.sage }}>
            <h2 id="onboarding-h" style={{ fontSize: 20, marginBottom: 4 }}>Primeros pasos</h2>
            <p style={{ fontSize: 13.5, color: colors.textMuted, marginBottom: 16 }}>
              Deja el centro listo en unos minutos. Ve completando estos pasos:
            </p>
            <div style={{ display: "grid", gap: 10 }}>
              <OnbPaso n={1} hecho={hayEquipo} to="/equipo"
                titulo="Da de alta a tu equipo"
                detalle="Crea las cuentas de las maestras (integradoras) que darán las actividades." />
              <OnbPaso n={2} hecho={hayPersonas} to="/pacientes"
                titulo="Da de alta a las personas"
                detalle="Registra a las personas usuarias del centro (solo un alias, sin datos personales)." />
              <OnbPaso n={3} hecho={hayTablets} to="/dispositivos"
                titulo="Empareja una tablet"
                detalle="Genera un código de emparejamiento y conéctalo en la tablet del centro." />
              <OnbPaso n={4} hecho={hayPersonas && hayTablets} to="/pacientes"
                titulo="Planifica y arranca"
                detalle="Cada persona nace con un plan; ajústalo si quieres y ya puedes abrir sesión en la tablet." />
            </div>
          </Card>
        </section>
      )}

      {/* Actividad del centro: evidencia de uso para dirección (adherencia). */}
      {uso.data && (
        <section style={{ marginBottom: 36 }} aria-labelledby="uso-titulo">
          <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: 12, flexWrap: "wrap", marginBottom: 6 }}>
            <h2 id="uso-titulo" style={{ fontSize: 22 }}>Actividad del centro</h2>
            {areas.data && (
              <button
                onClick={() => window.print()}
                style={{
                  background: colors.sageDark, color: colors.white, border: "none",
                  borderRadius: radius.sm, padding: "8px 14px", fontSize: 13.5,
                  fontWeight: 600, cursor: "pointer",
                }}
              >
                Informe del centro (PDF)
              </button>
            )}
          </div>
          <p style={{ fontSize: 13.5, color: colors.textMuted, marginBottom: 14 }}>
            Cuánto se está usando el programa y quién lleva días sin participar.
          </p>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 14, marginBottom: 16 }}>
            <UsoDato titulo="Personas activas" valor={`${uso.data.personas_activas_30d} / ${uso.data.personas_totales}`} pie="participaron en 30 días" />
            <UsoDato titulo="Sesiones (7 días)" valor={String(uso.data.sesiones_7d)} pie="última semana" />
            <UsoDato titulo="Sesiones (30 días)" valor={String(uso.data.sesiones_30d)} pie="último mes" />
            <UsoDato titulo="Sin actividad" valor={String(uso.data.inactivas.length)} pie="conviene invitarlas" tono={uso.data.inactivas.length > 0 ? "coral" : "sage"} />
          </div>
          {uso.data.inactivas.length > 0 && (
            <Card style={{ padding: "14px 18px" }}>
              <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 8, color: colors.ink }}>
                Personas que llevan días sin participar
              </div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                {uso.data.inactivas.map((p) => (
                  <button
                    key={p.usuario_final_id}
                    onClick={() => navigate(`/usuarios/${p.usuario_final_id}`)}
                    style={{
                      background: colors.card, border: `1px solid ${colors.sand}`, borderRadius: radius.sm,
                      padding: "6px 12px", fontSize: 13, color: colors.ink, cursor: "pointer",
                    }}
                  >
                    {p.alias_interno}{" "}
                    <span style={{ color: colors.textFaint }}>
                      · {p.dias_sin_actividad == null ? "nunca" : `${p.dias_sin_actividad} días`}
                    </span>
                  </button>
                ))}
              </div>
            </Card>
          )}
        </section>
      )}

      {/* Bandeja de alertas pendientes */}
      <section style={{ marginBottom: 36 }} aria-labelledby="alertas-titulo">
        <div style={{ display: "flex", alignItems: "baseline", gap: 10, marginBottom: 14 }}>
          <h2 id="alertas-titulo" style={{ fontSize: 22 }}>Alertas pendientes</h2>
          {alertas.data && (
            <span className="mono" style={{ color: colors.textFaint, fontSize: 13 }}>
              {alertas.data.length} sin revisar
            </span>
          )}
        </div>

        {alertas.loading && <Spinner label="Cargando alertas…" />}
        {alertas.error && (
          <StateMessage tone="error" title="No se pudieron cargar las alertas">
            {alertas.error}
          </StateMessage>
        )}
        {alertas.data && alertas.data.length === 0 && (
          <StateMessage title="Sin alertas pendientes">
            Nada fuera de lo normal ahora mismo. Cuando el sistema detecte un cambio en el patrón de
            alguien, aparecerá aquí.
          </StateMessage>
        )}
        {alertas.data && alertas.data.length > 0 && (
          <div style={{ display: "grid", gap: 14 }}>
            {alertas.data.map((a) => (
              <button
                key={a.id}
                onClick={() => navigate(`/usuarios/${a.usuario_final_id}`)}
                style={{ background: "none", border: "none", padding: 0, margin: 0, font: "inherit", color: "inherit", textAlign: "left", cursor: "pointer", display: "block" }}
                aria-label={`Ver evolución de ${aliasPorId.get(a.usuario_final_id) ?? "la persona"}`}
              >
                <AlertCard alerta={a} aliasLabel={aliasPorId.get(a.usuario_final_id)} />
              </button>
            ))}
          </div>
        )}
      </section>

      {/* Cómo va cada área en el centro (priorización más allá de las alertas) */}
      {areas.data && areas.data.length > 0 && (
        <section style={{ marginBottom: 36 }} aria-labelledby="areas-titulo">
          <h2 id="areas-titulo" style={{ fontSize: 22, marginBottom: 6 }}>Cómo va cada área</h2>
          <p style={{ fontSize: 13.5, color: colors.textMuted, marginBottom: 14 }}>
            Desempeño medio del centro por dominio, de peor a mejor. Ayuda a priorizar aunque no haya saltado una alerta.
          </p>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 14 }}>
            {areas.data.map((a) => {
              const flojo = a.desempeno_medio < 0.5;
              return (
                <Card key={a.bloque} style={{ padding: "16px 18px", borderColor: flojo ? colors.coral : colors.sand }}>
                  <div style={{ fontFamily: fonts.serif, fontSize: 17, marginBottom: 6 }}>{labelBloque(a.bloque)}</div>
                  <div style={{ fontSize: 30, fontWeight: 700, color: flojo ? colors.coralDark : colors.sageDark }}>
                    {fmtPorcentaje(a.desempeno_medio)}
                  </div>
                  <div style={{ fontSize: 12.5, color: colors.textFaint, marginTop: 4 }}>
                    {a.n_personas} persona{a.n_personas === 1 ? "" : "s"}
                    {a.n_por_debajo > 0 && (
                      <span style={{ color: colors.coralDark }}> · {a.n_por_debajo} por debajo</span>
                    )}
                  </div>
                </Card>
              );
            })}
          </div>
        </section>
      )}

      {/* Lista de personas usuarias */}
      <section aria-labelledby="usuarios-titulo">
        <h2 id="usuarios-titulo" style={{ fontSize: 22, marginBottom: 14 }}>
          Personas del centro
        </h2>

        {usuarios.loading && <Spinner label="Cargando personas…" />}
        {usuarios.error && (
          <StateMessage tone="error" title="No se pudieron cargar las personas">
            {usuarios.error}
          </StateMessage>
        )}
        {usuarios.data && usuarios.data.length === 0 && (
          <StateMessage title="Aún no hay personas dadas de alta">
            Cuando se registren personas usuarias en el centro, aparecerán en esta lista.
          </StateMessage>
        )}
        {usuarios.data && usuarios.data.length > 0 && (
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))",
              gap: 16,
            }}
          >
            {usuarios.data.map((u) => {
              const tieneAlerta = (alertas.data ?? []).some((a) => a.usuario_final_id === u.id);
              return (
                <Card
                  key={u.id}
                  as="article"
                  style={{
                    padding: 0,
                    overflow: "hidden",
                    borderColor: tieneAlerta ? colors.coral : colors.sand,
                  }}
                >
                  <button
                    onClick={() => navigate(`/usuarios/${u.id}`)}
                    style={{
                      background: "none",
                      border: "none",
                      margin: 0,
                      font: "inherit",
                      color: "inherit",
                      textAlign: "left",
                      cursor: "pointer",
                      display: "block",
                      width: "100%",
                      padding: "18px 20px",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <span
                        aria-hidden
                        style={{
                          width: 40,
                          height: 40,
                          borderRadius: "50%",
                          background: tieneAlerta ? colors.coral : colors.sage,
                          flexShrink: 0,
                        }}
                      />
                      <div>
                        <div style={{ fontSize: 17, fontWeight: 600 }}>{u.alias_interno}</div>
                        <div style={{ fontSize: 12.5, color: colors.textFaint }}>
                          Alta: {fmtFecha(u.fecha_alta)}
                        </div>
                      </div>
                    </div>
                    <div
                      style={{
                        marginTop: 14,
                        paddingTop: 12,
                        borderTop: `1px solid ${colors.card}`,
                        fontSize: 13.5,
                        color: tieneAlerta ? colors.coralDark : colors.sageDark,
                        fontWeight: 600,
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                      }}
                    >
                      <span>{tieneAlerta ? "Revisar cambio" : "Ver evolución"}</span>
                      <span
                        aria-hidden
                        style={{
                          fontSize: 12,
                          padding: "2px 8px",
                          borderRadius: radius.sm,
                          background: colors.card,
                          color: colors.textMuted,
                        }}
                      >
                        →
                      </span>
                    </div>
                  </button>
                </Card>
              );
            })}
          </div>
        )}
      </section>

      {/* Informe imprimible del centro (oculto en pantalla; solo al imprimir). */}
      {uso.data && areas.data && (
        <InformeCentro areas={areas.data} uso={uso.data} centroNombre={session!.centro_nombre} />
      )}
    </div>
  );
}

function OnbPaso({ n, hecho, to, titulo, detalle }: {
  n: number; hecho: boolean; to: string; titulo: string; detalle: string;
}) {
  return (
    <Link to={to} style={{ textDecoration: "none", color: "inherit" }}>
      <div style={{
        display: "flex", alignItems: "flex-start", gap: 14, padding: "12px 14px",
        border: `1px solid ${colors.sand}`, borderRadius: radius.sm, background: colors.card,
      }}>
        <span aria-hidden style={{
          flex: "0 0 auto", width: 30, height: 30, borderRadius: "50%",
          background: hecho ? colors.sageDark : colors.white, border: `2px solid ${hecho ? colors.sageDark : colors.sand}`,
          color: hecho ? colors.white : colors.textMuted, display: "flex", alignItems: "center",
          justifyContent: "center", fontWeight: 700, fontSize: 15,
        }}>
          {hecho ? "✓" : n}
        </span>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 600, color: colors.ink, textDecoration: hecho ? "line-through" : "none" }}>{titulo}</div>
          <div style={{ fontSize: 13, color: colors.textMuted, marginTop: 2 }}>{detalle}</div>
        </div>
        <span aria-hidden style={{ color: colors.textFaint, alignSelf: "center" }}>→</span>
      </div>
    </Link>
  );
}

function UsoDato({ titulo, valor, pie, tono = "sage" }: {
  titulo: string; valor: string; pie: string; tono?: "sage" | "coral";
}) {
  return (
    <Card style={{ padding: "16px 18px" }}>
      <div style={{ fontSize: 12.5, color: colors.textFaint, marginBottom: 4 }}>{titulo}</div>
      <div style={{ fontSize: 28, fontWeight: 700, color: tono === "coral" ? colors.coralDark : colors.sageDark, lineHeight: 1.1 }}>
        {valor}
      </div>
      <div style={{ fontSize: 12, color: colors.textFaint, marginTop: 3 }}>{pie}</div>
    </Card>
  );
}
