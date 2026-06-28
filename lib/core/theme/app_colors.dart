import 'package:flutter/material.dart';

/// Design System "Forge Noire" — Palette industrielle premium Forgeron v2
/// Inspiré de Mazak SmoothAi + cockpit automobile 2025
class AppColors {
  AppColors._();

  // ── BACKGROUNDS ─────────────────────────────────────────────────────────────
  static const Color background    = Color(0xFF0D0F14); // fond principal ultra-sombre
  static const Color sidebar       = Color(0xFF10131A); // sidebar légèrement plus clair
  static const Color surface       = Color(0xFF161922); // cartes / sections
  static const Color surfaceBright = Color(0xFF1E2230); // cartes élevées
  static const Color surfaceHigh   = Color(0xFF252B3B); // survol / sélection
  static const Color surfaceBorder = Color(0xFF2A2F3E); // bordures nettes (opaque)
  static const Color surfaceBorderDim = Color(0x332A2F3E); // bordures discrètes
  static const Color terminalBg    = Color(0xFF080A10);

  // ── BRAND PRIMARY ───────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFFFF6B35); // orange forgeron (accentuation principale)
  static const Color primaryDim    = Color(0xFFCC5220);
  static const Color primaryLight  = Color(0xFFFF9A6C);
  static const Color secondary     = Color(0xFF00D4FF); // cyan info
  static const Color info          = Color(0xFF3B82F6); // bleu doux

  // ── SEMANTIC ────────────────────────────────────────────────────────────────
  static const Color success       = Color(0xFF00C851); // vert vif
  static const Color warning       = Color(0xFFFFB703); // ambre
  static const Color danger        = Color(0xFFE63946); // rouge danger
  static const Color error         = Color(0xFFFF5472);

  // ── AXIS COLORS ─────────────────────────────────────────────────────────────
  static const Color axisX         = Color(0xFFFF4757); // rouge X
  static const Color axisY         = Color(0xFF2ED573); // vert Y
  static const Color axisZ         = Color(0xFF3B82F6); // bleu Z
  static const Color axisA         = Color(0xFFFF6B35); // orange A (=primary, cohérent)
  static const Color axisC         = Color(0xFF00D4FF); // cyan C (= secondary, cohérent)

  // ── TEXT ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F2FF);
  static const Color textSecondary = Color(0xFFA0A8C0);
  static const Color textDisabled  = Color(0xFF4A5068);

  // ── GLASS / BORDERS ─────────────────────────────────────────────────────────
  static const Color glassBorder   = Color(0x22FFFFFF);
  static const Color glassSurface  = Color(0x1AFFFFFF);

  // ── CNC PANEL ───────────────────────────────────────────────────────────────
  static const Color lcdBackground = Color(0xFF080E04);
  static const Color lcdText       = Color(0xFF39FF14);
  static const Color lcdTextDim    = Color(0xFF1A7A08);
  static const Color lcdBorder     = Color(0xFF0D2A0A);
  static const Color keyBezel      = Color(0xFF181E2E);
  static const Color keyActive     = Color(0xFF242D45);
  static const Color keyBorder     = Color(0xFF2E3A5C);
  static const Color panelBody     = Color(0xFF0D0F14);
  static const Color panelSection  = Color(0xFF13182A);

  // ── STATUS LEDS ─────────────────────────────────────────────────────────────
  static const Color ledGreen      = Color(0xFF00C851);
  static const Color ledOrange     = Color(0xFFFFB703);
  static const Color ledRed        = Color(0xFFE63946);
  static const Color ledBlue       = Color(0xFF00D4FF);
  static const Color ledPurple     = Color(0xFF8B5CF6);
}
