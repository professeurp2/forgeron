import 'package:flutter/material.dart';

class ForgeronColorPalette {
  final Color background;
  final Color sidebar;
  final Color surface;
  final Color surfaceBright;
  final Color surfaceHigh;
  final Color surfaceBorder;
  final Color surfaceBorderDim;
  final Color terminalBg;
  final Color primary;
  final Color primaryDim;
  final Color primaryLight;
  final Color secondary;
  final Color info;
  final Color success;
  final Color warning;
  final Color danger;
  final Color error;
  final Color axisX;
  final Color axisY;
  final Color axisZ;
  final Color axisA;
  final Color axisC;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color glassBorder;
  final Color glassSurface;
  final Color lcdBackground;
  final Color lcdText;
  final Color lcdTextDim;
  final Color lcdBorder;
  final Color keyBezel;
  final Color keyActive;
  final Color keyBorder;
  final Color panelBody;
  final Color panelSection;

  const ForgeronColorPalette({
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
  });
}

const forgeronDarkColors = ForgeronColorPalette(
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
);

const forgeronLightColors = ForgeronColorPalette(
  background: Color(0xFFF0F2F5),
  sidebar: Color(0xFFE8EBF2),
  surface: Color(0xFFFFFFFF),
  surfaceBright: Color(0xFFF5F7FA),
  surfaceHigh: Color(0xFFE2E6F0),
  surfaceBorder: Color(0xFFD0D5E0),
  surfaceBorderDim: Color(0x1AD0D5E0),
  terminalBg: Color(0xFFF9FAFB),
  primary: Color(0xFFFF6B35),
  primaryDim: Color(0xFFCC5220),
  primaryLight: Color(0xFFFF9A6C),
  secondary: Color(0xFF0099CC),
  info: Color(0xFF2563EB),
  success: Color(0xFF10B981),
  warning: Color(0xFFF59E0B),
  danger: Color(0xFFEF4444),
  error: Color(0xFFF43F5E),
  axisX: Color(0xFFDC2626),
  axisY: Color(0xFF16A34A),
  axisZ: Color(0xFF2563EB),
  axisA: Color(0xFFFF6B35),
  axisC: Color(0xFF0099CC),
  textPrimary: Color(0xFF1F2937),
  textSecondary: Color(0xFF4B5563),
  textDisabled: Color(0xFF9CA3AF),
  glassBorder: Color(0x1A000000),
  glassSurface: Color(0x0D000000),
  lcdBackground: Color(0xFFE0E5DF),
  lcdText: Color(0xFF0D5E07),
  lcdTextDim: Color(0xFF2E7D32),
  lcdBorder: Color(0xFFB8C2B7),
  keyBezel: Color(0xFFE5E7EB),
  keyActive: Color(0xFFD1D5DB),
  keyBorder: Color(0xFF9CA3AF),
  panelBody: Color(0xFFF3F4F6),
  panelSection: Color(0xFFE5E7EB),
);

class ForgeronTheme extends InheritedWidget {
  final ForgeronColorPalette colors;

  const ForgeronTheme({
    super.key,
    required this.colors,
    required super.child,
  });

  static ForgeronColorPalette of(BuildContext context) {
    final ForgeronTheme? result = context.dependOnInheritedWidgetOfExactType<ForgeronTheme>();
    return result?.colors ?? forgeronDarkColors;
  }

  @override
  bool updateShouldNotify(ForgeronTheme oldWidget) {
    return oldWidget.colors != colors;
  }
}

extension ForgeronThemeExtension on BuildContext {
  ForgeronColorPalette get fc => ForgeronTheme.of(this);
}
