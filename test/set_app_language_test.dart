import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:forgeron/application/providers/activity_log_provider.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/command_understanding.dart';
import 'package:forgeron/application/services/tool_router.dart';
import 'package:forgeron/core/i18n/app_language.dart';

/// L'outil qui laisse l'agent mettre l'interface dans la langue de
/// l'opérateur. Son déclencheur est la LANGUE du message, pas un mot : d'où
/// les deux premiers tests, qui vérifient qu'il est atteignable à chaque tour
/// plutôt que routé par mots-clés.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outil = AiToolCatalog.byName('set_app_language');

  test('l\'outil existe et n\'est pas derrière une porte de confirmation', () {
    expect(outil, isNotNull);
    // Changer une langue ne fait pas bouger la machine et se défait en deux
    // touches : le gater reviendrait à demander une permission pour rien.
    expect(outil!.category, isNull);
  });

  test('il est toujours déclaré, et compte comme une action', () {
    // Aucun mot-clé ne peut attraper « l'opérateur écrit en bambara » : si le
    // routeur pouvait le retirer, la détection de langue ne marcherait que
    // par hasard.
    expect(ToolRouter.core, contains('set_app_language'));
    // En revanche il écrit un réglage : il doit disparaître des tours mis en
    // lecture seule par le lexique.
    expect(isReadOnlyToolName('set_app_language'), isFalse);
  });

  group('exécution', () {
    late ProviderContainer c;
    late Ref ref;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      c = ProviderContainer();
      ref = c.read(Provider((r) => r));
    });
    tearDown(() => c.dispose());

    Future<Map<String, dynamic>> appelle(String code) async =>
        jsonDecode(await outil!.execute({'language': code}, ref))
            as Map<String, dynamic>;

    test('bascule l\'interface et dit d\'où elle vient', () async {
      final j = await appelle('bm');
      expect(j['ok'], isTrue);
      expect(j['change'], isTrue);
      expect(j['precedente'], 'auto');
      expect(j['langue'], 'bm');
      expect(c.read(appLanguageProvider).id, 'bm');
    });

    test('accepte la forme régionale que donnent souvent les modèles',
        () async {
      final j = await appelle('SW-KE');
      expect(j['langue'], 'sw');
      expect(c.read(appLanguageProvider).id, 'sw');
    });

    test('refuse un code inconnu au lieu de deviner', () async {
      final j = await appelle('klingon');
      expect(j['ok'], isFalse);
      expect('${j['raison']}', contains('klingon'));
      expect(j['codes_acceptes'], contains('bm'));
      // Surtout : rien n'a bougé.
      expect(c.read(appLanguageProvider).id, 'auto');
    });

    test('un code vide ne change rien non plus', () async {
      final j = await appelle('   ');
      expect(j['ok'], isFalse);
      expect(c.read(appLanguageProvider).id, 'auto');
    });

    test('redemander la langue courante ne la rebascule pas', () async {
      await appelle('sw');
      final j = await appelle('sw');
      expect(j['ok'], isTrue);
      expect(j['change'], isFalse);
    });

    test('annonce la couverture réelle, sans la surestimer', () async {
      final j = await appelle('bm');
      // Le nombre vient du dictionnaire chargé, pas d'une promesse : c'est ce
      // qui permet à l'agent de prévenir que le reste restera en français.
      expect(j['libelles_traduits'], isA<int>());
      expect(j['relu_par_un_locuteur'], isFalse);
      expect('${j['retour_arriere']}', contains('Paramètres'));
    });

    test('le français est annoncé comme la langue source', () async {
      final j = await appelle('fr');
      expect(j['libelles_traduits'], 'source');
    });

    test('le changement laisse une trace dans le journal machine', () async {
      await appelle('bm');
      final journal = c.read(activityLogProvider);
      expect(journal.entries.map((e) => e.text).join(' '), contains('bm'));
    });
  });
}
