/**
 * Contrato de ENCARGO DEL TRATAMIENTO (DPA, art. 28 RGPD) imprimible y
 * autorrellenado (centro + fecha), listo para imprimir/guardar como PDF y firmar
 * entre Trazo (encargado) y el centro (responsable).
 *
 * BORRADOR basado en `legal/01-contrato-encargo-tratamiento.md`: debe revisarlo
 * un abogado/DPO antes de firmarlo. Aquí queda el MECANISMO. Reutiliza el patrón
 * de impresión `.trazo-doc` (+ @media print de index.css).
 */
import { useEffect } from "react";
import { createPortal } from "react-dom";

export const VERSION_DPA = "v1-borrador";

export function DpaImprimible({ centro, onHecho }: { centro: string; onHecho: () => void }) {
  const hoy = new Date().toLocaleDateString("es-ES", { day: "2-digit", month: "long", year: "numeric" });

  useEffect(() => {
    const alTerminar = () => onHecho();
    window.addEventListener("afterprint", alTerminar);
    const t = window.setTimeout(() => window.print(), 150);
    return () => {
      window.clearTimeout(t);
      window.removeEventListener("afterprint", alTerminar);
    };
  }, [onHecho]);

  const linea = { borderBottom: "1px solid #333", minWidth: 240, display: "inline-block" as const };
  const clausula = (t: string, c: React.ReactNode) => (
    <p style={{ margin: "6px 0" }}><strong>{t}.</strong> {c}</p>
  );

  return createPortal(
    <div className="trazo-doc" style={{ fontFamily: "Georgia, 'Times New Roman', serif", color: "#111", fontSize: 12, lineHeight: 1.45 }}>
      <div style={{ background: "#FFF3CD", border: "1px solid #E0B000", padding: "6px 10px", fontSize: 11, marginBottom: 12 }}>
        BORRADOR — pendiente de revisión por asesoría legal / DPO antes de firmarlo. {VERSION_DPA}
      </div>

      <h1 style={{ fontSize: 17, margin: "0 0 4px" }}>Contrato de encargo del tratamiento (art. 28 RGPD)</h1>
      <p style={{ margin: "0 0 12px", fontSize: 11.5, color: "#444" }}>Fecha: {hoy}</p>

      <p>
        Entre <strong>{centro || "__________________"}</strong> (el «Responsable del tratamiento», el centro)
        y <strong>Trazo</strong> (el «Encargado del tratamiento»), que presta al centro un servicio de
        estimulación cognitiva y registro de desempeño en tablet.
      </p>

      {clausula("1. Objeto y finalidad", <>El Encargado trata datos personales por cuenta del Responsable con la única finalidad de prestar el servicio: registrar el desempeño de las personas usuarias en actividades y ofrecer su seguimiento. Duración: mientras esté vigente la relación de servicio.</>)}
      {clausula("2. Tipo de datos e interesados", <>Datos identificativos (pseudonimizados: alias interno; el nombre real se guarda por separado) y datos de desempeño en las actividades (categoría especial — salud). Interesados: personas usuarias del centro y profesionales que usan la app.</>)}
      {clausula("3. Instrucciones", <>El Encargado tratará los datos <strong>únicamente siguiendo las instrucciones documentadas</strong> del Responsable y no para fines propios.</>)}
      {clausula("4. Confidencialidad", <>El personal del Encargado con acceso a los datos está sujeto a deber de confidencialidad.</>)}
      {clausula("5. Medidas de seguridad (art. 32)", <>Cifrado en tránsito y en reposo, pseudonimización, control de accesos por rol, aislamiento por centro y registro de auditoría de accesos.</>)}
      {clausula("6. Subencargados", <>El Encargado se apoya en los siguientes subencargados: <strong>Google Cloud (Cloud Run, región Madrid, España)</strong> como alojamiento de la aplicación; <strong>Aiven</strong> como base de datos gestionada (PostgreSQL); y <strong>Cloudflare</strong> para la entrega de los frontends. El tratamiento se realiza en la Unión Europea. El Encargado traslada a estos subencargados las mismas obligaciones de protección de datos e informará de cualquier alta o cambio para que el Responsable pueda oponerse.</>)}
      {clausula("7. Asistencia al Responsable", <>El Encargado ayudará a atender los derechos de los interesados (acceso, rectificación, supresión, etc.) y el cumplimiento de los arts. 32-36.</>)}
      {clausula("8. Brechas de seguridad", <>El Encargado notificará al Responsable, sin dilación indebida, cualquier violación de seguridad de la que tenga conocimiento.</>)}
      {clausula("9. Fin del encargo", <>Al terminar, el Encargado, a elección del Responsable, devolverá o suprimirá los datos y las copias.</>)}
      {clausula("10. Auditorías", <>El Encargado permitirá y contribuirá a las auditorías del Responsable.</>)}
      {clausula("11. Ubicación de los datos y transferencias", <>Los datos se tratan en servidores ubicados en el Espacio Económico Europeo (Madrid, España). Algunos subencargados (Google Cloud, Cloudflare) pertenecen a grupos con matriz en EE. UU.; para cualquier acceso desde fuera del EEE se aplican las garantías del capítulo V del RGPD (cláusulas contractuales tipo y/o el marco EU-US Data Privacy Framework).</>)}

      <div style={{ marginTop: 24, display: "flex", gap: 40, flexWrap: "wrap" }}>
        <div style={{ flex: "1 1 240px" }}>
          <p style={{ margin: "0 0 22px" }}>Por el Responsable (el centro):</p>
          <p style={{ margin: "0 0 10px" }}>Nombre y cargo: <span style={linea} /></p>
          <p style={{ margin: 0 }}>Firma y fecha:</p>
        </div>
        <div style={{ flex: "1 1 240px" }}>
          <p style={{ margin: "0 0 22px" }}>Por el Encargado (Trazo):</p>
          <p style={{ margin: "0 0 10px" }}>Nombre y cargo: <span style={linea} /></p>
          <p style={{ margin: 0 }}>Firma y fecha:</p>
        </div>
      </div>

      <p style={{ marginTop: 24, fontSize: 10.5, color: "#666" }}>
        Documento generado por Trazo el {hoy}. Conserve el original firmado; puede adjuntarse en el panel
        (Cumplimiento) para tenerlo disponible ante una auditoría.
      </p>
    </div>,
    document.body,
  );
}
