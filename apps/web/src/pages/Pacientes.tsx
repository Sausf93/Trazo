/**
 * Pacientes del centro: la integradora gestiona sus plazas sin tocar la BD.
 * Añadir, buscar, editar el alias y dar de baja. Enlaces a evolución y plan.
 */
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  crearUsuario,
  darDeBajaUsuario,
  editarUsuario,
  listarUsuarios,
  suprimirUsuario,
} from "../api/endpoints";
import type { UsuarioFinal } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { Button, Card, PageHeader, Spinner, StateMessage, inputStyle } from "../components/ui";
import { useAsync } from "../hooks/useAsync";
import { colors, radius } from "../theme";

export function PacientesPage() {
  const { session } = useAuth();
  const centroId = session!.centro_id;
  const usuarios = useAsync<UsuarioFinal[]>((s) => listarUsuarios(centroId, s), [centroId]);

  const [busqueda, setBusqueda] = useState("");
  const [nuevoAlias, setNuevoAlias] = useState("");
  const [creando, setCreando] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const filtrados = useMemo(() => {
    const q = busqueda.trim().toLowerCase();
    const lista = usuarios.data ?? [];
    return q ? lista.filter((u) => u.alias_interno.toLowerCase().includes(q)) : lista;
  }, [usuarios.data, busqueda]);

  async function anadir() {
    const alias = nuevoAlias.trim();
    if (!alias) return;
    setCreando(true);
    setError(null);
    try {
      await crearUsuario({ alias_interno: alias });
      setNuevoAlias("");
      usuarios.reload();
    } catch {
      setError("No se pudo añadir la persona. Inténtalo de nuevo.");
    } finally {
      setCreando(false);
    }
  }

  return (
    <div>
      <PageHeader
        eyebrow="Panel del centro"
        title="Personas"
        subtitle="Da de alta, corrige un nombre o da de baja a las personas del centro."
      />

      {/* Añadir + buscar */}
      <Card style={{ marginBottom: 24 }}>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          <div style={{ flex: "1 1 240px" }}>
            <label style={{ fontSize: 13, color: colors.textMuted, display: "block", marginBottom: 4 }}>
              Añadir persona (alias interno, sin datos personales)
            </label>
            <input
              style={inputStyle}
              value={nuevoAlias}
              aria-label="Añadir persona (alias interno)"
              placeholder="p. ej. Paco M."
              onChange={(e) => setNuevoAlias(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && anadir()}
            />
          </div>
          <Button onClick={anadir} disabled={creando || !nuevoAlias.trim()}>
            {creando ? "Añadiendo…" : "Añadir"}
          </Button>
        </div>
        {error && <p style={{ color: colors.coralDeep, marginTop: 8, fontSize: 14 }}>{error}</p>}
        <div style={{ marginTop: 16 }}>
          <input
            style={inputStyle}
            value={busqueda}
            aria-label="Buscar persona por nombre"
            placeholder="Buscar por nombre…"
            onChange={(e) => setBusqueda(e.target.value)}
          />
        </div>
      </Card>

      {usuarios.loading && <Spinner label="Cargando personas…" />}
      {usuarios.error && (
        <StateMessage tone="error" title="No se pudo cargar la lista">
          {usuarios.error}
        </StateMessage>
      )}
      {usuarios.data && filtrados.length === 0 && (
        <StateMessage title="Sin resultados">
          {busqueda ? "Nadie coincide con la búsqueda." : "Aún no hay personas dadas de alta."}
        </StateMessage>
      )}

      <div style={{ display: "grid", gap: 12 }}>
        {filtrados.map((u) => (
          <FilaPaciente
            key={u.id}
            usuario={u}
            esAdmin={session?.rol === "admin_centro"}
            onCambio={() => usuarios.reload()}
          />
        ))}
      </div>
    </div>
  );
}

function FilaPaciente({ usuario, esAdmin, onCambio }: { usuario: UsuarioFinal; esAdmin: boolean; onCambio: () => void }) {
  const [editando, setEditando] = useState(false);
  const [alias, setAlias] = useState(usuario.alias_interno);
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function suprimir() {
    // Acción irreversible: se pide teclear el alias exacto para confirmar.
    const conf = window.prompt(
      `SUPRIMIR (RGPD) a "${usuario.alias_interno}".\n\n` +
        "Se borran su nombre real y consentimientos; se conserva su histórico ANONIMIZADO (estadística). Es IRREVERSIBLE.\n\n" +
        `Para confirmar, escribe el nombre exacto: ${usuario.alias_interno}`,
    );
    if (conf == null) return;
    if (conf.trim() !== usuario.alias_interno) {
      setError("El nombre no coincide: no se ha suprimido nada.");
      return;
    }
    setOcupado(true);
    setError(null);
    try {
      await suprimirUsuario(usuario.id);
      onCambio();
    } catch {
      setError("No se pudo suprimir. Inténtalo de nuevo.");
    } finally {
      setOcupado(false);
    }
  }

  async function guardar() {
    setOcupado(true);
    setError(null);
    try {
      await editarUsuario(usuario.id, { alias_interno: alias.trim() || usuario.alias_interno });
      setEditando(false);
      onCambio();
    } catch {
      setError("No se pudo guardar el cambio. Revisa la conexión e inténtalo de nuevo.");
    } finally {
      setOcupado(false);
    }
  }

  async function baja() {
    if (!window.confirm(`¿Dar de baja a "${usuario.alias_interno}"? Se conserva su histórico, pero deja de aparecer.`)) return;
    setOcupado(true);
    setError(null);
    try {
      await darDeBajaUsuario(usuario.id);
      onCambio();
    } catch {
      setError("No se pudo dar de baja. Inténtalo de nuevo.");
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
      }}
    >
      {editando ? (
        <input
          style={{ ...inputStyle, flex: "1 1 180px" }}
          value={alias}
          autoFocus
          aria-label={`Editar el nombre de ${usuario.alias_interno}`}
          onChange={(e) => setAlias(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && guardar()}
        />
      ) : (
        <span style={{ flex: "1 1 180px", fontFamily: "Fraunces, serif", fontSize: 18 }}>
          {usuario.alias_interno}
        </span>
      )}
      {error && (
        <span role="alert" style={{ flexBasis: "100%", color: colors.coralDeep, fontSize: 13 }}>{error}</span>
      )}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <Link to={`/usuarios/${usuario.id}`}><Button variant="ghost">Evolución</Button></Link>
        <Link to={`/usuarios/${usuario.id}/plan`}><Button variant="ghost">Plan</Button></Link>
        {editando ? (
          <Button onClick={guardar} disabled={ocupado}>Guardar</Button>
        ) : (
          <Button variant="ghost" onClick={() => setEditando(true)} disabled={ocupado}>Editar</Button>
        )}
        <Button variant="coral" onClick={baja} disabled={ocupado}>Baja</Button>
        {esAdmin && (
          <button
            onClick={suprimir}
            disabled={ocupado}
            title="Derecho de supresión (RGPD): anonimiza a la persona"
            style={{
              padding: "9px 14px",
              borderRadius: radius.sm,
              border: `1.5px solid ${colors.coralDark}`,
              background: "transparent",
              color: colors.coralDark,
              fontWeight: 600,
              fontSize: 13.5,
              cursor: ocupado ? "default" : "pointer",
            }}
          >
            Suprimir (RGPD)
          </button>
        )}
      </div>
    </div>
  );
}
