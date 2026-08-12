/**
 * Equipo del centro (solo admin del centro): da de alta y gestiona a las
 * maestras (integradoras). Ellas luego dan de alta pacientes y hacen sesiones.
 */
import { useState } from "react";
import { Navigate } from "react-router-dom";
import { actualizarStaff, crearStaff, listarStaff } from "../api/endpoints";
import type { Staff } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { Button, Card, PageHeader, Spinner, StateMessage, inputStyle } from "../components/ui";
import { useAsync } from "../hooks/useAsync";
import { colors, radius } from "../theme";

export function EquipoPage() {
  const { session } = useAuth();
  // Guarda de rol en el front: "Equipo" es solo del admin del centro (el backend
  // ya lo exige, pero así una maestra que teclee /equipo no ve una página rota).
  const esAdmin = session?.rol === "admin_centro";
  const equipo = useAsync<Staff[]>((s) => listarStaff(s), []);

  const [nombre, setNombre] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rol, setRol] = useState("integradora");
  const [creando, setCreando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  // Todos los hooks quedan declarados arriba; la guarda va después.
  if (!esAdmin) return <Navigate to="/" replace />;

  async function anadir() {
    setError(null);
    setOk(null);
    if (!nombre.trim() || !email.trim()) {
      setError("Pon al menos nombre y email.");
      return;
    }
    if (password.length < 8) {
      setError("La contraseña debe tener al menos 8 caracteres.");
      return;
    }
    setCreando(true);
    try {
      const creada = await crearStaff({ nombre: nombre.trim(), email: email.trim(), password, rol });
      setOk(`Cuenta creada para ${creada.nombre}. Ya puede entrar con su email y contraseña.`);
      setNombre("");
      setEmail("");
      setPassword("");
      setRol("integradora");
      equipo.reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "No se pudo crear la cuenta.");
    } finally {
      setCreando(false);
    }
  }

  return (
    <div>
      <PageHeader
        eyebrow="Panel del centro"
        title="Equipo"
        subtitle="Da de alta a las maestras del centro. Cada una entra con su email y contraseña, y desde ahí gestiona a sus pacientes."
      />

      {/* Alta de una cuenta nueva */}
      <Card style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, marginBottom: 14 }}>Añadir una persona al equipo</h2>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 12 }}>
          <Field label="Nombre">
            <input style={inputStyle} value={nombre} placeholder="p. ej. Nuria G."
              onChange={(e) => setNombre(e.target.value)} />
          </Field>
          <Field label="Email (con el que entrará)">
            <input style={inputStyle} value={email} placeholder="nuria@centro.es" type="email"
              onChange={(e) => setEmail(e.target.value)} />
          </Field>
          <Field label="Contraseña (mínimo 8)">
            <input style={inputStyle} value={password} placeholder="••••••••" type="password"
              onChange={(e) => setPassword(e.target.value)} />
          </Field>
          <Field label="Rol">
            <select style={inputStyle} value={rol} onChange={(e) => setRol(e.target.value)}>
              <option value="integradora">Maestra (integradora)</option>
              <option value="admin_centro">Administración del centro</option>
            </select>
          </Field>
        </div>
        <div style={{ marginTop: 16, display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap" }}>
          <Button onClick={anadir} disabled={creando}>
            {creando ? "Creando…" : "Crear cuenta"}
          </Button>
          {error && <span role="alert" style={{ color: colors.coralDeep, fontSize: 14 }}>{error}</span>}
          {ok && <span role="status" style={{ color: colors.sageDark, fontSize: 14 }}>{ok}</span>}
        </div>
      </Card>

      {equipo.loading && <Spinner label="Cargando equipo…" />}
      {equipo.error && (
        <StateMessage tone="error" title="No se pudo cargar el equipo">
          {equipo.error}
        </StateMessage>
      )}

      <div style={{ display: "grid", gap: 12 }}>
        {(equipo.data ?? []).map((m) => (
          <FilaStaff
            key={m.id}
            miembro={m}
            esYo={m.id === session?.id}
            onCambio={() => equipo.reload()}
          />
        ))}
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label style={{ display: "block" }}>
      <span style={{ display: "block", fontSize: 13, color: colors.textMuted, marginBottom: 4 }}>{label}</span>
      {children}
    </label>
  );
}

function FilaStaff({ miembro, esYo, onCambio }: { miembro: Staff; esYo: boolean; onCambio: () => void }) {
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const esAdmin = miembro.rol === "admin_centro";

  async function cambiarActivo() {
    const accion = miembro.activo ? "dar de baja" : "reactivar";
    if (!window.confirm(`¿Seguro que quieres ${accion} a "${miembro.nombre}"?`)) return;
    setOcupado(true);
    setError(null);
    try {
      await actualizarStaff(miembro.id, { activo: !miembro.activo });
      onCambio();
    } catch (e) {
      setError(e instanceof Error ? e.message : "No se pudo cambiar.");
    } finally {
      setOcupado(false);
    }
  }

  return (
    <div
      style={{
        background: colors.white,
        border: `1px solid ${colors.sand}`,
        borderRadius: radius.md,
        padding: "14px 18px",
        display: "flex",
        alignItems: "center",
        gap: 12,
        flexWrap: "wrap",
        opacity: miembro.activo ? 1 : 0.6,
      }}
    >
      <div style={{ flex: "1 1 220px" }}>
        <div style={{ fontFamily: "Fraunces, serif", fontSize: 18 }}>
          {miembro.nombre}{" "}
          <span style={{ fontFamily: "inherit", fontSize: 12.5, color: esAdmin ? colors.coralDeep : colors.sageDark, fontWeight: 600 }}>
            · {esAdmin ? "Administración" : "Maestra"}
          </span>
        </div>
        <div style={{ fontSize: 13.5, color: colors.textFaint }}>{miembro.email}</div>
      </div>
      {error && (
        <span role="alert" style={{ flexBasis: "100%", color: colors.coralDeep, fontSize: 13 }}>{error}</span>
      )}
      <div style={{ display: "flex", gap: 8 }}>
        {esYo ? (
          <span style={{ fontSize: 13, color: colors.textFaint, alignSelf: "center" }}>Tu cuenta</span>
        ) : miembro.activo ? (
          <Button variant="coral" onClick={cambiarActivo} disabled={ocupado}>Dar de baja</Button>
        ) : (
          <Button variant="ghost" onClick={cambiarActivo} disabled={ocupado}>Reactivar</Button>
        )}
      </div>
    </div>
  );
}
