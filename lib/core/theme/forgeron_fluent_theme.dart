import 'package:fluent_ui/fluent_ui.dart';
import 'forgeron_colors.dart';

/// Thème Fluent (Win11) dérivé de [ForgeronColorPalette] — pas une seconde
/// palette : les mêmes teintes que `context.fc` (Material), pour que l'écran
/// Agent IA reste visuellement de la même famille que le reste de l'app.
///
/// Portée volontairement limitée à cet écran (voir PLAN-IA) : on ne monte pas
/// de `FluentApp` à la racine, seulement un `FluentTheme` autour du sous-arbre
/// concerné.
FluentThemeData forgeronFluentTheme(ForgeronColorPalette c) {
  final isDark = c.background.computeLuminance() < 0.5;
  final brightness = isDark ? Brightness.dark : Brightness.light;

  return FluentThemeData(
    brightness: brightness,
    accentColor: c.primary.toAccentColor(),
    scaffoldBackgroundColor: c.background,
    micaBackgroundColor: c.background,
    cardColor: c.surface,
    shadowColor: Colors.black,
    menuColor: c.surfaceBright,
    activeColor: c.primary,
    inactiveColor: c.textSecondary,
    inactiveBackgroundColor: c.surfaceBright,
    selectionColor: c.primary.toAccentColor(),
  );
}
