import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/core/theme/forgeron_colors.dart';
import 'package:forgeron/presentation/screens/ai_agent_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_machine_repository.dart';

/// L'interrupteur « Traduire les réponses du modèle local » des réglages de
/// l'agent coupe et rallume le traducteur (`LocalTranslator`).
void main() {
  testWidgets('l\'interrupteur de traduction coupe puis rallume le réglage',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
      lexiconSourceProvider.overrideWithValue(
          () async => File('assets/lexicon/lexique.json').readAsString()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: ForgeronTheme(
        colors: forgeronDarkColors,
        child: const MaterialApp(home: AiAgentSettingsScreen()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final title = find.text('Traduire les réponses du modèle local');
    await tester.scrollUntilVisible(title, 300,
        scrollable: find.byType(Scrollable).first);
    expect(title, findsOneWidget);
    expect(find.textContaining('Kiswahili'), findsOneWidget);
    expect(find.textContaining('gemma3:12b'), findsOneWidget);

    final toggle = find.descendant(
      of: find.ancestor(of: title, matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );
    expect(container.read(aiAgentSettingsProvider).localTranslatorEnabled,
        isTrue);
    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(aiAgentSettingsProvider).localTranslatorEnabled,
        isFalse);
    expect(find.textContaining('Coupée'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(container.read(aiAgentSettingsProvider).localTranslatorEnabled,
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
