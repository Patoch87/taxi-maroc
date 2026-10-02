import 'package:flutter/material.dart';

/// Couleurs de l'application : sobre (noir et blanc) avec le rouge des petits taxis de Casablanca.
class AppColors {
  static const ink = Color(0xFF111111);
  static const taxiRed = Color(0xFFC1272D);
  static const moroccoGreen = Color(0xFF006233);
  static const surface = Colors.white;
  static const muted = Color(0xFF6B6B6B);
  static const line = Color(0xFFEDEDED);
  static const grandTaxi = Color(0xFFE8E2D0);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      secondary: AppColors.taxiRed,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
