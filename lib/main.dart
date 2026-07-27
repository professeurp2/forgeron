import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/forgeron_colors.dart';
import 'application/providers/theme_provider.dart';
import 'application/services/notification_service.dart';
import 'presentation/screens/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🛑 [CRITICAL ERROR] $error\n$stack');
    return true; // Empêche l'application de crasher complètement
  };

  // Notifications système de l'agent IA (non bloquant).
  NotificationService.instance.init();

  runApp(const ProviderScope(child: ForgeronApp()));
}

class ForgeronApp extends ConsumerWidget {
  const ForgeronApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final palette = themeMode == ThemeMode.dark ? forgeronDarkColors : forgeronLightColors;

    return ForgeronTheme(
      colors: palette,
      child: MaterialApp(
        title: 'Forgeron — CNC 5 Axes',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const MainScaffold(),
      ),
    );
  }
}
