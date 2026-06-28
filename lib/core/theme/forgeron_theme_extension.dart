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

  /// Thème "Forge Noire" (Dark industriel — palette originale Void-to-Neon)
  static const ForgeronTheme dark = ForgeronTheme(
    // Backgrounds — bleu nuit profond original
    background: Color(0xFF090E1C),
    sidebar: Color(0xFF0D1323),
    surface: Color(0xFF13192B),
    surfaceBright: Color(0xFF242B43),
    surfaceHigh: Color(0xFF2E3650),
    surfaceBorder: Color(0x26707588),
    surfaceBorderDim: Color(0x14707588),
    terminalBg: Color(0xFF050A15),
    // Brand — Cyan néon original
    primary: Color(0xFF6DDDFF),
    primaryDim: Color(0xFF00C3EB),
    primaryLight: Color(0xFFB3EFFF),
    secondary: Color(0xFF50E1F9),
    info: Color(0xFF2196F3),
    // Semantic
    success: Color(0xFF00E676),
    warning: Color(0xFFFDB022),
    danger: Color(0xFFFF8257),
    error: Color(0xFFFF716C),
    // Axes CNC
    axisX: Color(0xFFFF5252),
    axisY: Color(0xFF69F0AE),
    axisZ: Color(0xFF448AFF),
    axisA: Color(0xFFFFAB40),
    axisC: Color(0xFFE040FB),
    // Text
    textPrimary: Color(0xFFE1E4FA),
    textSecondary: Color(0xFFA6AABF),
    textDisabled: Color(0xFF505466),
    // Glass
    glassBorder: Color(0x33FFFFFF),
    glassSurface: Color(0x1AFFFFFF),
    // CNC Panel — LCD phosphore vert style Fanuc
    lcdBackground: Color(0xFF0A1505),
    lcdText: Color(0xFF39FF14),
    lcdTextDim: Color(0xFF1A7A08),
    lcdBorder: Color(0xFF0D2A0A),
    keyBezel: Color(0xFF1A1F35),
    keyActive: Color(0xFF252D4A),
    keyBorder: Color(0xFF2E3A5C),
    panelBody: Color(0xFF0B0E1C),
    panelSection: Color(0xFF101525),
    // LEDs
    ledGreen: Color(0xFF00E676),
    ledOrange: Color(0xFFFDB022),
    ledRed: Color(0xFFFF3D00),
    ledBlue: Color(0xFF40C4FF),
    ledPurple: Color(0xFFE040FB),
  );

  /// Thème "Forge Blanche" (Light industriel — adapté de l'esthétique originale)
  static const ForgeronTheme light = ForgeronTheme(
    // Backgrounds — blanc industriel chaud
    background: Color(0xFFF0F2F8),
    sidebar: Color(0xFFE4E8F2),
    surface: Color(0xFFFBFCFF),
    surfaceBright: Color(0xFFEEF1FA),
    surfaceHigh: Color(0xFFE0E5F0),
    surfaceBorder: Color(0xFFCACFDE),
    surfaceBorderDim: Color(0x44CACFDE),
    terminalBg: Color(0xFF060C1A), // Terminal reste sombre
    // Brand — Cyan assombri (lisible sur fond clair)
    primary: Color(0xFF0099CC),
    primaryDim: Color(0xFF007BAA),
    primaryLight: Color(0xFF33BBEE),
    secondary: Color(0xFF009BB8),
    info: Color(0xFF1565C0),
    // Semantic
    success: Color(0xFF00AB55),
    warning: Color(0xFFC97B00),
    danger: Color(0xFFD63031),
    error: Color(0xFFD63850),
    // Axes CNC
    axisX: Color(0xFFCC2222),
    axisY: Color(0xFF007744),
    axisZ: Color(0xFF1155CC),
    axisA: Color(0xFFCC5500),
    axisC: Color(0xFF6600AA),
    // Text
    textPrimary: Color(0xFF0A0E1A),
    textSecondary: Color(0xFF3D4465),
    textDisabled: Color(0xFF8590A8),
    // Glass
    glassBorder: Color(0x44000000),
    glassSurface: Color(0x0A000000),
    // CNC Panel — LCD couleur crème style Fanuc clair
    lcdBackground: Color(0xFFE8F4E8),
    lcdText: Color(0xFF0A3A0A),
    lcdTextDim: Color(0xFF3D7A3D),
    lcdBorder: Color(0xFF8FB88F),
    keyBezel: Color(0xFFEFF2F8),
    keyActive: Color(0xFFD8DEF0),
    keyBorder: Color(0xFFB8C0D8),
    panelBody: Color(0xFFF5F7FC),
    panelSection: Color(0xFFFFFFFF),
    // LEDs
    ledGreen: Color(0xFF00AB55),
    ledOrange: Color(0xFFC97B00),
    ledRed: Color(0xFFCC2200),
    ledBlue: Color(0xFF0066BB),
    ledPurple: Color(0xFF7B2FBE),
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
