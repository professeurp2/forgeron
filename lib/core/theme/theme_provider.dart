import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'forgeron_theme_extension.dart';

// Gère le mode actuel globalement pour l'accès statique via AppColors
class ThemeManager {
  static ThemeMode currentMode = ThemeMode.dark;
  
  static ForgeronTheme get current => 
      currentMode == ThemeMode.light ? ForgeronTheme.light : ForgeronTheme.dark;
}

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    ThemeManager.currentMode = state;
  }

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    ThemeManager.currentMode = state;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    ThemeManager.currentMode = state;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
