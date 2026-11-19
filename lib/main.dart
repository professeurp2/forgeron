import 'dart:async' show unawaited;
import 'dart:io' show Platform, Directory, File, FileMode;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'application/providers/ai_artifacts_provider.dart';
import 'application/services/ai_window_channel.dart';
import 'application/services/bundled_runtime.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/fallback_localizations.dart';
import 'core/storage/prefs_guard_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/forgeron_colors.dart';
import 'application/providers/theme_provider.dart';
import 'application/services/notification_service.dart';
import 'presentation/screens/main_scaffold.dart';
import 'presentation/desktop/ai_sub_window_app.dart';

bool get _isDesktopPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

void _logStartup(String message) {
  try {
    if (!kIsWeb && Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final dir = Directory('$localAppData\\Forgeron\\logs');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final file = File('${dir.path}\\startup.log');
        final now = DateTime.now().toIso8601String();
        file.writeAsStringSync('[$now] [Dart] $message\r\n',
            mode: FileMode.append);
      }
    }
  } catch (_) {
    // Ne jamais planter sur l'écriture du journal
  }
}

Future<void> main(List<String> args) async {
  _logStartup('Entrée dans main(), arguments: $args');

  FlutterError.onError = (details) {
    _logStartup(
        'FlutterError: ${details.exceptionAsString()}\r\n${details.stack}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _logStartup('PlatformDispatcher error: $error\r\n$stack');
    debugPrint('🛑 [CRITICAL ERROR] $error\n$stack');
    return true; // Empêche l'application de crasher complètement
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
    _logStartup('WidgetsFlutterBinding initialisé avec succès');

    if (_isDesktopPlatform &&
        args.length >= 3 &&
        args.first == 'multi_window') {
      // Une fenêtre ouverte par l'agent IA (graphique, G-code détaché, rapport)
      // relance ce même point d'entrée avec un second moteur Flutter, qui reçoit
      // ["multi_window", windowId, arguments] — desktop_multi_window 0.2.1 n'a
      // pas d'autre façon de choisir quoi afficher (pas de
      // `WindowController.fromCurrentEngine()`, voir `AiWindowChannel`). La
      // fenêtre principale, elle, démarre sans arguments : c'est ce qui la
      // distingue d'une fenêtre secondaire.
      final windowId = int.tryParse(args[1]);
      if (windowId != null) AiWindowChannel.bindCurrentWindow(windowId);
      final rawArguments = args[2];
      if (rawArguments.isNotEmpty) {
        _logStartup('Lancement sous-fenêtre ID: $windowId');
        runApp(AiSubWindowApp(rawArguments: rawArguments));
        return;
      }
    }

    // Une copie saine des préférences doit exister — et remplacer un fichier
    // corrompu — AVANT que quoi que ce soit ne les lise (voir PrefsFileGuard :
    // un arrêt brutal du PC avait vidé tout le profil le 21 octobre 2026).
    final prefsReport = _isDesktopPlatform ? await installPrefsGuard() : null;
    _logStartup('installPrefsGuard terminé (rapport: $prefsReport)');

    // Notifications système de l'agent IA (non bloquant).
    NotificationService.instance.init();

    // La portée Riverpod est créée à la main, et non par un `ProviderScope`
    // implicite : les fenêtres détachées savent rendre la main à cette
    // fenêtre-ci, et leur message arrive par un canal de plateforme, hors de
    // tout widget. Il faut donc pouvoir écrire dans les providers depuis là.
    final container = ProviderContainer();
    if (prefsReport != null) {
      container.read(prefsRestoreNoticeProvider.notifier).state = prefsReport;
    }
    if (_isDesktopPlatform) _listenToSubWindows(container);

    // Installation Windows (installer/) : démarre Ollama et reco3d embarqués,
    // arrêtés d'eux-mêmes à la fermeture. Sans effet en développement.
    if (_isDesktopPlatform) unawaited(BundledRuntime.instance.startServices());

    _logStartup('Lancement de runApp(ForgeronApp)');
    runApp(UncontrolledProviderScope(
      container: container,
      child: const ForgeronApp(),
    ));
    _logStartup('runApp() configuré avec succès');
  } catch (error, stack) {
    _logStartup('Erreur critique attrapée dans main(): $error\r\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Une erreur est survenue lors de l\'initialisation de Forgeron',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$error',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Un rapport d\'erreur détaillé est disponible dans :\n%LOCALAPPDATA%\\Forgeron\\logs\\startup.log',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

/// Écoute les fenêtres détachées.
///
/// Un seul message pour l'instant : « remets cet aperçu chez toi ». La réponse
/// dit si c'est accepté — la fenêtre appelante ne se referme que dans ce cas,
/// faute de quoi elle serait le dernier endroit où l'aperçu existe encore.
///
/// La réponse part AVANT que la vue 3D soit réellement affichée ici : la
/// fenêtre appelante doit pouvoir se refermer sans attendre la fin de notre
/// travail. C'est justement sa fermeture qu'on attend, en retour, avant
/// d'afficher quoi que ce soit — jamais deux vues 3D vivantes en même temps
/// sur l'environnement WebView2 partagé (voir
/// AiWindowChannel.waitUntilWindowClosed pour le pourquoi).
void _listenToSubWindows(ProviderContainer container) {
  try {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method != AiWindowChannel.dockViewer) return false;
      final viewer = AiDockedViewer.fromWire(call.arguments as String?);
      if (viewer == AiDockedViewer.none) return false;
      final notifier = container.read(aiArtifactsProvider.notifier);
      if (!notifier.canDock(viewer)) {
        return false;
      }
      unawaited(
        AiWindowChannel.waitUntilWindowClosed(fromWindowId).then((_) {
          notifier.dock(viewer);
        }),
      );
      return true;
    });
  } catch (e) {
    // Canal indisponible : les fenêtres restent détachables, elles ne savent
    // simplement pas revenir. L'application, elle, démarre.
    debugPrint('[Fenêtres] écoute des fenêtres détachées impossible : $e');
  }
}

class ForgeronApp extends ConsumerWidget {
  const ForgeronApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);

    return MaterialApp(
      title: 'Forgeron — CNC 5 Axes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // Langue de l'interface. `null` en automatique : MaterialApp résout
      // alors la locale du système contre [supportedLocales].
      locale: language.locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // Uniquement pour les langues absentes des délégués globaux
        // (wolof, lingala, kinyarwanda, shona) : sans eux, l'app tombe.
        FallbackMaterialLocalizationsDelegate(),
        FallbackCupertinoLocalizationsDelegate(),
      ],
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
      home: const PrefsRestoreNotice(child: MainScaffold()),
    );
  }
}
