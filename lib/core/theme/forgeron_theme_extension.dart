import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ForgeronTheme — Extension ThemeData pour TOUTES les couleurs de l'application.
// ═══════════════════════════════════════════════════════════════════════════════

class ForgeronTheme extends ThemeExtension<ForgeronTheme> {
  // ── BACKGROUNDS ─────────────────────────────────────────────────────────────
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceHigh;
  final Color surfaceBorder;
  final Color surfaceBorderDim;
  final Color terminalBg;

  // ── BRAND PRIMARY ───────────────────────────────────────────────────────────
  final Color primary;
  final Color primaryDim;
  final Color primaryLight;
  final Color secondary;
  final Color info;

  // ── SEMANTIC ────────────────────────────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color danger;
  final Color error;

  // ── AXIS COLORS ─────────────────────────────────────────────────────────────
  final Color axisX;
  final Color axisY;
  final Color axisZ;
  final Color axisA;
  final Color axisC;

  // ── TEXT ────────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // ── GLASS / BORDERS ─────────────────────────────────────────────────────────
  final Color glassBorder;
  final Color glassSurface;

  // ── CNC PANEL ───────────────────────────────────────────────────────────────
  final Color lcdBackground;
  final Color lcdText;
  final Color lcdTextDim;
  final Color lcdBorder;
  final Color keyBezel;
  final Color keyActive;
  final Color keyBorder;
  final Color panelBody;
  final Color panelSection;

  // ── STATUS LEDS ─────────────────────────────────────────────────────────────
  final Color ledGreen;
  final Color ledOrange;
  final Color ledRed;
  final Color ledBlue;
  final Color ledPurple;

  const ForgeronTheme({
    required this.background,
    required this.sidebar,
    required this.surface,
    required this.surfaceBright,
    required this.surfaceHigh,
    required this.surfaceBorder,
    required this.surfaceBorderDim,
    required this.terminalBg,
    required this.primary,
    required this.primaryDim,
    required this.primaryLight,
    required this.secondary,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.error,
    required this.axisX,
    required this.axisY,
    required this.axisZ,
    required this.axisA,
    required this.axisC,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.glassBorder,
    required this.glassSurface,
    required this.lcdBackground,
    required this.lcdText,
    required this.lcdTextDim,
    required this.lcdBorder,
    required this.keyBezel,
    required this.keyActive,
    required this.keyBorder,
    required this.panelBody,
    required this.panelSection,
    required this.ledGreen,
    required this.ledOrange,
    required this.ledRed,
    required this.ledBlue,
    required this.ledPurple,
  });

  /// Thème "Forge Noire" (Dark industriel)
  static const ForgeronTheme dark = ForgeronTheme(
    background: Color(0xFF0D0F14),
    sidebar: Color(0xFF10131A),
    surface: Color(0xFF161922),
    surfaceBright: Color(0xFF1E2230),
    surfaceHigh: Color(0xFF252B3B),
    surfaceBorder: Color(0xFF2A2F3E),
    surfaceBorderDim: Color(0x332A2F3E),
    terminalBg: Color(0xFF080A10),
    primary: Color(0xFFFF6B35),
    primaryDim: Color(0xFFCC5220),
    primaryLight: Color(0xFFFF9A6C),
    secondary: Color(0xFF00D4FF),
    info: Color(0xFF3B82F6),
    success: Color(0xFF00C851),
    warning: Color(0xFFFFB703),
    danger: Color(0xFFE63946),
    error: Color(0xFFFF5472),
    axisX: Color(0xFFFF4757),
    axisY: Color(0xFF2ED573),
    axisZ: Color(0xFF3B82F6),
    axisA: Color(0xFFFF6B35),
    axisC: Color(0xFF00D4FF),
    textPrimary: Color(0xFFF0F2FF),
    textSecondary: Color(0xFFA0A8C0),
    textDisabled: Color(0xFF4A5068),
    glassBorder: Color(0x22FFFFFF),
    glassSurface: Color(0x1AFFFFFF),
    lcdBackground: Color(0xFF080E04),
    lcdText: Color(0xFF39FF14),
    lcdTextDim: Color(0xFF1A7A08),
    lcdBorder: Color(0xFF0D2A0A),
    keyBezel: Color(0xFF181E2E),
    keyActive: Color(0xFF242D45),
    keyBorder: Color(0xFF2E3A5C),
    panelBody: Color(0xFF0D0F14),
    panelSection: Color(0xFF13182A),
    ledGreen: Color(0xFF00C851),
    ledOrange: Color(0xFFFFB703),
    ledRed: Color(0xFFE63946),
    ledBlue: Color(0xFF00D4FF),
    ledPurple: Color(0xFF8B5CF6),
  );

  /// Thème "Forge Blanche" (Light industriel)
  static const ForgeronTheme light = ForgeronTheme(
    background: Color(0xFFF1F3F8), 
    sidebar: Color(0xFFE6EBF2), 
    surface: Color(0xFFFFFFFF), 
    surfaceBright: Color(0xFFF8F9FA),
    surfaceHigh: Color(0xFFE2E8F0), 
    surfaceBorder: Color(0xFFCBD5E1), 
    surfaceBorderDim: Color(0x33CBD5E1),
    terminalBg: Color(0xFF1E293B), // Reste sombre
    primary: Color(0xFFFF6B35), 
    primaryDim: Color(0xFFCC5220),
    primaryLight: Color(0xFFFF9A6C),
    secondary: Color(0xFF0284C7), // Cyan assombri (SkyBlue)
    info: Color(0xFF3B82F6),
    success: Color(0xFF16A34A), 
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    error: Color(0xFFEF4444),
    axisX: Color(0xFFE11D48),
    axisY: Color(0xFF16A34A),
    axisZ: Color(0xFF2563EB),
    axisA: Color(0xFFFF6B35),
    axisC: Color(0xFF0284C7),
    textPrimary: Color(0xFF0F172A), 
    textSecondary: Color(0xFF475569), 
    textDisabled: Color(0xFF94A3B8), 
    glassBorder: Color(0x33000000), 
    glassSurface: Color(0x0A000000),
    lcdBackground: Color(0xFFD1E8D1), 
    lcdText: Color(0xFF1E521E), 
    lcdTextDim: Color(0xFF7FA87F),
    lcdBorder: Color(0xFF9CB89C),
    keyBezel: Color(0xFFF1F5F9),
    keyActive: Color(0xFFE2E8F0),
    keyBorder: Color(0xFFCBD5E1),
    panelBody: Color(0xFFF8FAFC), 
    panelSection: Color(0xFFFFFFFF),
    ledGreen: Color(0xFF22C55E),
    ledOrange: Color(0xFFF59E0B),
    ledRed: Color(0xFFEF4444),
    ledBlue: Color(0xFF3B82F6),
    ledPurple: Color(0xFF8B5CF6),
  );

  @override
  ForgeronTheme copyWith({
    Color? background, Color? sidebar, Color? surface, Color? surfaceBright,
    Color? surfaceHigh, Color? surfaceBorder, Color? surfaceBorderDim, Color? terminalBg,
    Color? primary, Color? primaryDim, Color? primaryLight, Color? secondary, Color? info,
    Color? success, Color? warning, Color? danger, Color? error,
    Color? axisX, Color? axisY, Color? axisZ, Color? axisA, Color? axisC,
    Color? textPrimary, Color? textSecondary, Color? textDisabled,
    Color? glassBorder, Color? glassSurface,
    Color? lcdBackground, Color? lcdText, Color? lcdTextDim, Color? lcdBorder,
    Color? keyBezel, Color? keyActive, Color? keyBorder, Color? panelBody, Color? panelSection,
    Color? ledGreen, Color? ledOrange, Color? ledRed, Color? ledBlue, Color? ledPurple,
  }) {
    return ForgeronTheme(
      background: background ?? this.background,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      surfaceBorderDim: surfaceBorderDim ?? this.surfaceBorderDim,
      terminalBg: terminalBg ?? this.terminalBg,
      primary: primary ?? this.primary,
      primaryDim: primaryDim ?? this.primaryDim,
      primaryLight: primaryLight ?? this.primaryLight,
      secondary: secondary ?? this.secondary,
      info: info ?? this.info,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      error: error ?? this.error,
      axisX: axisX ?? this.axisX,
      axisY: axisY ?? this.axisY,
      axisZ: axisZ ?? this.axisZ,
      axisA: axisA ?? this.axisA,
      axisC: axisC ?? this.axisC,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      glassBorder: glassBorder ?? this.glassBorder,
      glassSurface: glassSurface ?? this.glassSurface,
      lcdBackground: lcdBackground ?? this.lcdBackground,
      lcdText: lcdText ?? this.lcdText,
      lcdTextDim: lcdTextDim ?? this.lcdTextDim,
      lcdBorder: lcdBorder ?? this.lcdBorder,
      keyBezel: keyBezel ?? this.keyBezel,
      keyActive: keyActive ?? this.keyActive,
      keyBorder: keyBorder ?? this.keyBorder,
      panelBody: panelBody ?? this.panelBody,
      panelSection: panelSection ?? this.panelSection,
      ledGreen: ledGreen ?? this.ledGreen,
      ledOrange: ledOrange ?? this.ledOrange,
      ledRed: ledRed ?? this.ledRed,
      ledBlue: ledBlue ?? this.ledBlue,
      ledPurple: ledPurple ?? this.ledPurple,
    );
  }

  @override
  ForgeronTheme lerp(ForgeronTheme? other, double t) {
    if (other == null) return this;
    return ForgeronTheme(
      background: Color.lerp(background, other.background, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      surfaceBorderDim: Color.lerp(surfaceBorderDim, other.surfaceBorderDim, t)!,
      terminalBg: Color.lerp(terminalBg, other.terminalBg, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      info: Color.lerp(info, other.info, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      error: Color.lerp(error, other.error, t)!,
      axisX: Color.lerp(axisX, other.axisX, t)!,
      axisY: Color.lerp(axisY, other.axisY, t)!,
      axisZ: Color.lerp(axisZ, other.axisZ, t)!,
      axisA: Color.lerp(axisA, other.axisA, t)!,
      axisC: Color.lerp(axisC, other.axisC, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      lcdBackground: Color.lerp(lcdBackground, other.lcdBackground, t)!,
      lcdText: Color.lerp(lcdText, other.lcdText, t)!,
      lcdTextDim: Color.lerp(lcdTextDim, other.lcdTextDim, t)!,
      lcdBorder: Color.lerp(lcdBorder, other.lcdBorder, t)!,
      keyBezel: Color.lerp(keyBezel, other.keyBezel, t)!,
      keyActive: Color.lerp(keyActive, other.keyActive, t)!,
      keyBorder: Color.lerp(keyBorder, other.keyBorder, t)!,
      panelBody: Color.lerp(panelBody, other.panelBody, t)!,
      panelSection: Color.lerp(panelSection, other.panelSection, t)!,
      ledGreen: Color.lerp(ledGreen, other.ledGreen, t)!,
      ledOrange: Color.lerp(ledOrange, other.ledOrange, t)!,
      ledRed: Color.lerp(ledRed, other.ledRed, t)!,
      ledBlue: Color.lerp(ledBlue, other.ledBlue, t)!,
      ledPurple: Color.lerp(ledPurple, other.ledPurple, t)!,
    );
  }
}

// ── Extension BuildContext ────────────────────────────────────────────────────
extension ForgeronThemeContext on BuildContext {
  ForgeronTheme get forge => Theme.of(this).extension<ForgeronTheme>() ?? ForgeronTheme.dark;
}
