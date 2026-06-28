import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_scaffold.dart';

import 'package:flutter/foundation.dart';

void main() {
  // Autoriser l'usage hors ligne des polices Google Fonts
  // (désactive le téléchargement réseau, utilise les polices bundlées)
  GoogleFonts.config.allowRuntimeFetching = false;

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🛑 [CRITICAL ERROR] $error\n$stack');
    return true; // Empêche l'application de crasher complètement
  };

  runApp(const ProviderScope(child: ForgeronApp()));
}

class ForgeronApp extends StatelessWidget {
  const ForgeronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forgeron — CNC 5 Axes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScaffold(),
    );
  }
}
