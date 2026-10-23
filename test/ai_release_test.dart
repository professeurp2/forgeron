import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart'
    show AiAgentController;
import 'package:forgeron/application/services/ai_agent_tools.dart';

import '../tool/eval/bench_core.dart' show fingerprint;

/// « Pas de changement non mesuré. »
///
/// `tool/eval/ai_release.json` est la fiche de la dernière version de l'IA
/// **mesurée** par Forgeron-Bench : empreinte du prompt, empreinte des outils,
/// rapport à l'appui. Ce test la compare au code. Si le prompt ou un outil a
/// changé depuis, la suite échoue — et dit quoi faire. C'est la porte de
/// publication d'une version IA, sans qu'il faille un serveur de modèle.
void main() {
  final file = File('tool/eval/ai_release.json');

  test('le prompt et les outils sont ceux de la dernière version mesurée', () {
    if (!file.existsSync()) {
      markTestSkipped('Aucune version IA promue pour l\'instant. Lancer le banc '
          'avec BENCH_PROMOTE=<id> (voir tool/eval/README.md).');
      return;
    }
    final release = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final declarations = AiToolCatalog.tools
        .map((t) => t.toGeminiFunctionDeclaration())
        .toList();
    // ignore: invalid_use_of_visible_for_testing_member
    final basePrompt = AiAgentController.baseSystemPrompt;

    const howTo = 'Le prompt ou les outils ont changé depuis la dernière '
        'mesure (version « %ID% »). Relance le banc, vérifie qu\'il ne '
        'régresse pas, puis promeus la nouvelle version :\n'
        '  \$env:BENCH_PROMOTE="<nouvel-id>"; flutter test '
        'tool/eval/forgeron_bench_test.dart\n'
        'Commit : tool/eval/ai_release.json et docs/addis/evidence/.';
    final reason = howTo.replaceFirst('%ID%', '${release['id']}');

    expect(fingerprint(basePrompt), release['base_prompt_fingerprint'],
        reason: 'Prompt. $reason');
    expect(fingerprint(jsonEncode(declarations)), release['tools_fingerprint'],
        reason: 'Outils. $reason');
    expect(declarations.length, release['tool_count'], reason: reason);
  });

  test('la fiche renvoie à un rapport qui existe', () {
    if (!file.existsSync()) {
      markTestSkipped('Aucune version IA promue pour l\'instant.');
      return;
    }
    final release = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final report = File('${release['bench_report']}');
    expect(report.existsSync(), isTrue,
        reason: 'Le rapport « ${release['bench_report']} » est introuvable : '
            'une version sans mesure à l\'appui n\'est pas une version.');
    expect(release['headline'], isA<Map>());
    expect((release['headline'] as Map)['runs'], greaterThan(0));
  });
}
