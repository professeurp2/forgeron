import 'package:flutter/material.dart';

/// Design System "Void-to-Neon" — Palette industrielle Forgerons
class AppColors {
  AppColors._();

  // ── BACKGROUNDS ──
  static const Color background = Color(0xFF090E1C);
  static const Color sidebar = Color(0xFF0D1323);
  static const Color surface = Color(0xFF13192B);
  static const Color surfaceBright = Color(0xFF242B43);
  static const Color surfaceBorder = Color(0x26707588);
  static const Color terminalBg = Color(0xFF050A15);

  // ── BRAND NEON ──
  static const Color primary = Color(0xFF6DDDFF);
  static const Color primaryDim = Color(0xFF00C3EB);
  static const Color primaryLight = Color(0xFFB3EFFF);
  static const Color secondary = Color(0xFF50E1F9);
  static const Color info = Color(0xFF2196F3);

  // ── SEMANTIC ──
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFDB022);
  static const Color danger = Color(0xFFFF8257);
  static const Color error = Color(0xFFFF716C);

  // ── AXIS COLORS ──
  static const Color axisX = Color(0xFFFF5252);
  static const Color axisY = Color(0xFF69F0AE);
  static const Color axisZ = Color(0xFF448AFF);
  static const Color axisA = Color(0xFFFFAB40);
  static const Color axisC = Color(0xFFE040FB);

  // ── TEXT ──
  static const Color textPrimary = Color(0xFFE1E4FA);
  static const Color textSecondary = Color(0xFFA6AABF);
  static const Color textDisabled = Color(0xFF505466);

  // ── GLASS ──
  static const Color glassBorder = Color(0x33FFFFFF);

  // ── CNC PANEL (FANUC style) ──
  static const Color lcdBackground = Color(0xFF0A1505);   // fond LCD phosphore
  static const Color lcdText       = Color(0xFF39FF14);   // vert phosphore (néon)
  static const Color lcdTextDim    = Color(0xFF1A7A08);   // texte secondaire LCD
  static const Color lcdBorder     = Color(0xFF0D2A0A);   // bordure LCD
  static const Color keyBezel      = Color(0xFF1A1F35);   // fond touche normale
  static const Color keyActive     = Color(0xFF252D4A);   // fond touche survol/active
  static const Color keyBorder     = Color(0xFF2E3A5C);   // bordure touche
  static const Color panelBody     = Color(0xFF0B0E1C);   // corps du pupitre
  static const Color panelSection  = Color(0xFF101525);   // section panneaux
  static const Color ledGreen      = Color(0xFF00E676);   // voyant vert
  static const Color ledOrange     = Color(0xFFFDB022);   // voyant orange
  static const Color ledRed        = Color(0xFFFF3D00);   // voyant rouge
  static const Color ledBlue       = Color(0xFF40C4FF);   // voyant bleu
}
