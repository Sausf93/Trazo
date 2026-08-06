/** Logo de marca de Trazo — el MISMO en toda la app (panel, tablet, web comercial).
 *  Azulejo salvia con un trazo que empieza tembloroso y termina firme (punto coral). */
import { colors, fonts } from "../theme";

export function Logo({
  size = 30,
  textSize = 26,
  showText = true,
}: {
  size?: number;
  textSize?: number;
  showText?: boolean;
}) {
  return (
    <div style={{ display: "inline-flex", alignItems: "center", gap: 10 }}>
      <svg width={size} height={size} viewBox="0 0 40 40" aria-label="Trazo" role="img">
        <rect width="40" height="40" rx="11" fill="#7C9885" />
        <path
          d="M7 26 C11 14 15 30 20 22 C24 16 27 24 33 15"
          fill="none"
          stroke="#FFFEFB"
          strokeWidth="3"
          strokeLinecap="round"
        />
        <circle cx="33" cy="15" r="2.6" fill="#E8A87C" />
      </svg>
      {showText && (
        <span style={{ fontFamily: fonts.serif, fontSize: textSize, fontWeight: 600, color: colors.ink }}>
          Trazo
        </span>
      )}
    </div>
  );
}
