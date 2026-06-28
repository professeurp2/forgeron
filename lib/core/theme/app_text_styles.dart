import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'forgeron_theme_extension.dart';

class AppTextStyles {
  static const String _rajdhani = 'Rajdhani';
  static const String _jetBrains = 'JetBrainsMono';

  // ── HEADLINES ────────────────────────────────────────────────────────────
  static TextStyle get headline => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      );

  static TextStyle get headlineSmall => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );

  // ── NAVIGATION ────────────────────────────────────────────────────────────
  static TextStyle get navLabel => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      );

  static TextStyle get navLabelSelected => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      );

  // ── SECTION HEADERS ───────────────────────────────────────────────────────
  static TextStyle get sectionTitle => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      );

  static TextStyle sectionAccent(Color color) => TextStyle(
        fontFamily: _rajdhani,
        color: color.withValues(alpha: 0.9),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      );

  // ── BOUTONS ───────────────────────────────────────────────────────────────
  static TextStyle get buttonLabel => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  static TextStyle get buttonDanger => const TextStyle(
        fontFamily: _rajdhani,
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      );

  // ── BADGES / STATUT ───────────────────────────────────────────────────────
  static TextStyle statusBadge(Color color) => TextStyle(
        fontFamily: _rajdhani,
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      );

  static TextStyle get chipLabel => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      );

  // ── DRO — AFFICHAGE NUMÉRIQUE ─────────────────────────────────────────────
  static TextStyle get dro => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.lcdText,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      );

  static TextStyle get droMedium => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.lcdText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      );

  static TextStyle get droLabel => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
      );

  static TextStyle get droDim => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.lcdTextDim,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.0,
      );

  // ── TERMINAL / GCODE ──────────────────────────────────────────────────────
  static TextStyle get terminalOutput => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.lcdText,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.6,
      );

  static TextStyle get terminalInput => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  static TextStyle get terminalComment => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.textDisabled,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
      );

  // ── GENERAL ───────────────────────────────────────────────────────────────
  static TextStyle get body => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodySecondary => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: _rajdhani,
        color: AppColors.textDisabled,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      );

  static TextStyle get mono => TextStyle(
        fontFamily: _jetBrains,
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      );

  // ── TextTheme MATERIAL ────────────────────────────────────────────────────
  static TextTheme createMaterialTextTheme(ForgeronTheme themeColors) {
    return TextTheme(
      displayLarge: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1.5),
      headlineMedium: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      headlineSmall: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.0),
      titleMedium: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      bodyLarge:
          TextStyle(fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 14),
      bodyMedium:
          TextStyle(fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 13),
      bodySmall:
          TextStyle(fontFamily: _rajdhani, color: themeColors.textSecondary, fontSize: 12),
      labelLarge: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0),
      labelMedium: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textSecondary, fontSize: 11, letterSpacing: 0.8),
      labelSmall: TextStyle(
          fontFamily: _rajdhani, color: themeColors.textDisabled, fontSize: 10, letterSpacing: 1.5),
    );
  }
}
