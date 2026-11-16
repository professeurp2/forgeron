import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'forgeron_colors.dart';

/// Thème MaterialApp global pour Forgeron.
/// Supporte les modes Sombre et Clair.
abstract class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: forgeronDarkColors.background,
      colorScheme: ColorScheme.dark(
        primary: forgeronDarkColors.primary,
        secondary: forgeronDarkColors.secondary,
        surface: forgeronDarkColors.surface,
        error: forgeronDarkColors.danger,
      ),
      fontFamily: 'RobotoMono',
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: forgeronDarkColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        headlineMedium: TextStyle(
          color: forgeronDarkColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: forgeronDarkColors.textPrimary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: forgeronDarkColors.textSecondary,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: forgeronDarkColors.textSecondary,
          fontSize: 10,
          letterSpacing: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forgeronDarkColors.primary,
          foregroundColor: forgeronDarkColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      iconTheme: IconThemeData(
        color: forgeronDarkColors.textSecondary,
        size: 20,
      ),
      dividerColor: forgeronDarkColors.surfaceBorder,
      useMaterial3: true,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: forgeronLightColors.background,
      colorScheme: ColorScheme.light(
        primary: forgeronLightColors.primary,
        secondary: forgeronLightColors.secondary,
        surface: forgeronLightColors.surface,
        error: forgeronLightColors.danger,
      ),
      fontFamily: 'RobotoMono',
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: forgeronLightColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        headlineMedium: TextStyle(
          color: forgeronLightColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: forgeronLightColors.textPrimary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: forgeronLightColors.textSecondary,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: forgeronLightColors.textSecondary,
          fontSize: 10,
          letterSpacing: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forgeronLightColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      iconTheme: IconThemeData(
        color: forgeronLightColors.textSecondary,
        size: 20,
      ),
      dividerColor: forgeronLightColors.surfaceBorder,
      useMaterial3: true,
    );
  }
}
