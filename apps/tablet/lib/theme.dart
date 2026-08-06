import 'package:flutter/material.dart';

/// Paleta compartida con la presentación del proyecto (marfil/salvia/coral).
class TrazoColors {
  static const ivory = Color(0xFFFAF6EF);
  static const card = Color(0xFFF2ECDF);
  static const ink = Color(0xFF2B3A32);
  static const sage = Color(0xFF7C9885);
  static const sageDark = Color(0xFF5C7A66);
  static const coral = Color(0xFFE8A87C);
  static const coralDark = Color(0xFFC97B4A);
  static const sand = Color(0xFFC9BFA4);
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
        backgroundColor: TrazoColors.sage,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
