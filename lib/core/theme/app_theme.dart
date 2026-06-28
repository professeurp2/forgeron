import 'package:flutter/material.dart';
import 'app_text_styles.dart';
import 'forgeron_theme_extension.dart';

abstract class AppTheme {
  
  static ThemeData get darkTheme => _buildTheme(Brightness.dark, ForgeronTheme.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light, ForgeronTheme.light);

  static ThemeData _buildTheme(Brightness brightness, ForgeronTheme forgeColors) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: forgeColors.primary,
      onPrimary: forgeColors.background,
      primaryContainer: forgeColors.primaryDim,
      onPrimaryContainer: forgeColors.primaryLight,
      secondary: forgeColors.secondary,
      onSecondary: forgeColors.background,
      secondaryContainer: forgeColors.surfaceBright,
      onSecondaryContainer: forgeColors.secondary,
      tertiary: forgeColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: forgeColors.surfaceHigh,
      onTertiaryContainer: forgeColors.textPrimary,
      error: forgeColors.danger,
      onError: Colors.white,
      errorContainer: forgeColors.error.withValues(alpha: 0.2),
      onErrorContainer: forgeColors.error,
      surface: forgeColors.surface,
      onSurface: forgeColors.textPrimary,
      surfaceContainerHighest: forgeColors.surfaceHigh,
      onSurfaceVariant: forgeColors.textSecondary,
      outline: forgeColors.surfaceBorder,
      outlineVariant: forgeColors.surfaceBorderDim,
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: forgeColors.textPrimary,
      onInverseSurface: forgeColors.background,
      inversePrimary: forgeColors.primaryDim,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: forgeColors.background,
      useMaterial3: true,
      textTheme: AppTextStyles.createMaterialTextTheme(forgeColors),
      appBarTheme: AppBarTheme(
        backgroundColor: forgeColors.surface,
        foregroundColor: forgeColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: forgeColors.textSecondary, size: 20),
        titleTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.primary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2.0),
        toolbarTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 14),
        centerTitle: false,
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: forgeColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: forgeColors.surfaceBright,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textDisabled, fontSize: 13),
        labelStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        floatingLabelStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.primary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        helperStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textDisabled, fontSize: 11),
        errorStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.error, fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.error, width: 1.5)),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: forgeColors.primary,
          foregroundColor: forgeColors.background,
          disabledBackgroundColor: forgeColors.surfaceHigh,
          disabledForegroundColor: forgeColors.textDisabled,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: forgeColors.primary,
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: forgeColors.textPrimary,
          side: BorderSide(color: forgeColors.surfaceBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: forgeColors.textSecondary,
          hoverColor: forgeColors.surfaceHigh,
          highlightColor: forgeColors.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: forgeColors.surfaceBright,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: forgeColors.surfaceBorder, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        textStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
        waitDuration: const Duration(milliseconds: 400),
        showDuration: const Duration(seconds: 3),
        preferBelow: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: forgeColors.surfaceBright,
        selectedColor: forgeColors.primary.withValues(alpha: 0.2),
        disabledColor: forgeColors.surfaceBorder,
        labelStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        secondaryLabelStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: EdgeInsets.zero,
        elevation: 0,
        iconTheme: IconThemeData(color: forgeColors.textSecondary, size: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: forgeColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        titleTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.0),
        contentTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textSecondary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: forgeColors.surfaceBright,
        contentTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        actionTextColor: forgeColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: forgeColors.primary,
        unselectedLabelColor: forgeColors.textSecondary,
        indicatorColor: forgeColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.0),
        overlayColor: WidgetStateProperty.all(forgeColors.surfaceHigh.withValues(alpha: 0.4)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: forgeColors.surface,
        selectedItemColor: forgeColors.primary,
        unselectedItemColor: forgeColors.textDisabled,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 9, fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: forgeColors.surfaceBorder, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: forgeColors.textSecondary, size: 20),
      primaryIconTheme: IconThemeData(color: forgeColors.primary, size: 20),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: forgeColors.primary.withValues(alpha: 0.08),
        iconColor: forgeColors.textSecondary,
        textColor: forgeColors.textPrimary,
        subtitleTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textSecondary, fontSize: 12),
        titleTextStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return forgeColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return forgeColors.primary;
          return forgeColors.surfaceBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(forgeColors.background),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return forgeColors.primary;
          return Colors.transparent;
        }),
        side: BorderSide(color: forgeColors.surfaceBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return forgeColors.primary;
          return forgeColors.textDisabled;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: forgeColors.primary,
        inactiveTrackColor: forgeColors.surfaceBorder,
        thumbColor: forgeColors.primary,
        overlayColor: forgeColors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: forgeColors.surfaceBright,
        valueIndicatorTextStyle: TextStyle(fontFamily: 'JetBrainsMono', color: forgeColors.textPrimary, fontSize: 11),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: forgeColors.primary,
        linearTrackColor: forgeColors.surfaceBorder,
        circularTrackColor: forgeColors.surfaceBorder,
        linearMinHeight: 3,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(forgeColors.surfaceBorder.withValues(alpha: 0.8)),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(2),
        interactive: true,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: forgeColors.surfaceBright,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
        textStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        labelTextStyle: WidgetStateProperty.all(TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: forgeColors.danger,
        foregroundColor: Colors.white,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(forgeColors.surfaceBright),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(8),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: forgeColors.surfaceBorder, width: 1))),
        ),
        textStyle: TextStyle(fontFamily: 'Rajdhani', color: forgeColors.textPrimary, fontSize: 13),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: forgeColors.surfaceBright,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.surfaceBorder, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: forgeColors.primary, width: 1.5)),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        forgeColors,
      ],
    );
  }
}
