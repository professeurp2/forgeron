import 'package:flutter/material.dart';
import 'forgeron_colors.dart';

/// Thème MaterialApp global pour Forgeron — Design System « Forge Titanium & Magma v3 ».
/// Supporte les modes Sombre et Clair.
abstract class AppTheme {
  static TextTheme _buildTextTheme(ForgeronColorPalette c) {
    const tabular = [FontFeature.tabularFigures()];
    return TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Rajdhani',
        color: c.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Rajdhani',
        color: c.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Rajdhani',
        color: c.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Rajdhani',
        color: c.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Rajdhani',
        color: c.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      bodyLarge: TextStyle(
        color: c.textPrimary,
        fontSize: 14,
        fontFeatures: tabular,
      ),
      bodyMedium: TextStyle(
        color: c.textPrimary,
        fontSize: 13,
        fontFeatures: tabular,
      ),
      bodySmall: TextStyle(
        color: c.textSecondary,
        fontSize: 12,
        fontFeatures: tabular,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Rajdhani',
        color: c.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }

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
      fontFamily: 'JetBrains Mono',
      textTheme: _buildTextTheme(forgeronDarkColors),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forgeronDarkColors.primary,
          foregroundColor: forgeronDarkColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
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
      fontFamily: 'JetBrains Mono',
      textTheme: _buildTextTheme(forgeronLightColors),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forgeronLightColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
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
