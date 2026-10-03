import 'package:flutter/material.dart';

/// Couleurs de l'application : vert et rouge du drapeau marocain, sable chaud des panneaux,
/// encre bleu nuit pour le texte (contraste supérieur à 4,5:1 sur le sable et le blanc).
class AppColors {
  static const ink = Color(0xFF14213D);
  static const taxiRed = Color(0xFFC1272D);
  static const moroccoGreen = Color(0xFF006233);
  static const greenSoft = Color(0xFFE3F0E8);
  static const redSoft = Color(0xFFFBEAEA);
  static const sand = Color(0xFFF7F1E3);
  static const sandDeep = Color(0xFFEFE5CF);
  static const gold = Color(0xFFB8892B);
  static const surface = Colors.white;
  static const muted = Color(0xFF575E6E);
  static const line = Color(0xFFE5DAC2);
  static const grandTaxi = Color(0xFFE8E2D0);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.moroccoGreen,
      primary: AppColors.moroccoGreen,
      secondary: AppColors.taxiRed,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.sand,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.sand,
      surfaceTintColor: AppColors.sand,
      foregroundColor: AppColors.ink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.moroccoGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor:
          WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.moroccoGreen : null),
    ),
  );
}
