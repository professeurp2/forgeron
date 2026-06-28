import 'package:flutter/material.dart';
import 'theme_provider.dart';
import 'forgeron_theme_extension.dart';

export 'forgeron_theme_extension.dart';
export 'app_text_styles.dart';

class AppColors {
  // Raccourci vers le thème courant (mis à jour globalement lors du changement)
  static ForgeronTheme get _current => ThemeManager.current;

  // ── BACKGROUNDS ─────────────────────────────────────────────────────────────
  static Color get background => _current.background;
  static Color get sidebar => _current.sidebar;
  static Color get surface => _current.surface;
  static Color get surfaceBright => _current.surfaceBright;
  static Color get surfaceHigh => _current.surfaceHigh;
  static Color get surfaceBorder => _current.surfaceBorder;
  static Color get surfaceBorderDim => _current.surfaceBorderDim;
  static Color get terminalBg => _current.terminalBg;

  // ── BRAND PRIMARY ───────────────────────────────────────────────────────────
  static Color get primary => _current.primary;
  static Color get primaryDim => _current.primaryDim;
  static Color get primaryLight => _current.primaryLight;
  static Color get secondary => _current.secondary;
  static Color get info => _current.info;

  // ── SEMANTIC ────────────────────────────────────────────────────────────────
  static Color get success => _current.success;
  static Color get warning => _current.warning;
  static Color get danger => _current.danger;
  static Color get error => _current.error;

  // ── AXIS COLORS ─────────────────────────────────────────────────────────────
  static Color get axisX => _current.axisX;
  static Color get axisY => _current.axisY;
  static Color get axisZ => _current.axisZ;
  static Color get axisA => _current.axisA;
  static Color get axisC => _current.axisC;

  // ── TEXT ────────────────────────────────────────────────────────────────────
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textDisabled => _current.textDisabled;

  // ── GLASS / BORDERS ─────────────────────────────────────────────────────────
  static Color get glassBorder => _current.glassBorder;
  static Color get glassSurface => _current.glassSurface;

  // ── CNC PANEL ───────────────────────────────────────────────────────────────
  static Color get lcdBackground => _current.lcdBackground;
  static Color get lcdText => _current.lcdText;
  static Color get lcdTextDim => _current.lcdTextDim;
  static Color get lcdBorder => _current.lcdBorder;
  static Color get keyBezel => _current.keyBezel;
  static Color get keyActive => _current.keyActive;
  static Color get keyBorder => _current.keyBorder;
  static Color get panelBody => _current.panelBody;
  static Color get panelSection => _current.panelSection;

  // ── STATUS LEDS ─────────────────────────────────────────────────────────────
  static Color get ledGreen => _current.ledGreen;
  static Color get ledOrange => _current.ledOrange;
  static Color get ledRed => _current.ledRed;
  static Color get ledBlue => _current.ledBlue;
  static Color get ledPurple => _current.ledPurple;
}
