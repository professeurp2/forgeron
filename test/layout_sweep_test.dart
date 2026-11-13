import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/discovery_provider.dart';
import 'package:forgeron/application/providers/machine_provider.dart';
import 'package:forgeron/application/providers/theme_provider.dart';
import 'package:forgeron/application/providers/ui_state_provider.dart';
import 'package:forgeron/main.dart' show ForgeronApp;
import 'package:forgeron/presentation/screens/ai_agent_settings_screen.dart';
import 'package:forgeron/presentation/screens/app_settings_screen.dart';
import 'package:forgeron/presentation/screens/backoffice_screen.dart';
import 'package:forgeron/presentation/screens/cnc_panel_screen.dart';
import 'package:forgeron/presentation/screens/connection_settings_screen.dart';
import 'package:forgeron/presentation/screens/limit_config_screen.dart';
import 'package:forgeron/presentation/screens/limit_recovery_screen.dart';
import 'package:forgeron/presentation/screens/limit_switch_test_screen.dart';
import 'package:forgeron/presentation/screens/machine_calibration_screen.dart';
import 'package:forgeron/presentation/screens/main_scaffold.dart' show selectedNavIndexProvider;
import 'package:forgeron/presentation/screens/remote_chat_screen.dart';
import 'package:forgeron/presentation/screens/setup_wizard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Balayage de mise en page : TOUTE l'application, à toutes les tailles,
/// dans les deux thèmes, et chaque débordement (« RenderFlex overflowed »),
/// exception de rendu ou assertion de layout est relevé avec le fichier et la
/// ligne du widget fautif.
///
/// C'est la revue graphique sous forme de test : ce qu'un œil humain
/// attrape par hasard sur un écran, ce balayage l'attrape sur sept, à chaque
/// exécution. Le rapport complet est écrit dans `build/layout_sweep.txt`.
class _Size {
  const _Size(this.name, this.w, this.h);
  final String name;
  final double w, h;
}

const _sizes = [
  _Size('téléphone', 360, 780),
  _Size('téléphone paysage', 780, 360),
  _Size('tablette', 800, 1280),
  _Size('tablette paysage', 1280, 800),
  _Size('portable 1366×768', 1366, 768),
  _Size('fenêtre basse 1024×600', 1024, 600),
  _Size('grand écran 1920×1080', 1920, 1080),
];

const _pages = [
  'Tableau de bord',
  'Palpage & origines',
  'Magasin d\'outils',
  'Espace de travail',
  'Terminal MDI',
  'Diagnostics',
  'Agent IA',
  'Backoffice',
];

/// Un défaut relevé : où, dans quelles conditions, et quoi.
class _Finding {
  _Finding(this.where, this.size, this.theme, this.what, this.widget);
  final String where, size, theme, what, widget;
  @override
  String toString() => '[$size · $theme] $where → $what${widget.isEmpty ? '' : '\n      $widget'}';
}

class _NoScanDiscovery extends DiscoveryNotifier {
  _NoScanDiscovery(super.service, super.ref);
  @override
  Future<void> scan({bool autoConnect = false}) async {}
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(ThemeMode mode) {
    state = mode;
  }
}

void main() {
  final findings = <_Finding>[];
  var pumps = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({'tutorial_completed': true});
  });

  List<Override> overrides(ThemeMode theme) => [
        isSimulationModeProvider.overrideWith((ref) => true),
        discoveryProvider.overrideWith(
            (ref) => _NoScanDiscovery(ref.watch(autoDiscoveryServiceProvider), ref)),
        themeModeProvider.overrideWith((ref) => _FixedTheme(theme)),
      ];

  /// Monte [child] (ou l'application entière) et relève tout ce que Flutter
  /// signale pendant quelques frames.
  Future<void> sweep(
    WidgetTester tester, {
    required String where,
    required _Size size,
    required ThemeMode theme,
    Widget? child,
    void Function(ProviderContainer)? prepare,
  }) async {
    tester.view.physicalSize = Size(size.w, size.h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final seen = <String>{};
    final previous = FlutterError.onError;
    void record(FlutterErrorDetails d) {
      final text = d.toString();
      final what = d.exceptionAsString().split('\n').first.trim();
      final lines = text.split('\n');
      var widget = '';
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('relevant error-causing widget')) {
          widget = lines.skip(i + 1).take(2).map((l) => l.trim()).where((l) => l.isNotEmpty).join(' · ');
          break;
        }
      }
      final key = '$where|$what|$widget';
      if (seen.add(key)) {
        findings.add(_Finding(where, size.name, theme.name, what, widget));
      }
    }

    FlutterError.onError = record;
    final container = ProviderContainer(overrides: overrides(theme));
    try {
      prepare?.call(container);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: child == null
            ? const ForgeronApp()
            : MaterialApp(
                theme: ThemeData(brightness: theme == ThemeMode.dark ? Brightness.dark : Brightness.light),
                builder: (context, c) => c!,
                home: child,
              ),
      ));
      pumps++;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      // Les exceptions que le framework a gardées pour le test, s'il y en a.
      Object? e;
      while ((e = tester.takeException()) != null) {
        final what = '$e'.split('\n').first.trim();
        if (seen.add('$where|$what|')) findings.add(_Finding(where, size.name, theme.name, what, ''));
      }
      // Démonte proprement pour que les minuteries de la page meurent avant
      // la vérification du framework.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
      container.dispose();
    }
  }

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final size in _sizes) {
      for (var page = 0; page < _pages.length; page++) {
        testWidgets('${_pages[page]} · ${size.name} · ${theme.name}', (tester) async {
          await sweep(tester,
              where: _pages[page],
              size: size,
              theme: theme,
              prepare: (c) => c.read(selectedNavIndexProvider.notifier).state = page);
        });
      }
      testWidgets('Mode atelier · ${size.name} · ${theme.name}', (tester) async {
        await sweep(tester,
            where: 'Mode atelier',
            size: size,
            theme: theme,
            prepare: (c) => c.read(isWorkshopModeProvider.notifier).state = true);
      });
    }
  }

  // Les écrans poussés par navigation, hors du scaffold principal.
  final standalone = <String, Widget Function()>{
    'Paramètres': () => const AppSettingsScreen(),
    'Paramètres de l\'agent': () => const AiAgentSettingsScreen(),
    'Connexion': () => const ConnectionSettingsScreen(),
    'Backoffice (mobile)': () => const BackofficeScreen(standalone: true),
    'Pupitre CNC': () => const CncPanelScreen(),
    'Limites': () => const LimitConfigScreen(),
    'Reprise après limite': () => const LimitRecoveryScreen(),
    'Test fins de course': () => const LimitSwitchTestScreen(),
    'Calibration machine': () => const MachineCalibrationScreen(),
    'Chat à distance': () => const RemoteChatScreen(),
    'Assistant de mise en route': () => const SetupWizardScreen(),
  };
  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final size in [_sizes[0], _sizes[1], _sizes[3], _sizes[6]]) {
      for (final entry in standalone.entries) {
        testWidgets('${entry.key} · ${size.name} · ${theme.name}', (tester) async {
          await sweep(tester, where: entry.key, size: size, theme: theme, child: entry.value());
        });
      }
    }
  }

  tearDownAll(() {
    final buffer = StringBuffer()
      ..writeln('Balayage de mise en page — $pumps montages, ${findings.length} défaut(s)')
      ..writeln();
    final byWhere = <String, List<_Finding>>{};
    for (final f in findings) {
      byWhere.putIfAbsent(f.where, () => []).add(f);
    }
    for (final e in byWhere.entries) {
      buffer.writeln('── ${e.key} (${e.value.length})');
      for (final f in e.value) {
        buffer.writeln('  $f');
      }
      buffer.writeln();
    }
    final report = buffer.toString();
    try {
      File('build/layout_sweep.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(report);
    } catch (_) {}
    // ignore: avoid_print
    print(report);
    expect(findings, isEmpty, reason: 'des défauts de mise en page subsistent (voir build/layout_sweep.txt)');
  });
}
