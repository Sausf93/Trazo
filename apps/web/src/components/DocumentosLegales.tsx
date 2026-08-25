/**
 * Subida/lista/descarga de documentos legales guardados EN LA APP (para no
 * depender del papel ante una auditoría). Reutilizable: por persona
 * (consentimientos firmados) o por centro (DPA / RAT / DPIA).
 */
import { useRef, useState } from "react";
import { borrarDocumento, descargarDocumento, listarDocumentos, subirDocumento } from "../api/endpoints";
import type { DocumentoLegal } from "../api/types";
import { useAsync } from "../hooks/useAsync";
import { Card, Spinner, StateMessage, Button } from "./ui";
import { colors, radius } from "../theme";
import { fmtFecha } from "../utils/format";

type Tipo = { value: string; label: string };

function leerBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => {
      const s = String(r.result);
      resolve(s.includes(",") ? s.slice(s.indexOf(",") + 1) : s); // quita "data:...;base64,"
    };
    r.onerror = () => reject(new Error("No se pudo leer el archivo."));
    r.readAsDataURL(file);
  });
}

function descargar(nombre: string, mime: string, b64: string) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  const url = URL.createObjectURL(new Blob([bytes], { type: mime || "application/octet-stream" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = nombre || "documento";
  a.click();
  URL.revokeObjectURL(url);
}

export function DocumentosLegales({
  usuarioFinalId,
  tipos,
  version,
}: {
  usuarioFinalId?: string; // si se omite, son documentos del CENTRO
  tipos: Tipo[];
  version?: string;
}) {
  const scope = usuarioFinalId ? { usuario_final_id: usuarioFinalId } : { solo_centro: true };
  const docs = useAsync<DocumentoLegal[]>((s) => listarDocumentos(scope, s), [usuarioFinalId ?? "centro"]);
  const [tipo, setTipo] = useState(tipos[0]?.value ?? "otro");
  const [subiendo, setSubiendo] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  async function onArchivo(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    if (file.size > 8 * 1024 * 1024) {
      setError("El archivo supera los 8 MB. Escanéalo en menor calidad o divídelo.");
      if (inputRef.current) inputRef.current.value = "";
      return;
    }
    setSubiendo(true);
    try {
      const contenido_b64 = await leerBase64(file);
      await subirDocumento({
        tipo,
        usuario_final_id: usuarioFinalId ?? null,
        version: version ?? null,
        nombre_archivo: file.name,
        mime: file.type || "application/octet-stream",
        contenido_b64,
      });
      docs.reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo subir el documento.");
    } finally {
      setSubiendo(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  async function onDescargar(id: string) {
    try {
      const d = await descargarDocumento(id);
      descargar(d.nombre_archivo, d.mime, d.contenido_b64);
    } catch {
      setError("No se pudo descargar el documento.");
    }
  }

  async function onBorrar(id: string, nombre: string) {
    if (!window.confirm(`¿Borrar el documento "${nombre}"?`)) return;
    try {
      await borrarDocumento(id);
      docs.reload();
    } catch {
      setError("No se pudo borrar el documento.");
    }
  }

  const labelTipo = (v: string) => tipos.find((t) => t.value === v)?.label ?? v;

  return (
    <div>
      <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap", marginBottom: 12 }}>
        <select value={tipo} onChange={(e) => setTipo(e.target.value)}
          style={{ padding: "8px 10px", borderRadius: radius.sm, border: `1.5px solid ${colors.sand}` }}>
          {tipos.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
        </select>
        <input ref={inputRef} type="file" accept="application/pdf,image/*" onChange={onArchivo}
          style={{ display: "none" }} id={`file-${usuarioFinalId ?? "centro"}`} />
        <Button variant="ghost" disabled={subiendo}
          onClick={() => inputRef.current?.click()}>
          {subiendo ? "Subiendo…" : "Subir documento firmado"}
        </Button>
        <span style={{ fontSize: 12, color: colors.textFaint }}>PDF o foto, hasta 8 MB. Queda guardado en la app.</span>
      </div>

      {error && <div style={{ marginBottom: 10 }}><StateMessage tone="error">{error}</StateMessage></div>}
      {docs.loading && <Spinner label="Cargando documentos…" />}
      {docs.error && <StateMessage tone="error">{docs.error}</StateMessage>}

      {docs.data && docs.data.length === 0 && (
        <p style={{ fontSize: 13.5, color: colors.textMuted }}>Aún no hay documentos subidos.</p>
      )}
      {docs.data && docs.data.length > 0 && (
        <div style={{ display: "grid", gap: 8 }}>
          {docs.data.map((d) => (
            <Card key={d.id} style={{ padding: "10px 14px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap", alignItems: "center" }}>
                <div>
                  <div style={{ fontWeight: 600, color: colors.ink }}>
                    {labelTipo(d.tipo)} <span style={{ fontWeight: 400, color: colors.textMuted }}>· {d.nombre_archivo}</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: colors.textFaint }}>
                    {fmtFecha(d.fecha)} · {(d.tamano / 1024).toFixed(0)} KB · {d.subido_por}
                    {d.version && <> · {d.version}</>}
                  </div>
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <Button variant="ghost" onClick={() => onDescargar(d.id)}>Descargar</Button>
                  <Button variant="ghost" onClick={() => onBorrar(d.id, d.nombre_archivo)}>Borrar</Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
