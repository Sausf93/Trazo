/**
 * Gestión del catálogo de ejercicios.
 * Tabla del catálogo (bloque + plantilla + nombre) y formulario de alta sobre
 * plantillas (solo rol admin_centro).
 */
import { useState } from "react";
import { crearEjercicio, listarEjercicios } from "../api/endpoints";
import { ApiError } from "../api/client";
import type { Ejercicio } from "../api/types";
import { BLOQUES, PLANTILLAS, labelBloque, labelPlantilla } from "../api/vocab";
import { Badge, Button, Card, Field, PageHeader, Spinner, StateMessage, inputStyle } from "../components/ui";
import { useAuth } from "../auth/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { colors, fonts, radius } from "../theme";

export function EjerciciosPage() {
  const { isAdmin } = useAuth();
  const ejercicios = useAsync<Ejercicio[]>((s) => listarEjercicios({}, s), []);

  return (
    <div>
      <PageHeader
        eyebrow="Catálogo"
        title="Ejercicios"
        subtitle="Los ejercicios disponibles en el centro, organizados por bloque cognitivo y plantilla."
      />

      {isAdmin && <AltaEjercicio onCreado={() => ejercicios.reload()} />}
      {!isAdmin && (
        <div style={{ marginBottom: 22 }}>
          <StateMessage title="Solo lectura">
            El alta de ejercicios está reservada al rol de administración del centro.
          </StateMessage>
        </div>
      )}

      {ejercicios.loading && <Spinner label="Cargando catálogo…" />}
      {ejercicios.error && (
        <StateMessage tone="error" title="No se pudo cargar el catálogo">
          {ejercicios.error}
        </StateMessage>
      )}
      {ejercicios.data && ejercicios.data.length === 0 && (
        <StateMessage title="Catálogo vacío">Todavía no hay ejercicios dados de alta.</StateMessage>
      )}
      {ejercicios.data && ejercicios.data.length > 0 && (
        <Card style={{ padding: 0 }}>
          <div className="scroll-x">
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14.5, minWidth: 620 }}>
              <thead>
                <tr style={{ textAlign: "left", color: colors.textFaint, fontFamily: fonts.mono, fontSize: 12 }}>
                  <Th>Nombre</Th>
                  <Th>Bloque</Th>
                  <Th>Plantilla</Th>
                  <Th>Estado</Th>
                </tr>
              </thead>
              <tbody>
                {ejercicios.data.map((e) => (
                  <tr key={e.id} style={{ borderTop: `1px solid ${colors.card}` }}>
                    <Td>
                      <div style={{ fontWeight: 600 }}>{e.nombre}</div>
                      {e.descripcion && (
                        <div style={{ fontSize: 12.5, color: colors.textFaint }}>{e.descripcion}</div>
                      )}
                    </Td>
                    <Td><Badge tone="sage">{labelBloque(e.bloque)}</Badge></Td>
                    <Td><Badge tone="neutral">{labelPlantilla(e.plantilla_tipo)}</Badge></Td>
                    <Td>
                      {e.activo ? <Badge tone="sage">Activo</Badge> : <Badge tone="neutral">Inactivo</Badge>}
                    </Td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}

function AltaEjercicio({ onCreado }: { onCreado: () => void }) {
  const [bloque, setBloque] = useState<string>(BLOQUES[0]);
  const [plantilla, setPlantilla] = useState<string>(PLANTILLAS[0]);
  const [nombre, setNombre] = useState("");
  const [descripcion, setDescripcion] = useState("");
  const [activo, setActivo] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);
  const [guardando, setGuardando] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setOk(false);
    if (!nombre.trim()) {
      setError("El nombre es obligatorio.");
      return;
    }
    setGuardando(true);
    try {
      await crearEjercicio({
        bloque,
        plantilla_tipo: plantilla,
        nombre: nombre.trim(),
        descripcion: descripcion.trim() || null,
        parametros_json: {},
        activo,
      });
      setOk(true);
      setNombre("");
      setDescripcion("");
      onCreado();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "No se pudo crear el ejercicio.");
    } finally {
      setGuardando(false);
    }
  }

  return (
    <Card style={{ marginBottom: 26 }}>
      <h2 style={{ fontSize: 19, marginBottom: 4 }}>Añadir ejercicio</h2>
      <p style={{ color: colors.textMuted, fontSize: 14, marginBottom: 18 }}>
        Se crea sobre una plantilla. Las cantidades concretas de cada tirada las genera el motor
        automáticamente al usarlo en la tablet.
      </p>

      <form onSubmit={onSubmit}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))", gap: "0 20px" }}>
          <Field label="Bloque cognitivo" htmlFor="f-bloque">
            <select id="f-bloque" value={bloque} onChange={(e) => setBloque(e.target.value)} style={inputStyle}>
              {BLOQUES.map((b) => (
                <option key={b} value={b}>{labelBloque(b)}</option>
              ))}
            </select>
          </Field>

          <Field label="Plantilla" htmlFor="f-plantilla">
            <select id="f-plantilla" value={plantilla} onChange={(e) => setPlantilla(e.target.value)} style={inputStyle}>
              {PLANTILLAS.map((p) => (
                <option key={p} value={p}>{labelPlantilla(p)}</option>
              ))}
            </select>
          </Field>
        </div>

        <Field label="Nombre" htmlFor="f-nombre">
          <input
            id="f-nombre"
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            style={inputStyle}
            placeholder="p. ej. Sigue la línea"
            required
          />
        </Field>

        <Field label="Descripción (opcional)" htmlFor="f-desc">
          <input
            id="f-desc"
            value={descripcion}
            onChange={(e) => setDescripcion(e.target.value)}
            style={inputStyle}
            placeholder="Una frase que explique el ejercicio"
          />
        </Field>

        <label style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18, fontSize: 14.5 }}>
          <input type="checkbox" checked={activo} onChange={(e) => setActivo(e.target.checked)} style={{ width: 18, height: 18 }} />
          Disponible para usar desde ya
        </label>

        {error && (
          <div role="alert" style={{ background: colors.alertBg, border: `1px solid ${colors.coral}`, color: colors.coralDark, borderRadius: radius.sm, padding: "10px 12px", fontSize: 14, marginBottom: 14 }}>
            {error}
          </div>
        )}
        {ok && (
          <div role="status" aria-live="polite" style={{ background: "rgba(124,152,133,0.16)", border: `1px solid ${colors.sage}`, color: colors.sageDark, borderRadius: radius.sm, padding: "10px 12px", fontSize: 14, marginBottom: 14 }}>
            Ejercicio creado correctamente.
          </div>
        )}

        <Button type="submit" disabled={guardando}>
          {guardando ? "Guardando…" : "Crear ejercicio"}
        </Button>
      </form>
    </Card>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th scope="col" style={{ padding: "12px 16px", fontWeight: 600 }}>{children}</th>;
}
function Td({ children }: { children: React.ReactNode }) {
  return <td style={{ padding: "12px 16px", verticalAlign: "top" }}>{children}</td>;
}
