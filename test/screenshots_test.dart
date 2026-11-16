@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/discovery_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/theme_provider.dart';
import 'package:forgeron/application/providers/ui_state_provider.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/presentation/widgets/nav/forge_bottom_nav.dart';
import 'package:forgeron/domain/models/machine_state.dart';
import 'package:forgeron/main.dart' show ForgeronApp;
import 'package:forgeron/presentation/screens/ai_agent_settings_screen.dart';
import 'package:forgeron/presentation/screens/app_settings_screen.dart';
import 'package:forgeron/presentation/screens/backoffice_screen.dart';
import 'package:forgeron/presentation/screens/connection_settings_screen.dart';
import 'package:forgeron/presentation/screens/limit_config_screen.dart';
import 'package:forgeron/presentation/screens/machine_calibration_screen.dart';
import 'package:forgeron/presentation/screens/main_scaffold.dart' show selectedNavIndexProvider;
import 'package:forgeron/presentation/screens/remote_chat_screen.dart';
import 'package:forgeron/presentation/screens/setup_wizard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures d'écran de toute l'application, pour la relecture visuelle.
///
/// Ne fait partie d'aucune suite : il n'est lancé qu'à la main, avec
/// `FORGERON_SCREENS=1 flutter test test/screenshots_test.dart --update-goldens`,
/// et écrit un PNG par écran dans `build/screens/`. Les polices embarquées
/// (JetBrains Mono, Rajdhani) sont celles de l'application ; la police par
/// défaut du thème (`RobotoMono`, non embarquée) est remplacée par Rajdhani,
/// faute de quoi tout texte ordinaire s'afficherait en carrés.
const _run = bool.fromEnvironment('FORGERON_SCREENS');

class _NoScanDiscovery extends DiscoveryNotifier {
  _NoScanDiscovery(super.service, super.ref);
  @override
  Future<void> scan({bool autoConnect = false}) async {}
}

class _SilentStream extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {}
  @override
  void onCancel(Object? arguments) {}
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(ThemeMode mode) {
    state = mode;
  }
}

/// Une machine en ligne, posée sur une cote parlante : les écrans montrent
/// des chiffres, pas des zéros.
final _machine = MachineState(
  status: MachineStatus.idle,
  mPos: const [12.345, -8.2, 35.0, 15.5, 90.0],
  wPos: const [2.345, -3.2, 10.0, 15.5, 90.0],
  wco: const [10.0, -5.0, 25.0, 0.0, 0.0],
  feedrate: 600,
  spindleSpeed: 1000,
  coreTemp: 41,
);

void main() {
  final enabled = _run || Platform.environment['FORGERON_SCREENS'] == '1';

  setUpAll(() async {
    if (!enabled) return;
    SharedPreferences.setMockInitialValues({'tutorial_completed': true});
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(rootBundle.load(f));
      }
      await loader.load();
    }

    const raj = [
      'assets/fonts/Rajdhani/Rajdhani-Regular.ttf',
      'assets/fonts/Rajdhani/Rajdhani-Medium.ttf',
      'assets/fonts/Rajdhani/Rajdhani-SemiBold.ttf',
      'assets/fonts/Rajdhani/Rajdhani-Bold.ttf',
    ];
    const mono = [
      'assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf',
      'assets/fonts/JetBrainsMono/JetBrainsMono-Medium.ttf',
      'assets/fonts/JetBrainsMono/JetBrainsMono-SemiBold.ttf',
      'assets/fonts/JetBrainsMono/JetBrainsMono-Bold.ttf',
    ];
    await load('Rajdhani', raj);
    await load('JetBrains Mono', mono);

    // Polices du SDK : Material Icons (sinon chaque icône est un carré) et
    // Roboto pour la police par défaut du thème (`RobotoMono` n'est pas
    // embarquée : sur Windows l'application retombe sur une sans-serif).
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'C:\srclutter';
    final cache = '$sdk/bin/cache/artifacts/material_fonts';
    Future<void> loadFile(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final file = File('$cache/$f');
        if (!file.existsSync()) return;
        loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await loader.load();
    }

    await loadFile('MaterialIcons', ['materialicons-regular.otf']);

    // La police par défaut du thème (`RobotoMono`) n'est pas embarquée : sur
    // Windows, l'application retombe sur Segoe UI. On charge donc Segoe UI
    // depuis le système sous ce nom ; à défaut, Rajdhani.
    Future<bool> loadSystem(String family, List<String> files) async {
      final loader = FontLoader(family);
      var any = false;
      for (final f in files) {
        final file = File(r'C:\Windows\Fonts' + f);
        if (!file.existsSync()) continue;
        any = true;
        loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      if (any) await loader.load();
      return any;
    }

    const segoe = ['segoeui.ttf', 'segoeuisl.ttf', 'segoeuisb.ttf', 'segoeuib.ttf', 'seguibl.ttf'];
    for (final family in ['RobotoMono', 'Roboto', 'Segoe UI']) {
      if (!await loadSystem(family, segoe)) await load(family, raj);
    }

    // Plugins natifs absents en test : audio (sons d'interface).
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (_) async => null);
    messenger.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'), _SilentStream());
  });

  List<Override> overrides(ThemeMode theme) => [
        isSimulationModeProvider.overrideWith((ref) => true),
        machineStateProvider.overrideWith((ref) => Stream.value(_machine)),
        discoveryProvider.overrideWith(
            (ref) => _NoScanDiscovery(ref.watch(autoDiscoveryServiceProvider), ref)),
        themeModeProvider.overrideWith((ref) => _FixedTheme(theme)),
      ];

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Size size,
    required ThemeMode theme,
    Widget? child,
    void Function(ProviderContainer)? prepare,
    int? mobileTab,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'tutorial_completed': true});
    // Un grand écran est un poste Windows, un petit un téléphone Android :
    // la mise en page choisit sa variante d'après la plateforme.
    debugDefaultTargetPlatformOverride =
        size.width >= 1000 ? TargetPlatform.windows : TargetPlatform.android;

    final container = ProviderContainer(overrides: overrides(theme));
    // L'atelier parle français : c'est la langue dans laquelle on relit.
    await container.read(appLanguageProvider.notifier).select(appLanguageById('fr'));
    prepare?.call(container);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: child == null
          ? const ForgeronApp()
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('fr'),
              theme: ThemeData(
                  brightness: theme == ThemeMode.dark ? Brightness.dark : Brightness.light,
                  fontFamily: 'RobotoMono'),
              home: child,
            ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    // Téléphone : la navigation est un cube pilote par un PageController ;
    // le provider d'index ne suffit pas, on touche la destination.
    if (mobileTab != null && mobileTab > 0) {
      const icons = [Icons.dashboard, Icons.center_focus_strong, Icons.build, Icons.folder_open, Icons.terminal, Icons.monitor_heart];
      final target = find.descendant(of: find.byType(ForgeBottomNav), matching: find.byIcon(icons[mobileTab]));
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target.first);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    }
    final file = File('build/screens/$name.png').absolute;
    await expectLater(
      find.byType(child == null ? ForgeronApp : MaterialApp),
      matchesGoldenFile(file.uri),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
    // Remis AVANT la fin du test : le banc vérifie que les variables de
    // débogage sont rendues à leur valeur d'origine.
    debugDefaultTargetPlatformOverride = null;
  }

  const desktop = Size(1600, 900);
  const phone = Size(390, 844);
  const pages = [
    'tableau-de-bord',
    'palpage',
    'outils',
    'espace-de-travail',
    'terminal',
    'diagnostics',
    'agent-ia',
    'backoffice',
  ];

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    final t = theme == ThemeMode.dark ? 'sombre' : 'clair';
    for (var i = 0; i < pages.length; i++) {
      testWidgets('PC ${pages[i]} $t', (tester) async {
        await shoot(tester, 'pc-${pages[i]}-$t',
            size: desktop,
            theme: theme,
            prepare: (c) => c.read(selectedNavIndexProvider.notifier).state = i);
      }, skip: !enabled);
    }
    testWidgets('PC atelier $t', (tester) async {
      await shoot(tester, 'pc-atelier-$t',
          size: desktop,
          theme: theme,
          prepare: (c) => c.read(isWorkshopModeProvider.notifier).state = true);
    }, skip: !enabled);
  }

  for (var i = 0; i < 6; i++) {
    testWidgets('téléphone ${pages[i]}', (tester) async {
      await shoot(tester, 'tel-${pages[i]}', size: phone, theme: ThemeMode.dark, mobileTab: i);
    }, skip: !enabled);
  }
  testWidgets('téléphone atelier', (tester) async {
    await shoot(tester, 'tel-atelier',
        size: phone,
        theme: ThemeMode.dark,
        prepare: (c) => c.read(isWorkshopModeProvider.notifier).state = true);
  }, skip: !enabled);

  final standalone = <String, Widget Function()>{
    'parametres': () => const AppSettingsScreen(),
    'parametres-agent': () => const AiAgentSettingsScreen(),
    'connexion': () => const ConnectionSettingsScreen(),
    'backoffice-mobile': () => const BackofficeScreen(standalone: true),
    'limites': () => const LimitConfigScreen(),
    'calibration': () => const MachineCalibrationScreen(),
    'chat-distant': () => const RemoteChatScreen(),
    'assistant-mise-en-route': () => const SetupWizardScreen(),
  };
  for (final e in standalone.entries) {
    testWidgets('téléphone ${e.key}', (tester) async {
      await shoot(tester, 'tel-${e.key}', size: phone, theme: ThemeMode.dark, child: e.value());
    }, skip: !enabled);
    testWidgets('PC ${e.key}', (tester) async {
      await shoot(tester, 'pc-${e.key}', size: desktop, theme: ThemeMode.dark, child: e.value());
    }, skip: !enabled);
  }
}
