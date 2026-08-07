/**
 * Panel principal: lista de personas usuarias del centro + bandeja de alertas
 * pendientes (destacadas en coral, como en la presentación).
 */
import { useNavigate } from "react-router-dom";
import { listarAlertas, listarUsuarios } from "../api/endpoints";
import type { Alerta, UsuarioFinal } from "../api/types";
import { AlertCard } from "../components/AlertCard";
import { Card, PageHeader, Spinner, StateMessage } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, radius } from "../theme";
import { fmtFecha } from "../utils/format";

export function DashboardPage() {
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const navigate = useNavigate();

  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);
  const alertas = useAsync<Alerta[]>(
    (s) => listarAlertas({ centro_id: centroId, revisada: false }, s),
    [centroId],
  );

  const aliasPorId = new Map((usuarios.data ?? []).map((u) => [u.id, u.alias_interno]));

  return (
    <div>
      <PageHeader
        eyebrow="Panel del centro"
        title={`Hola, ${session!.nombre.split(" ")[0]}`}
        subtitle="Un vistazo a las personas del centro y a lo que conviene revisar hoy."
      />

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
    </div>
  );
}
