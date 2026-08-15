import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/chat_markdown.dart';
import 'package:forgeron/core/utils/gemini_context.dart';

void main() {
  group('parseChatBlocks', () {
    test('texte sans bloc de code → un seul bloc de prose', () {
      final blocks = parseChatBlocks('La position X est de 12,5 mm.');
      expect(blocks, hasLength(1));
      expect(blocks.first.isCode, isFalse);
      expect(blocks.first.text, contains('12,5 mm'));
    });

    test('sépare prose, code et prose', () {
      final blocks = parseChatBlocks(
        'Voici le programme :\n'
        '```gcode\n'
        'G0 X0 Y0\n'
        'G1 Z-5 F100\n'
        '```\n'
        'Vérifie le dégagement Z avant de lancer.',
      );
      expect(blocks, hasLength(3));
      expect(blocks[0].isCode, isFalse);
      expect(blocks[1].isCode, isTrue);
      expect(blocks[1].lang, 'gcode');
      expect(blocks[1].text.trim(), 'G0 X0 Y0\nG1 Z-5 F100');
      expect(blocks[2].isCode, isFalse);
      expect(blocks[2].text, contains('dégagement'));
    });

    test('bloc encore ouvert (streaming) rendu comme du code', () {
      // Pendant la génération, la clôture ``` n'est pas encore arrivée : le
      // code doit quand même s'afficher en monospace, pas en texte brut.
      final blocks = parseChatBlocks('Programme :\n```gcode\nG0 X10\nG1 Y2');
      expect(blocks, hasLength(2));
      expect(blocks[1].isCode, isTrue);
      expect(blocks[1].lang, 'gcode');
      expect(blocks[1].text, contains('G0 X10'));
    });

    test('deux blocs de code successifs', () {
      final blocks = parseChatBlocks('```nc\nG0 X1\n```\net\n```nc\nG0 X2\n```');
      final codes = blocks.where((b) => b.isCode).toList();
      expect(codes, hasLength(2));
      expect(codes[0].text.trim(), 'G0 X1');
      expect(codes[1].text.trim(), 'G0 X2');
    });

    test('langage absent → bloc de code quand même', () {
      final blocks = parseChatBlocks('```\nG0 X0\n```');
      expect(blocks.single.isCode, isTrue);
      expect(blocks.single.lang, isEmpty);
    });
  });

  group('looksLikeGcode', () {
    test('reconnaît les langages de programme machine', () {
      for (final lang in ['gcode', 'nc', 'ngc', 'tap', 'cnc']) {
        expect(looksLikeGcode(ChatBlock('x', isCode: true, lang: lang)), isTrue,
            reason: lang);
      }
    });

    test('un autre langage annoncé n\'est pas du G-code', () {
      expect(
        looksLikeGcode(ChatBlock('print(1)', isCode: true, lang: 'python')),
        isFalse,
      );
    });

    test('sans langage annoncé, se fie à la forme du contenu', () {
      expect(looksLikeGcode(ChatBlock('G0 X0 Y0\nM3 S1000', isCode: true)),
          isTrue);
      expect(looksLikeGcode(ChatBlock('bonjour le monde', isCode: true)),
          isFalse);
    });
  });

  group('compactGeminiContents', () {
    /// Un tour complet : message utilisateur, appel d'outil du modèle, réponse
    /// d'outil, puis réponse texte. C'est le motif que la compaction doit
    /// préserver intact du point de vue du protocole.
    List<Map<String, dynamic>> turn(String question, String toolResult) => [
          {
            'role': 'user',
            'parts': [
              {'text': question},
            ],
          },
          {
            'role': 'model',
            'parts': [
              {
                'functionCall': {'name': 'get_config', 'args': {}},
              },
            ],
          },
          {
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'name': 'get_config',
                  'response': {'result': toolResult},
                },
              },
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'text': 'Voilà.'},
            ],
          },
        ];

    /// Chaque functionCall doit avoir sa functionResponse, sinon Gemini rejette
    /// tout le fil (HTTP 400) — c'est l'invariant central de la compaction.
    void expectPaired(List<Map<String, dynamic>> contents) {
      var openCalls = 0;
      for (final entry in contents) {
        final parts = entry['parts'];
        if (parts is! List) continue;
        for (final p in parts) {
          if (p is! Map) continue;
          if (p.containsKey('functionCall')) openCalls++;
          if (p.containsKey('functionResponse')) openCalls--;
        }
      }
      expect(openCalls, 0,
          reason: 'appels d\'outils non appairés après compaction');
    }

    test('ne touche à rien sous le budget', () {
      final contents = turn('salut', 'petit résultat');
      final before = jsonEncode(contents);
      compactGeminiContents(contents);
      expect(jsonEncode(contents), before);
    });

    test('abrège les gros résultats d\'outils anciens', () {
      final contents = <Map<String, dynamic>>[];
      for (var i = 0; i < 8; i++) {
        contents.addAll(turn('question $i', 'X' * 3000));
      }
      compactGeminiContents(contents, maxChars: 20000, keepIntact: 4);

      // Le premier résultat d'outil (ancien) doit être abrégé…
      final oldResult = ((contents[2]['parts'] as List).first
          as Map)['functionResponse']['response']['result'] as String;
      expect(oldResult, contains('abrégé'));
      expect(oldResult.length, lessThan(3000));
      expectPaired(contents);
    });

    test('coupe la tête sans casser de paire appel/réponse', () {
      final contents = <Map<String, dynamic>>[];
      for (var i = 0; i < 30; i++) {
        contents.addAll(turn('question $i', 'Y' * 2000));
      }
      final originalLength = contents.length;
      compactGeminiContents(contents, maxChars: 8000, keepIntact: 4);

      expect(contents.length, lessThan(originalLength));
      expectPaired(contents);
      // La 1re entrée restante doit être un vrai message utilisateur, pas une
      // réponse d'outil orpheline.
      final firstParts = contents.first['parts'] as List;
      expect(contents.first['role'], 'user');
      expect(
        firstParts.any((p) => p is Map && p.containsKey('functionResponse')),
        isFalse,
      );
    });

    test('préserve les dernières entrées (keepIntact)', () {
      final contents = <Map<String, dynamic>>[];
      for (var i = 0; i < 20; i++) {
        contents.addAll(turn('question $i', 'Z' * 2000));
      }
      compactGeminiContents(contents, maxChars: 9000, keepIntact: 4);

      // Le tout dernier résultat d'outil ne doit pas avoir été abrégé.
      final lastToolEntry = contents.lastWhere((e) {
        final parts = e['parts'];
        return parts is List &&
            parts.any((p) => p is Map && p.containsKey('functionResponse'));
      });
      final result = ((lastToolEntry['parts'] as List).first
          as Map)['functionResponse']['response']['result'] as String;
      expect(result, isNot(contains('abrégé')));
    });

    test('sans frontière sûre, préfère un contexte trop gros à un fil invalide',
        () {
      // Uniquement des paires appel/réponse : aucune coupe n'est sûre.
      final contents = <Map<String, dynamic>>[
        {
          'role': 'user',
          'parts': [
            {'text': 'go'},
          ],
        },
        for (var i = 0; i < 6; i++) ...[
          {
            'role': 'model',
            'parts': [
              {
                'functionCall': {'name': 'get_config', 'args': {}},
              },
            ],
          },
          {
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'name': 'get_config',
                  'response': {'result': 'W' * 2000},
                },
              },
            ],
          },
        ],
      ];
      compactGeminiContents(contents, maxChars: 100, keepIntact: 2);
      expectPaired(contents);
    });
  });

  group('safeCutIndex', () {
    test('retourne 0 quand aucune frontière n\'est disponible', () {
      final contents = <Map<String, dynamic>>[
        {
          'role': 'user',
          'parts': [
            {'text': 'a'},
          ],
        },
        {
          'role': 'model',
          'parts': [
            {'text': 'b'},
          ],
        },
      ];
      expect(safeCutIndex(contents, 10), 0);
    });

    test('saute les messages utilisateur porteurs de functionResponse', () {
      final contents = <Map<String, dynamic>>[
        {
          'role': 'user',
          'parts': [
            {'text': 'q0'},
          ],
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'x',
                'response': {'result': 'r'},
              },
            },
          ],
        },
        {
          'role': 'user',
          'parts': [
            {'text': 'q1'},
          ],
        },
        {
          'role': 'model',
          'parts': [
            {'text': 'a'},
          ],
        },
      ];
      // L'index 1 porte une functionResponse → la frontière sûre est l'index 2.
      expect(safeCutIndex(contents, 0), 2);
    });
  });
}
