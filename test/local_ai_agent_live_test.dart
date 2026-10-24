import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart'
    show AiAgentController;
import 'package:forgeron/application/services/ai_agent_service.dart'
    show AiApiResponse;
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/core/utils/gemini_context.dart';
import 'package:http/http.dart' as http;

/// Le fournisseur local face à un VRAI serveur — pas à des JSON écrits à la
/// main.
///
/// `local_ai_agent_service_test.dart` verrouille la traduction Gemini ↔ OpenAI
/// sur des exemples ; il ne peut pas dire si un vrai Ollama parle ce
/// protocole, ni si son modèle comprend la vraie charge utile de l'agent (le
/// prompt système réel et les 38 outils réels). Ces tests le disent.
///
/// Ils se SAUTENT d'eux-mêmes quand aucun serveur ne répond, donc la suite
/// reste verte sur un poste sans Ollama. Réglages :
///
///   FORGERON_LOCAL_URL    (défaut http://localhost:11434)
///   FORGERON_LOCAL_MODEL  (défaut forgeron-qwen — voir tool/ollama/Modelfile)
void main() {
  final url = LocalAiAgentService.normalizeBaseUrl(
      Platform.environment['FORGERON_LOCAL_URL'] ?? 'http://localhost:11434');
  final model = Platform.environment['FORGERON_LOCAL_MODEL'] ?? 'forgeron-qwen';

  var live = false;
  late LocalModelInfo info;
  late LocalAiAgentService service;

  setUpAll(() async {
    try {
      final tags = await http
          .get(Uri.parse('$url/api/tags'))
          .timeout(const Duration(seconds: 3));
      live = tags.statusCode == 200 && tags.body.contains('"$model');
    } catch (_) {
      live = false;
    }
    if (!live) return;
    info = await LocalAiAgentService.probe(url, model);
    service = LocalAiAgentService(baseUrl: url, model: model, info: info);
  });

  tearDownAll(() {
    if (live) service.dispose();
  });

  /// Saute le test si aucun serveur ne sert [model]. Retourne vrai si on doit
  /// s'arrêter là.
  bool absent() {
    if (live) return false;
    markTestSkipped('Aucun serveur local ne sert « $model » sur $url.');
    return true;
  }

  final declarations =
      AiToolCatalog.tools.map((t) => t.toGeminiFunctionDeclaration()).toList();
  final toolNames = AiToolCatalog.tools.map((t) => t.name).toSet();

  // Ce qu'`AiAgentController._buildSystemPrompt` ajoute à la partie fixe, en
  // taille représentative : cinématique des cinq axes, directive de langue,
  // journal d'activité d'une douzaine de lignes.
  final dynamicTail = '''
Cinématique réelle (lue dans la config FluidNC de la machine) :
- X : course 80 mm, 264 pas/mm, F max 1000 mm/min, accél. 100 mm/s²
- Y : course 150 mm, 400 pas/mm, F max 1000 mm/min, accél. 100 mm/s²
- Z : course 110 mm, 400 pas/mm, F max 800 mm/min, accél. 80 mm/s²
- A : course 360 °, 16.667 pas/°, F max 2000 °/min, accél. 50 °/s²
- C : course 360 °, 16.667 pas/°, F max 2000 °/min, accél. 50 °/s²

Réponds en français.

=== JOURNAL D'ACTIVITÉ MACHINE (récent, opérateur + toi) ===
${List.generate(12, (i) => '12:${10 + i}:0$i opérateur : jog X+1.0 (F300)').join('\n')}''';

  final systemPrompt =
      '${AiAgentController.baseSystemPrompt}\n\n$dynamicTail';

  List<Map<String, dynamic>> ask(String text) => [
        {
          'role': 'user',
          'parts': [
            {'text': text}
          ]
        }
      ];

  /// Une discussion d'atelier d'une quarantaine d'échanges : question, appel
  /// d'outil, résultat JSON de taille variable, réponse en français. Assez
  /// longue pour que la compaction doive trancher.
  List<Map<String, dynamic>> longDiscussion() {
    const outils = ['get_machine_state', 'list_workspace_files', 'jog_axis'];
    const questions = [
      'Où en est la machine ?',
      'Quels fichiers j\'ai dans mon espace ?',
      'Avance X de 2 millimètres.',
    ];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < 40; i++) {
      final k = i % outils.length;
      final resultat = switch (k) {
        0 => jsonEncode({
            'status': 'Idle',
            'mpos': {'X': 10.0 + i, 'Y': 0.0, 'Z': -3.25, 'A': 0.0, 'C': 0.0},
            'wpos': {'X': 10.0 + i, 'Y': 0.0, 'Z': -3.25},
            'alarmes': <String>[],
          }),
        1 => jsonEncode({
            'fichiers': [
              for (var f = 0; f < 12; f++)
                {'nom': 'piece_${i}_$f.nc', 'taille': 1200 + f * 37}
            ]
          }),
        _ => jsonEncode({'ok': true, 'axe': 'X', 'distance': 2.0}),
      };
      out.addAll([
        {
          'role': 'user',
          'parts': [
            {'text': '${questions[k]} (essai $i)'}
          ]
        },
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': outils[k],
                'args': k == 2 ? {'axis': 'X', 'distance': 2.0} : {}
              }
            }
          ]
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': outils[k],
                'response': {'result': resultat}
              }
            }
          ]
        },
        {
          'role': 'model',
          'parts': [
            {
              'text': switch (k) {
                0 => 'La machine est au repos, X à ${10 + i} mm, aucune '
                    'alarme. Tu peux lancer la suite quand tu veux.',
                1 => 'Ton espace contient 12 programmes, de piece_${i}_0.nc '
                    'à piece_${i}_11.nc. Dis-moi lequel examiner.',
                _ => 'L\'axe X a avancé de 2 mm. Je ne touche à rien d\'autre '
                    'tant que tu ne me le demandes pas.',
              }
            }
          ]
        },
      ]);
    }
    return out;
  }

  Map<String, dynamic>? firstCall(AiApiResponse r) {
    for (final p in r.parts) {
      if (p.containsKey('functionCall')) {
        return (p['functionCall'] as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  group('serveur local réel', () {
    test('le contexte du modèle est assez grand pour l\'agent', () {
      if (absent()) return;
      // ignore: avoid_print
      print('contexte détecté : ${info.contextTokens} tokens, '
          'images : ${info.supportsImages}');
      expect(service.configurationProblem, isNull,
          reason: 'Le modèle « $model » a un contexte trop court : '
              'ollama create forgeron-qwen -f tool/ollama/Modelfile');
    });

    test('la charge utile réelle tient dans la part réservée au prompt',
        () async {
      if (absent()) return;
      final r = await service.sendMessages(
        contents: ask('Bonjour'),
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
      // total = prompt + réponse ; la réponse à « Bonjour » pèse quelques
      // dizaines de tokens, négligeables devant le prompt.
      // ignore: avoid_print
      print('charge utile : ${r.totalTokens} tokens '
          '(${AiToolCatalog.tools.length} outils, prompt système '
          '${systemPrompt.length} caractères, déclarations '
          '${jsonEncode(declarations).length} caractères)');
      expect(r.totalTokens, lessThanOrEqualTo(
          LocalAiAgentService.promptOverheadTokens),
          reason: 'Le prompt système + les outils dépassent la part prévue '
              '(promptOverheadTokens) : le budget d\'historique des modèles '
              'locaux serait trop généreux et le serveur tronquerait le '
              'prompt. Réévalue la constante.');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('une question sans outil reçoit du texte, pas un appel d\'outil',
        () async {
      if (absent()) return;
      final r = await service.sendMessages(
        contents: ask('Bonjour, que peux-tu faire pour moi ?'),
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
      expect(r.text.trim(), isNotEmpty);
      expect(firstCall(r), isNull);
      expect(r.finishReason, 'STOP');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('« état de la machine » déclenche l\'outil de lecture, bien nommé',
        () async {
      if (absent()) return;
      final r = await service.sendMessages(
        contents: ask('Donne-moi l\'état de la machine.'),
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
      final call = firstCall(r);
      // ignore: avoid_print
      print('appel : ${jsonEncode(call)}');
      expect(call, isNotNull, reason: 'texte reçu : ${r.text}');
      expect(toolNames, contains(call!['name']),
          reason: 'le modèle a inventé un outil');
      expect(call['name'], 'get_machine_state');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('le streaming rend le même appel d\'outil que le mode complet',
        () async {
      if (absent()) return;
      final deltas = <String>[];
      final r = await service.streamMessages(
        contents: ask('Liste les fichiers de mon espace de travail.'),
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
        onDelta: deltas.add,
      );
      final call = firstCall(r);
      // ignore: avoid_print
      print('appel streamé : ${jsonEncode(call)}');
      expect(call, isNotNull, reason: 'texte reçu : ${r.text}');
      expect(call!['name'], 'list_workspace_files');
      expect(r.totalTokens, greaterThan(0),
          reason: 'le fragment d\'usage final a été perdu');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('l\'argument d\'un outil est extrait correctement', () async {
      if (absent()) return;
      final r = await service.sendMessages(
        contents: ask('Déplace l\'axe X de 5 millimètres.'),
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
      final call = firstCall(r);
      // ignore: avoid_print
      print('appel : ${jsonEncode(call)}');
      expect(call, isNotNull, reason: 'texte reçu : ${r.text}');
      expect(call!['name'], 'jog_axis');
      final args = (call['args'] as Map).cast<String, dynamic>();
      expect('${args['axis']}'.toUpperCase(), 'X');
      expect(num.parse('${args['distance']}'), 5);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('la réponse d\'un outil est comprise au tour suivant', () async {
      if (absent()) return;
      // Historique tel que le produit AiAgentController : au format Gemini, la
      // réponse relie son appel par le NOM — c'est le client qui fabrique les
      // identifiants OpenAI.
      final r = await service.sendMessages(
        contents: [
          ...ask('Quelle est la position de la machine ?'),
          {
            'role': 'model',
            'parts': [
              {
                'functionCall': {'name': 'get_machine_state', 'args': {}}
              }
            ]
          },
          {
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'name': 'get_machine_state',
                  'response': {
                    'result': jsonEncode({
                      'status': 'Idle',
                      'mpos': {'X': 12.5, 'Y': 0.0, 'Z': -3.25},
                    })
                  }
                }
              }
            ]
          },
        ],
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
      // ignore: avoid_print
      print('réponse : ${r.text}');
      expect(firstCall(r), isNull, reason: 'le modèle a rappelé un outil');
      expect(r.text, contains('12'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('une longue discussion ne fait pas dérailler l\'appel d\'outil',
        () async {
      if (absent()) return;
      // Le piège de la fiabilité, pas de la place : la fenêtre n'est PAS
      // pleine, mais un 7B noyé sous trop d'historique répond de mémoire au
      // lieu d'appeler l'outil (il recopie une ancienne position comme si elle
      // était actuelle). Une vraie discussion rejouée 30 fois donnait 18/30 à
      // 22 000 caractères d'historique, 29/30 à 12 000.
      //
      // Cette discussion-ci est volontairement extrême — 40 interrogations
      // d'état d'affilée. Mesuré : 7 à 12 bons appels sur 20, quel que soit le
      // plafond testé (4 000 à 22 000) : le plafond limite le mal sans le
      // supprimer. Le test n'est donc PAS une barre de qualité ; il garantit
      // seulement que l'appel d'outil ne s'effondre pas (protocole cassé,
      // identifiants orphelins après compaction) et affiche le taux mesuré.
      final histoire = longDiscussion();
      var bons = 0;
      var tokens = 0;
      const essais = 10;
      for (var i = 0; i < essais; i++) {
        final contents = [
          for (final c in histoire) jsonDecode(jsonEncode(c)) as Map<String, dynamic>,
          ...ask('Donne-moi l\'état de la machine.'),
        ];
        compactGeminiContents(contents, maxChars: service.historyBudgetChars);
        final r = await service.sendMessages(
          contents: contents,
          functionDeclarations: declarations,
          systemPrompt: systemPrompt,
        );
        tokens = r.totalTokens;
        if (firstCall(r)?['name'] == 'get_machine_state') {
          bons++;
        } else {
          // ignore: avoid_print
          print('  raté : appel=${jsonEncode(firstCall(r))} '
              'texte=${r.text.replaceAll('\n', ' ')}');
        }
      }
      // ignore: avoid_print
      print('longue discussion : $bons/$essais bons appels, $tokens tokens '
          '(budget ${service.historyBudgetChars} caractères)');
      expect(bons, greaterThanOrEqualTo(1),
          reason: 'Aucun appel d\'outil correct sur $essais essais avec un '
              'historique de ${service.historyBudgetChars} caractères : '
              'l\'appel d\'outil est cassé quand l\'historique est long.');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('le début du prompt n\'est pas perdu quand l\'historique grossit',
        () async {
      if (absent()) return;
      // Le piège documenté : un contexte trop petit tronque le prompt par le
      // DÉBUT, sans erreur. Une consigne placée en tête en est la première
      // victime.
      const secret = 'ZEPHYR-4471';
      final filler = ('La fraise boule de six millimètres suit la surface. ' * 40 +
              '\n') *
          8;
      final r = await service.sendMessages(
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': filler},
            ]
          },
          {
            'role': 'model',
            'parts': [
              {'text': 'Compris.'}
            ]
          },
          ...ask('Quel est le code secret ? Réponds uniquement par le code.'),
        ],
        functionDeclarations: const [],
        systemPrompt:
            'CODE SECRET À RETENIR : $secret. Si on te demande le code '
            'secret, donne-le.\n$systemPrompt',
      );
      // ignore: avoid_print
      print('contexte utilisé : ${r.totalTokens} tokens → « ${r.text.trim()} »');
      expect(r.text, contains(secret),
          reason: 'Le début du prompt a été tronqué : le contexte effectif '
              'du modèle est plus petit que le prompt.');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('une image n\'interrompt pas la discussion d\'un modèle texte seul',
        () async {
      if (absent()) return;
      if (info.supportsImages) {
        markTestSkipped('« $model » lit les images : rien à contourner.');
        return;
      }
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8Dw'
          'HwAFBQIAX8jx0gAAAABJRU5ErkJggg==';
      final r = await service.sendMessages(
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'Voici une capture de la caméra.'},
              {
                'inlineData': {'mimeType': 'image/png', 'data': png}
              },
            ]
          },
        ],
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
      // ignore: avoid_print
      print('réponse : ${r.text}');
      expect(r.text.trim(), isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
