/**
 * Documento de CONSENTIMIENTO INFORMADO imprimible y AUTORRELLENADO (centro,
 * persona, fecha, versión), listo para imprimir/guardar como PDF y firmar.
 *
 * IMPORTANTE: el texto es un BORRADOR basado en `legal/02-consentimiento-informado.md`.
 * Debe revisarlo un abogado/DPO antes de usarlo con datos reales. Aquí queda el
 * MECANISMO montado: al cambiar el texto final, solo se edita este componente.
 *
 * Reutiliza el patrón de impresión de los informes (clase `.trazo-doc` + reglas
 * `@media print` de index.css): al montarse (portal a body) se imprime solo este
 * documento y se oculta el resto de la app.
 */
import { useEffect } from "react";
import { createPortal } from "react-dom";

/** Versión del texto de consentimiento. Súbela cuando cambie el contenido legal. */
export const VERSION_CONSENTIMIENTO = "v1-borrador";

const TITULO: Record<string, string> = {
  uso_y_seguimiento: "Consentimiento informado · Uso y seguimiento",
  imagen: "Consentimiento informado · Uso de imagen",
};

export function ConsentimientoImprimible({
  centro,
  personaAlias,
  tipo = "uso_y_seguimiento",
  onHecho,
}: {
  centro: string;
  personaAlias: string;
  tipo?: string;
  onHecho: () => void;
}) {
  const hoy = new Date().toLocaleDateString("es-ES", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });

  useEffect(() => {
    const alTerminar = () => onHecho();
    window.addEventListener("afterprint", alTerminar);
    // Espera un frame a que pinte antes de abrir el diálogo de impresión.
    const t = window.setTimeout(() => window.print(), 150);
    return () => {
      window.clearTimeout(t);
      window.removeEventListener("afterprint", alTerminar);
    };
  }, [onHecho]);

  const linea = { borderBottom: "1px solid #333", minWidth: 220, display: "inline-block" as const };

  return createPortal(
    <div
      className="trazo-doc"
      style={{
        fontFamily: "Georgia, 'Times New Roman', serif",
        color: "#111",
        fontSize: 12.5,
        lineHeight: 1.5,
      }}
    >
      <div
        style={{
          background: "#FFF3CD",
          border: "1px solid #E0B000",
          padding: "6px 10px",
          fontSize: 11,
          marginBottom: 14,
        }}
      >
        BORRADOR — pendiente de revisión por asesoría legal / DPO antes de su uso
        con datos reales. {VERSION_CONSENTIMIENTO}
      </div>

      <h1 style={{ fontSize: 18, margin: "0 0 4px" }}>{TITULO[tipo] ?? TITULO.uso_y_seguimiento}</h1>
      <p style={{ margin: "0 0 14px", fontSize: 11.5, color: "#444" }}>
        Fecha: {hoy} · Centro: <strong>{centro || "__________________"}</strong> ·
        Referencia interna de la persona: <strong>{personaAlias}</strong>
      </p>

      <h2 style={{ fontSize: 13 }}>1. Responsable y encargado</h2>
      <p>
        <strong>Responsable del tratamiento:</strong> {centro || "__________________"} (el
        centro). <strong>Encargado del tratamiento:</strong> Trazo, que trata los datos
        únicamente siguiendo las instrucciones del centro y para prestar el servicio.
      </p>

      <h2 style={{ fontSize: 13 }}>2. Finalidad</h2>
      <p>
        Registrar el <strong>desempeño</strong> de la persona usuaria en actividades de
        estimulación cognitiva en tablet y avisar de cambios para que un profesional los
        revise. <strong>No es un diagnóstico ni un producto sanitario</strong> y no
        sustituye la valoración clínica.
      </p>

      <h2 style={{ fontSize: 13 }}>3. Datos y protección</h2>
      <p>
        Se tratan datos identificativos (de forma <strong>pseudonimizada</strong>: se usa
        un alias interno y el nombre real se guarda por separado, con acceso restringido) y
        datos de desempeño en las actividades (categoría especial — salud). Los datos se
        conservan mientras dure la relación con el centro y el plazo legal aplicable, y se
        suprimen o anonimizan después. Medidas de seguridad: cifrado en tránsito y en
        reposo, control de accesos por rol y registro de auditoría.
      </p>

      <h2 style={{ fontSize: 13 }}>4. Derechos</h2>
      <p>
        La persona (o su representante) puede ejercer los derechos de acceso, rectificación,
        supresión, limitación, oposición y portabilidad, y <strong>retirar este
        consentimiento en cualquier momento sin consecuencias asistenciales</strong>,
        dirigiéndose al centro. La participación es <strong>voluntaria</strong>.
      </p>

      <h2 style={{ fontSize: 13 }}>5. Consentimiento</h2>
      <p>
        Declaro haber sido informado/a de lo anterior y <strong>consiento</strong> el
        tratamiento descrito.
      </p>

      <div style={{ marginTop: 26, display: "flex", gap: 40, flexWrap: "wrap" }}>
        <div style={{ flex: "1 1 240px" }}>
          <p style={{ margin: "0 0 22px" }}>Firma de la persona usuaria:</p>
          <p style={{ margin: "0 0 10px" }}>Nombre y apellidos: <span style={linea} /></p>
          <p style={{ margin: "0 0 10px" }}>DNI/NIE: <span style={{ ...linea, minWidth: 140 }} /></p>
          <p style={{ margin: 0 }}>Firma y fecha:</p>
        </div>
        <div style={{ flex: "1 1 240px" }}>
          <p style={{ margin: "0 0 22px" }}>
            Si firma un representante (representante legal / tutor/a / guardador/a de hecho):
          </p>
          <p style={{ margin: "0 0 10px" }}>Nombre y apellidos: <span style={linea} /></p>
          <p style={{ margin: "0 0 10px" }}>DNI/NIE: <span style={{ ...linea, minWidth: 140 }} /></p>
          <p style={{ margin: "0 0 10px" }}>En calidad de: <span style={{ ...linea, minWidth: 160 }} /></p>
          <p style={{ margin: 0 }}>Firma y fecha:</p>
        </div>
      </div>

      <p style={{ marginTop: 26, fontSize: 10.5, color: "#666" }}>
        Documento generado por Trazo el {hoy}. Conserve el original firmado; puede
        registrarse su referencia (y adjuntarse) en el panel del centro.
      </p>
    </div>,
    document.body,
  );
}
