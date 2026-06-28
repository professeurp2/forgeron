import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Système de typographie centralisé — Forgeron v2
///
/// Polices :
///   • Rajdhani     — Labels, titres, navigation  (look industriel premium)
///   • JetBrains Mono — DRO, terminal, valeurs numériques  (lisibilité maximale)
abstract class AppTextStyles {
  AppTextStyles._();

  // ── HEADLINES (Rajdhani) ──────────────────────────────────────────────────

  /// Titre d'écran principal — ex: "TABLEAU DE BORD"
  static TextStyle get headline => GoogleFonts.rajdhani(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      );

  /// Sous-titre de section — ex: "AXES DRO"
  static TextStyle get headlineSmall => GoogleFonts.rajdhani(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );

  // ── NAVIGATION (Rajdhani) ─────────────────────────────────────────────────

  /// Label de la sidebar desktop
  static TextStyle get navLabel => GoogleFonts.rajdhani(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      );

  /// Label de la sidebar sélectionné
  static TextStyle get navLabelSelected => GoogleFonts.rajdhani(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      );

  // ── SECTION HEADERS (Rajdhani) ────────────────────────────────────────────

  /// En-tête d'un GlassPanel — "AXES LINÉAIRES"
  static TextStyle get sectionTitle => GoogleFonts.rajdhani(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      );

  /// Label d'axe coloré dans un GlassPanel
  static TextStyle sectionAccent(Color color) => GoogleFonts.rajdhani(
        color: color.withValues(alpha: 0.9),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      );

  // ── BOUTONS (Rajdhani) ────────────────────────────────────────────────────

  /// Texte d'un bouton d'action CNC
  static TextStyle get buttonLabel => GoogleFonts.rajdhani(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  /// Texte d'un bouton d'urgence / danger
  static TextStyle get buttonDanger => GoogleFonts.rajdhani(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      );

  // ── BADGES / STATUT (Rajdhani) ─────────────────────────────────────────────

  /// Badge de statut machine — "IDLE", "RUN", "ALARM"
  static TextStyle statusBadge(Color color) => GoogleFonts.rajdhani(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      );

  /// Label d'un chip / tag
  static TextStyle get chipLabel => GoogleFonts.rajdhani(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      );

  // ── DRO — AFFICHAGE NUMÉRIQUE (JetBrains Mono) ──────────────────────────

  /// Grande valeur DRO — coordonnée principale
  static TextStyle get dro => GoogleFonts.jetBrainsMono(
        color: AppColors.lcdText,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      );

  /// Valeur DRO moyenne — coordonnées secondaires
  static TextStyle get droMedium => GoogleFonts.jetBrainsMono(
        color: AppColors.lcdText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      );

  /// Label d'un axe DRO — "X", "Y", "Z"
  static TextStyle get droLabel => GoogleFonts.jetBrainsMono(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
      );

  /// Valeur DRO atténuée (valeur machine vs programme)
  static TextStyle get droDim => GoogleFonts.jetBrainsMono(
        color: AppColors.lcdTextDim,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.0,
      );

  // ── TERMINAL / GCODE (JetBrains Mono) ─────────────────────────────────────

  /// Sortie terminal MDI / FluidNC
  static TextStyle get terminalOutput => GoogleFonts.jetBrainsMono(
        color: AppColors.lcdText,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.6,
      );

  /// Entrée commande terminal
  static TextStyle get terminalInput => GoogleFonts.jetBrainsMono(
        color: AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  /// Commentaire G-code
  static TextStyle get terminalComment => GoogleFonts.jetBrainsMono(
        color: AppColors.textDisabled,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
      );

  // ── GENERAL (Rajdhani) ────────────────────────────────────────────────────

  /// Corps de texte standard
  static TextStyle get body => GoogleFonts.rajdhani(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      );

  /// Texte de corps secondaire / description
  static TextStyle get bodySecondary => GoogleFonts.rajdhani(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  /// Caption / légende d'image ou de widget
  static TextStyle get caption => GoogleFonts.rajdhani(
        color: AppColors.textDisabled,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      );

  /// Valeur numérique monospace générique (IP, durée, taille fichier...)
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w400,
      );

  // ── TextTheme MATERIAL — à brancher dans ThemeData ────────────────────────

  /// TextTheme complet à passer à ThemeData pour Rajdhani comme font globale.
  static TextTheme get materialTextTheme => GoogleFonts.rajdhaniTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
          headlineMedium: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2),
          headlineSmall: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
          titleLarge: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0),
          titleMedium: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8),
          bodyLarge: TextStyle(
              color: AppColors.textPrimary, fontSize: 14),
          bodyMedium: TextStyle(
              color: AppColors.textPrimary, fontSize: 13),
          bodySmall: TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
          labelLarge: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0),
          labelMedium: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 0.8),
          labelSmall: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10,
              letterSpacing: 1.5),
        ),
      );
}
