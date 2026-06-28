import 'package:flutter/material.dart';
import 'app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ForgeronThemeExtension — Extension ThemeData pour les couleurs CNC spécifiques
//
// Usage :
//   final theme = context.forge;
//   Color axisX = theme.axisX;
//   Color lcdText = theme.lcdText;
// ═══════════════════════════════════════════════════════════════════════════════

class ForgeronTheme extends ThemeExtension<ForgeronTheme> {
  // ── Couleurs LCD / Panneau ────────────────────────────────────────────────
  final Color lcdBackground;
  final Color lcdText;
  final Color lcdTextDim;
  final Color lcdBorder;
  final Color keyBezel;
  final Color keyActive;
  final Color keyBorder;
  final Color panelBody;
  final Color panelSection;

  // ── Couleurs axes ─────────────────────────────────────────────────────────
  final Color axisX;
  final Color axisY;
  final Color axisZ;
  final Color axisA;
  final Color axisC;

  // ── LEDs statut ───────────────────────────────────────────────────────────
  final Color ledGreen;
  final Color ledOrange;
  final Color ledRed;
  final Color ledBlue;
  final Color ledPurple;

  // ── Surface spéciale ──────────────────────────────────────────────────────
  final Color terminalBg;
  final Color surfaceHigh;
  final Color glassBorder;
  final Color glassSurface;

  const ForgeronTheme({
    required this.lcdBackground,
    required this.lcdText,
    required this.lcdTextDim,
    required this.lcdBorder,
    required this.keyBezel,
    required this.keyActive,
    required this.keyBorder,
    required this.panelBody,
    required this.panelSection,
    required this.axisX,
    required this.axisY,
    required this.axisZ,
    required this.axisA,
    required this.axisC,
    required this.ledGreen,
    required this.ledOrange,
    required this.ledRed,
    required this.ledBlue,
    required this.ledPurple,
    required this.terminalBg,
    required this.surfaceHigh,
    required this.glassBorder,
    required this.glassSurface,
  });

  /// Instance par défaut — thème "Forge Noire" (dark industriel)
  static const ForgeronTheme dark = ForgeronTheme(
    lcdBackground: AppColors.lcdBackground,
    lcdText: AppColors.lcdText,
    lcdTextDim: AppColors.lcdTextDim,
    lcdBorder: AppColors.lcdBorder,
    keyBezel: AppColors.keyBezel,
    keyActive: AppColors.keyActive,
    keyBorder: AppColors.keyBorder,
    panelBody: AppColors.panelBody,
    panelSection: AppColors.panelSection,
    axisX: AppColors.axisX,
    axisY: AppColors.axisY,
    axisZ: AppColors.axisZ,
    axisA: AppColors.axisA,
    axisC: AppColors.axisC,
    ledGreen: AppColors.ledGreen,
    ledOrange: AppColors.ledOrange,
    ledRed: AppColors.ledRed,
    ledBlue: AppColors.ledBlue,
    ledPurple: AppColors.ledPurple,
    terminalBg: AppColors.terminalBg,
    surfaceHigh: AppColors.surfaceHigh,
    glassBorder: AppColors.glassBorder,
    glassSurface: AppColors.glassSurface,
  );

  @override
  ForgeronTheme copyWith({
    Color? lcdBackground,
    Color? lcdText,
    Color? lcdTextDim,
    Color? lcdBorder,
    Color? keyBezel,
    Color? keyActive,
    Color? keyBorder,
    Color? panelBody,
    Color? panelSection,
    Color? axisX,
    Color? axisY,
    Color? axisZ,
    Color? axisA,
    Color? axisC,
    Color? ledGreen,
    Color? ledOrange,
    Color? ledRed,
    Color? ledBlue,
    Color? ledPurple,
    Color? terminalBg,
    Color? surfaceHigh,
    Color? glassBorder,
    Color? glassSurface,
  }) {
    return ForgeronTheme(
      lcdBackground: lcdBackground ?? this.lcdBackground,
      lcdText: lcdText ?? this.lcdText,
      lcdTextDim: lcdTextDim ?? this.lcdTextDim,
      lcdBorder: lcdBorder ?? this.lcdBorder,
      keyBezel: keyBezel ?? this.keyBezel,
      keyActive: keyActive ?? this.keyActive,
      keyBorder: keyBorder ?? this.keyBorder,
      panelBody: panelBody ?? this.panelBody,
      panelSection: panelSection ?? this.panelSection,
      axisX: axisX ?? this.axisX,
      axisY: axisY ?? this.axisY,
      axisZ: axisZ ?? this.axisZ,
      axisA: axisA ?? this.axisA,
      axisC: axisC ?? this.axisC,
      ledGreen: ledGreen ?? this.ledGreen,
      ledOrange: ledOrange ?? this.ledOrange,
      ledRed: ledRed ?? this.ledRed,
      ledBlue: ledBlue ?? this.ledBlue,
      ledPurple: ledPurple ?? this.ledPurple,
      terminalBg: terminalBg ?? this.terminalBg,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      glassBorder: glassBorder ?? this.glassBorder,
      glassSurface: glassSurface ?? this.glassSurface,
    );
  }

  @override
  ForgeronTheme lerp(ForgeronTheme? other, double t) {
    if (other == null) return this;
    return ForgeronTheme(
      lcdBackground: Color.lerp(lcdBackground, other.lcdBackground, t)!,
      lcdText: Color.lerp(lcdText, other.lcdText, t)!,
      lcdTextDim: Color.lerp(lcdTextDim, other.lcdTextDim, t)!,
      lcdBorder: Color.lerp(lcdBorder, other.lcdBorder, t)!,
      keyBezel: Color.lerp(keyBezel, other.keyBezel, t)!,
      keyActive: Color.lerp(keyActive, other.keyActive, t)!,
      keyBorder: Color.lerp(keyBorder, other.keyBorder, t)!,
      panelBody: Color.lerp(panelBody, other.panelBody, t)!,
      panelSection: Color.lerp(panelSection, other.panelSection, t)!,
      axisX: Color.lerp(axisX, other.axisX, t)!,
      axisY: Color.lerp(axisY, other.axisY, t)!,
      axisZ: Color.lerp(axisZ, other.axisZ, t)!,
      axisA: Color.lerp(axisA, other.axisA, t)!,
      axisC: Color.lerp(axisC, other.axisC, t)!,
      ledGreen: Color.lerp(ledGreen, other.ledGreen, t)!,
      ledOrange: Color.lerp(ledOrange, other.ledOrange, t)!,
      ledRed: Color.lerp(ledRed, other.ledRed, t)!,
      ledBlue: Color.lerp(ledBlue, other.ledBlue, t)!,
      ledPurple: Color.lerp(ledPurple, other.ledPurple, t)!,
      terminalBg: Color.lerp(terminalBg, other.terminalBg, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
    );
  }
}

// ── Extension BuildContext ────────────────────────────────────────────────────

/// Raccourci ergonomique : `context.forge.axisX`
extension ForgeronThemeContext on BuildContext {
  ForgeronTheme get forge =>
      Theme.of(this).extension<ForgeronTheme>() ?? ForgeronTheme.dark;
}
