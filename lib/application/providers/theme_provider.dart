import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode de thème de l'application.
///
/// Par défaut **celui du système** : à l'atelier on passe du plein jour au
/// hangar sombre, et le téléphone gère déjà cette bascule. L'application le
/// suit tant que l'utilisateur n'a pas choisi explicitement.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
        (ref) => ThemeModeController());

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    // Rien d'enregistré = l'utilisateur n'a jamais choisi : on reste sur le
    // système. Sans persistance, un choix explicite serait perdu à chaque
    // lancement et le réglage n'aurait aucun sens.
    if (saved == null) return;
    state = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Fait tourner système → clair → sombre → système.
  ///
  /// Trois états, pas deux : une simple bascule clair/sombre rendrait le mode
  /// système inaccessible dès la première pression, sans moyen d'y revenir.
  Future<void> cycle() => set(switch (state) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });
}

/// Thème **réellement appliqué**, mode système résolu.
///
/// À utiliser partout où l'on comparait `themeMode == ThemeMode.dark` : cette
/// comparaison répond « clair » en mode système, y compris sur un téléphone en
/// sombre. Elle laissait donc la palette maison en clair pendant que les
/// widgets Material passaient en sombre.
///
/// `platformBrightnessOf` enregistre une dépendance : l'écran se reconstruit
/// tout seul quand le système bascule.
bool isDarkTheme(BuildContext context, ThemeMode mode) => switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

/// Libellé court du mode, pour l'interface.
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Système',
      ThemeMode.light => 'Clair',
      ThemeMode.dark => 'Sombre',
    };

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
    };
