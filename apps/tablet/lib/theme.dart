import 'package:flutter/material.dart';

/// Paleta oficial "Aqua Green" (elegida por Saulo). Verde agua fresco de marca
/// con acento coral cálido. Los nombres (sage/coral…) se conservan por
/// compatibilidad; los valores son los de la paleta Aqua Green.
class TrazoColors {
  static const ivory = Color(0xFFF5FBFA);
  static const card = Color(0xFFE8F5F2);
  static const ink = Color(0xFF12312E);
  static const sage = Color(0xFF12A99B);
  static const sageDark = Color(0xFF1F7A70); // blanco encima ≈5.1:1 (AA ✓)
  static const coral = Color(0xFFF08A6B);
  static const coralDark = Color(0xFFC4553A);
  static const sand = Color(0xFFD2E6E2);
  static const white = Color(0xFFFFFEFB);
}

ThemeData buildTrazoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TrazoColors.sage,
      primary: TrazoColors.sage,
      secondary: TrazoColors.coral,
      surface: TrazoColors.ivory,
    ),
    scaffoldBackgroundColor: TrazoColors.ivory,
  );
  return base.copyWith(
    // Solo color aquí. El aumento de tamaño para público mayor se hace con un
    // textScaler global en main.dart (aplicar `fontSizeFactor` sobre el
    // textTheme base dispara un assert cuando algún estilo tiene fontSize null).
    textTheme: base.textTheme.apply(
      bodyColor: TrazoColors.ink,
      displayColor: TrazoColors.ink,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // sageDark (no sage): blanco sobre sage daba ~3.1:1 (falla AA); sobre
        // sageDark sube a ~4.6:1, legible para 80+ con baja visión.
        backgroundColor: TrazoColors.sageDark,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
