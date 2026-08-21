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

    return MaterialApp(
      title: 'Forgeron — CNC 5 Axes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // ForgeronTheme est monté SOUS MaterialApp, et non au-dessus. C'est là
      // que MediaQuery existe, donc que la luminosité du système est lisible :
      // au-dessus, [isDarkTheme] n'aurait aucun MediaQuery ancêtre à consulter.
      //
      // Ce placement garantit aussi que la palette maison et les widgets
      // Material résolvent `ThemeMode.system` de la même façon — sinon l'un des
      // deux passe en sombre pendant que l'autre reste en clair.
      builder: (context, child) => ForgeronTheme(
        colors: isDarkTheme(context, themeMode)
            ? forgeronDarkColors
            : forgeronLightColors,
        child: child!,
      ),
      home: const MainScaffold(),
    );
  }
}
