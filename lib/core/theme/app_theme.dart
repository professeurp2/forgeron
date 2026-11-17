import 'package:flutter/material.dart';

import '../widgets/forge_ui.dart' show ForgePageTransitionsBuilder;
import 'forge_tokens.dart';
import 'forgeron_colors.dart';

/// Thème Material global de Forgeron (v2), en sombre et en clair.
///
/// Les deux thèmes sortent de la MÊME fabrique, à partir de la palette
/// maison : un composant Material laissé à son défaut (bouton lavande, champ
/// gris clair) trahit tout de suite une application bricolée. Tout ce que
/// l'application emploie est donc thémé ici — boutons, champs, interrupteurs,
/// onglets, dialogues, bulles d'aide, barres d'information, menus.
abstract class AppTheme {
  static ThemeData get darkTheme => _build(forgeronDarkColors, Brightness.dark);
  static ThemeData get lightTheme => _build(forgeronLightColors, Brightness.light);

  static ThemeData _build(ForgeronColorPalette c, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: c.primary,
      onPrimary: Colors.white,
      primaryContainer: c.primary.withValues(alpha: 0.16),
      onPrimaryContainer: c.primary,
      secondary: c.secondary,
      onSecondary: dark ? const Color(0xFF00212B) : Colors.white,
      secondaryContainer: c.surfaceHigh,
      onSecondaryContainer: c.textPrimary,
      tertiary: c.info,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerHighest: c.surfaceHigh,
      surfaceContainerHigh: c.surfaceBright,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
      outline: c.surfaceBorder,
      outlineVariant: c.surfaceBorder,
      error: c.danger,
      onError: Colors.white,
    );

    OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(FRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(FRadius.md));
    const buttonText = TextStyle(
        fontFamily: FText.ui, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.6);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 13);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      dividerColor: c.surfaceBorder,
      fontFamily: FText.ui,
      // Glyphes absents de Rajdhani (flèches, symboles) : police du système.
      fontFamilyFallback: const ['Segoe UI', 'Roboto', 'sans-serif'],
      splashFactory: InkSparkle.splashFactory,
      // Une seule transition de page, sur toutes les plateformes.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ForgePageTransitionsBuilder(),
        TargetPlatform.iOS: ForgePageTransitionsBuilder(),
        TargetPlatform.windows: ForgePageTransitionsBuilder(),
        TargetPlatform.macOS: ForgePageTransitionsBuilder(),
        TargetPlatform.linux: ForgePageTransitionsBuilder(),
        TargetPlatform.fuchsia: ForgePageTransitionsBuilder(),
      }),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            color: c.textPrimary, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        headlineMedium: FText.title(c),
        titleLarge: FText.title(c),
        titleMedium: FText.heading(c),
        titleSmall: FText.heading(c).copyWith(fontSize: 14),
        bodyLarge: FText.body(c).copyWith(fontSize: 15),
        bodyMedium: FText.body(c),
        bodySmall: FText.caption(c),
        labelLarge: buttonText.copyWith(color: c.textPrimary),
        labelMedium: FText.caption(c).copyWith(fontWeight: FontWeight.w700),
        labelSmall: FText.overline(c),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: FText.heading(c).copyWith(fontSize: 17, letterSpacing: 0.8),
        shape: Border(bottom: BorderSide(color: c.surfaceBorder)),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FRadius.lg),
          side: BorderSide(color: c.surfaceBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.surfaceHigh,
          disabledForegroundColor: c.textDisabled,
          elevation: 0,
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.surfaceHigh,
          disabledForegroundColor: c.textDisabled,
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.surfaceBorder),
          shape: buttonShape,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          shape: buttonShape,
          textStyle: buttonText.copyWith(fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceBright,
        hintStyle: TextStyle(color: c.textDisabled, fontFamily: FText.ui),
        labelStyle: TextStyle(color: c.textSecondary, fontFamily: FText.ui),
        floatingLabelStyle: TextStyle(color: c.primary, fontFamily: FText.ui),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: field(c.surfaceBorder),
        enabledBorder: field(c.surfaceBorder),
        focusedBorder: field(c.primary, 1.6),
        errorBorder: field(c.danger),
        focusedErrorBorder: field(c.danger, 1.6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : c.textSecondary),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceHigh),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceBorder),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceHigh,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceHigh,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.primary,
        dividerColor: c.surfaceBorder,
        labelStyle: buttonText.copyWith(fontSize: 12, letterSpacing: 1),
        unselectedLabelStyle:
            buttonText.copyWith(fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FRadius.lg),
          side: BorderSide(color: c.surfaceBorder),
        ),
        titleTextStyle: FText.heading(c).copyWith(fontSize: 17),
        contentTextStyle: FText.body(c).copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(FRadius.lg))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceBright,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FRadius.md),
          side: BorderSide(color: c.surfaceBorder),
        ),
        textStyle: FText.body(c),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHigh,
        contentTextStyle: FText.body(c),
        actionTextColor: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FRadius.md),
          side: BorderSide(color: c.surfaceBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE8EBF5) : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(FRadius.sm),
        ),
        textStyle: TextStyle(
            fontFamily: FText.ui,
            color: dark ? const Color(0xFF111827) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.textDisabled.withValues(alpha: 0.5)),
        radius: const Radius.circular(FRadius.pill),
        thickness: const WidgetStatePropertyAll(6),
      ),
      dividerTheme: DividerThemeData(color: c.surfaceBorder, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
    );
  }
}
