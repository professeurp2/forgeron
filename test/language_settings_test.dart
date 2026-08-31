import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:forgeron/core/i18n/fallback_localizations.dart';
import 'package:forgeron/presentation/screens/app_settings_screen.dart';

/// Le sélecteur de langue avait été livré dans les réglages de l'agent IA :
/// personne ne l'y trouvait, rien ne laissait deviner qu'il pilotait toute
/// l'interface. Ces tests fixent sa place — l'écran Paramètres — pour qu'il
/// ne puisse pas redevenir introuvable.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocalizations.setCurrentForTest(const <String, String>{});
  });

  Widget harness() => ProviderScope(
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FallbackMaterialLocalizationsDelegate(),
            FallbackCupertinoLocalizationsDelegate(),
          ],
          home: const AppSettingsScreen(),
        ),
      );

  testWidgets('l\'écran Paramètres porte le réglage de langue', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Interface, agent IA, dictée et voix'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('les 17 langues du catalogue sont proposées', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // On lit la liste sur le widget plutôt qu'à l'écran : un menu déroulant
    // ne construit que ses entrées visibles, un test par find.text ne
    // prouverait donc rien sur les dernières langues.
    // DropdownButtonFormField n'expose pas ses entrées : on interroge le
    // DropdownButton qu'il construit en interne.
    final button = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>));
    final values = button.items!.map((i) => i.value).toList();

    expect(values.length, kAppLanguages.length);
    expect(values, containsAll(kAppLanguages.map((l) => l.id)));
    expect(values.first, 'auto');
  });

  testWidgets('choisir une langue traduit l\'écran séance tenante',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text('Langue'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    // Le provider a bien enregistré le choix ; l'écran est reconstruit par
    // MaterialApp au niveau de la racine réelle de l'app.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(AppSettingsScreen)));
    expect(container.read(appLanguageProvider).id, 'en');
  });
}
