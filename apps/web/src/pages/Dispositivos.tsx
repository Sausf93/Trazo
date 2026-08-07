/**
 * Gestión de dispositivos (tablets emparejadas al centro).
 *  - Lista los dispositivos (GET /dispositivos?centro_id=).
 *  - Empareja uno nuevo (POST /dispositivos) y muestra el token que devuelve.
 *  - Revoca (desvincula) una tablet (PATCH /dispositivos/{id}/revocar).
 */
import { useState } from "react";
import {
  emparejarDispositivo,
  listarDispositivos,
  revocarDispositivo,
} from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Dispositivo, DispositivoCreado, RolDispositivo } from "../api/types";
import { ROLES_DISPOSITIVO, labelRolDispositivo } from "../api/vocab";
import { Badge, Button, Card, Field, PageHeader, Spinner, StateMessage, inputStyle } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";
import { fmtFecha } from "../utils/format";

export function DispositivosPage() {
  const { session } = useAuth();
  const centroId = session!.centro_id;

  const dispositivos = useAsync<Dispositivo[]>(
    (s) => listarDispositivos({ centro_id: centroId }, s),
    [centroId],
  );

  return (
    <div>
      <PageHeader
        eyebrow="Dispositivos"
        title="Tablets emparejadas"
        subtitle="Las tablets del centro se emparejan una sola vez. En el día a día no piden login; si se pierde una, se desvincula desde aquí."
      />

      <EmparejarDispositivo centroId={centroId} onCreado={() => dispositivos.reload()} />

      <section aria-labelledby="lista-dispositivos">
        <h2 id="lista-dispositivos" style={{ fontSize: 20, marginBottom: 14 }}>
          Dispositivos del centro
        </h2>

        {dispositivos.loading && <Spinner label="Cargando dispositivos…" />}
        {dispositivos.error && (
          <StateMessage tone="error" title="No se pudieron cargar los dispositivos">
            {dispositivos.error}
          </StateMessage>
        )}
        {dispositivos.data && dispositivos.data.length === 0 && (
          <StateMessage title="Sin dispositivos">
            Todavía no hay ninguna tablet emparejada. Empareja la primera con el formulario de arriba.
          </StateMessage>
        )}
        {dispositivos.data && dispositivos.data.length > 0 && (
          <Card style={{ padding: 0 }}>
            <div className="scroll-x">
              <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14.5, minWidth: 620 }}>
                <thead>
                  <tr style={{ textAlign: "left", color: colors.textFaint, fontFamily: fonts.mono, fontSize: 12 }}>
                    <Th>Nombre</Th>
                    <Th>Rol</Th>
                    <Th>Estado</Th>
                    <Th>Alta</Th>
                    <Th> </Th>
                  </tr>
                </thead>
                <tbody>
                  {dispositivos.data.map((d) => (
                    <FilaDispositivo key={d.id} disp={d} onRevocado={() => dispositivos.reload()} />
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        )}
      </section>
    </div>
  );
}

function FilaDispositivo({ disp, onRevocado }: { disp: Dispositivo; onRevocado: () => void }) {
  const [revocando, setRevocando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function revocar() {
    if (
      !window.confirm(
        "¿Seguro que quieres revocar «" + disp.nombre + "»? La tablet dejará de funcionar.",
      )
    ) {
      return;
    }
    setError(null);
    setRevocando(true);
    try {
      await revocarDispositivo(disp.id);
      onRevocado();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo revocar el dispositivo.");
    } finally {
      setRevocando(false);
    }
  }

  return (
    <tr style={{ borderTop: `1px solid ${colors.card}` }}>
      <Td>
        <div style={{ fontWeight: 600 }}>{disp.nombre}</div>
        <div style={{ fontSize: 12, color: colors.textFaint, fontFamily: fonts.mono }}>{disp.id}</div>
      </Td>
      <Td><Badge tone={disp.rol === "maestra" ? "sage" : "neutral"}>{labelRolDispositivo(disp.rol)}</Badge></Td>
      <Td>
        {disp.activo ? <Badge tone="sage">Activo</Badge> : <Badge tone="coral">Revocado</Badge>}
      </Td>
      <Td>{fmtFecha(disp.fecha_alta)}</Td>
      <Td>
        {disp.activo && (
          <Button variant="coral" onClick={revocar} disabled={revocando} style={{ padding: "8px 14px", fontSize: 14 }}>
            {revocando ? "Revocando…" : "Revocar"}
          </Button>
        )}
        {error && (
          <div role="alert" style={{ color: colors.coralDark, fontSize: 12.5, marginTop: 6 }}>
            {error}
          </div>
        )}
      </Td>
    </tr>
  );
}

function EmparejarDispositivo({ centroId, onCreado }: { centroId: string; onCreado: () => void }) {
  const [nombre, setNombre] = useState("");
  const [rol, setRol] = useState<RolDispositivo>("participante");
  const [error, setError] = useState<string | null>(null);
  const [creando, setCreando] = useState(false);
  const [creado, setCreado] = useState<DispositivoCreado | null>(null);
  const [copiado, setCopiado] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setCreado(null);
    setCopiado(false);
    if (!nombre.trim()) {
      setError("El nombre del dispositivo es obligatorio.");
      return;
    }
    setCreando(true);
    try {
      const nuevo = await emparejarDispositivo({ nombre: nombre.trim(), rol, centro_id: centroId });
      setCreado(nuevo);
      setNombre("");
      onCreado();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo emparejar el dispositivo.");
    } finally {
      setCreando(false);
    }
  }

  async function copiarToken() {
    if (!creado) return;
    try {
      await navigator.clipboard.writeText(creado.token);
      setCopiado(true);
    } catch {
      setCopiado(false);
    }
  }

  return (
    <Card style={{ marginBottom: 26 }}>
      <h2 style={{ fontSize: 19, marginBottom: 4 }}>Emparejar una tablet</h2>
      <p style={{ color: colors.textMuted, fontSize: 14, marginBottom: 18 }}>
        Da de alta una tablet nueva. El rol se fija al emparejar: <strong>maestra</strong> (la de la
        trabajadora, con login) o <strong>participante</strong> (kiosco, sin login).
      </p>

      <form onSubmit={onSubmit}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "0 20px" }}>
          <Field label="Nombre del dispositivo" htmlFor="d-nombre">
            <input
              id="d-nombre"
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              style={inputStyle}
              placeholder="p. ej. Tablet sala 2"
              required
            />
          </Field>

          <Field label="Rol" htmlFor="d-rol">
            <select
              id="d-rol"
              value={rol}
              onChange={(e) => setRol(e.target.value as RolDispositivo)}
              style={inputStyle}
            >
              {ROLES_DISPOSITIVO.map((r) => (
                <option key={r} value={r}>{labelRolDispositivo(r)}</option>
              ))}
            </select>
          </Field>
        </div>

        {error && (
          <div role="alert" style={{ background: colors.alertBg, border: `1px solid ${colors.coral}`, color: colors.coralDark, borderRadius: radius.sm, padding: "10px 12px", fontSize: 14, marginBottom: 14 }}>
            {error}
          </div>
        )}

        <Button type="submit" disabled={creando}>
          {creando ? "Emparejando…" : "Emparejar tablet"}
        </Button>
      </form>

      {creado && (
        <div
          style={{
            marginTop: 18,
            background: "rgba(124,152,133,0.12)",
            border: `1px solid ${colors.sage}`,
            borderRadius: radius.md,
            padding: "16px 18px",
          }}
        >
          <strong style={{ display: "block", marginBottom: 4, color: colors.ink }}>
            Tablet «{creado.nombre}» emparejada
          </strong>
          <p style={{ fontSize: 13.5, color: colors.textMuted, marginBottom: 10 }}>
            Copia este token ahora: es lo que introduce la tablet para vincularse y no se vuelve a mostrar.
          </p>
          <div style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "center" }}>
            <code
              style={{
                fontFamily: fonts.mono,
                fontSize: 13.5,
                background: colors.white,
                border: `1px solid ${colors.sand}`,
                borderRadius: radius.sm,
                padding: "8px 12px",
                wordBreak: "break-all",
                flex: "1 1 260px",
              }}
            >
              {creado.token}
            </code>
            <Button variant="ghost" type="button" onClick={copiarToken}>
              {copiado ? "Copiado ✓" : "Copiar token"}
            </Button>
          </div>
        </div>
      )}
    </Card>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th scope="col" style={{ padding: "12px 16px", fontWeight: 600 }}>{children}</th>;
}
function Td({ children }: { children: React.ReactNode }) {
  return <td style={{ padding: "12px 16px", verticalAlign: "top" }}>{children}</td>;
}
