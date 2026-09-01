/**
 * Gestión de dispositivos (tablets emparejadas al centro).
 *  - Lista los dispositivos (GET /dispositivos?centro_id=).
 *  - Empareja uno nuevo (POST /dispositivos) y muestra el token que devuelve.
 *  - Revoca (desvincula) una tablet (PATCH /dispositivos/{id}/revocar).
 */
import { useState } from "react";
import { QRCodeSVG } from "qrcode.react";
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
        eyebrow="Tablets"
        title="Tablets emparejadas"
        subtitle="Las tablets del centro se emparejan una sola vez. En el día a día se abren solas; si se pierde una, se desvincula desde aquí."
      />

      <EmparejarDispositivo centroId={centroId} onCreado={() => dispositivos.reload()} />

      <section aria-labelledby="lista-dispositivos">
        <h2 id="lista-dispositivos" style={{ fontSize: 20, marginBottom: 14 }}>
          Tablets del centro
        </h2>

        {dispositivos.loading && <Spinner label="Cargando tablets…" />}
        {dispositivos.error && (
          <StateMessage tone="error" title="No se pudieron cargar las tablets">
            {dispositivos.error}
          </StateMessage>
        )}
        {dispositivos.data && dispositivos.data.length === 0 && (
          <StateMessage title="Sin tablets">
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
                    <Th>Última actividad</Th>
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
        "¿Seguro que quieres desvincular «" + disp.nombre + "»? La tablet dejará de funcionar hasta que la vuelvas a emparejar.",
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
      setError(err instanceof ApiError ? err.message : "No se pudo desvincular la tablet.");
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
        {disp.activo ? <Badge tone="sage">Activa</Badge> : <Badge tone="coral">Desvinculada</Badge>}
      </Td>
      <Td>
        <div style={{ fontSize: 13 }}>
          {disp.visto_en ? fmtFecha(disp.visto_en) : "sin actividad aún"}
        </div>
        <div style={{ fontSize: 11, color: colors.textFaint }}>
          emparejada {fmtFecha(disp.emparejado_en ?? disp.fecha_alta)}
        </div>
      </Td>
      <Td>
        {disp.activo && (
          <Button variant="coral" onClick={revocar} disabled={revocando} style={{ padding: "8px 14px", fontSize: 14 }}>
            {revocando ? "Desvinculando…" : "Desvincular"}
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
        Da de alta una tablet nueva. Con el código, la tablet queda vinculada a tu centro una sola vez.
        Después, la misma tablet sirve para las dos cosas y se elige en cada uso: <strong>Maestra</strong>{" "}
        (pide el acceso de la profesional) o <strong>Participante</strong> (se abre sola y solo muestra las
        actividades a la persona usuaria).
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
            En la tablet, abre «Emparejar esta tablet» y <strong>escanea este QR</strong> (o pega el código de
            abajo). Se muestra una sola vez: hazlo ahora.
          </p>
          <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center", marginBottom: 12 }}>
            <div style={{ background: "#fff", padding: 12, borderRadius: radius.sm, border: `1px solid ${colors.sand}`, lineHeight: 0 }}>
              <QRCodeSVG value={creado.token} size={168} level="M" />
            </div>
            <div style={{ fontSize: 13, color: colors.textMuted, flex: "1 1 200px" }}>
              Apunta la cámara de la tablet a este código y quedará vinculada a este centro.
            </div>
          </div>
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
              {copiado ? "Copiado ✓" : "Copiar código"}
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
