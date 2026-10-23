import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/core/utils/gemini_context.dart' show kMaxContextChars;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Traduction Gemini ↔ OpenAI du fournisseur d'agent local.
///
/// Le reste de l'application ne parle que Gemini ; c'est ce service qui
/// traduit. Ces tests verrouillent la partie subtile — l'appariement des
/// appels d'outils — parce qu'une erreur y est silencieuse : le serveur
/// répond, mais le fil devient incohérent au deuxième tour.
void main() {
  group('Gemini → OpenAI : messages', () {
    test('le prompt système ouvre la liste', () {
      final msgs = LocalAiAgentService.toOpenAiMessages(
        [
          {
            'role': 'user',
            'parts': [
              {'text': 'Quelle est la position ?'}
            ]
          },
        ],
        'Tu es l\'assistant de Forgeron.',
      );

      expect(msgs.first['role'], 'system');
      expect(msgs.first['content'], 'Tu es l\'assistant de Forgeron.');
      expect(msgs[1], {'role': 'user', 'content': 'Quelle est la position ?'});
    });

    test('le rôle « model » de Gemini devient « assistant »', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'model',
          'parts': [
            {'text': 'La broche est à l\'arrêt.'}
          ]
        },
      ], null);

      expect(msgs.single['role'], 'assistant');
      expect(msgs.single['content'], 'La broche est à l\'arrêt.');
    });

    test('un appel d\'outil et sa réponse partagent le même tool_call_id', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': 'get_machine_state',
                'args': <String, dynamic>{},
              }
            }
          ]
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'get_machine_state',
                'response': {'result': '{"status":"idle"}'},
              }
            }
          ]
        },
      ], null);

      final assistant = msgs.firstWhere((m) => m['role'] == 'assistant');
      final tool = msgs.firstWhere((m) => m['role'] == 'tool');
      final call = (assistant['tool_calls'] as List).single as Map;

      expect(call['function']['name'], 'get_machine_state');
      expect(tool['tool_call_id'], call['id'],
          reason: 'Gemini apparie par NOM, OpenAI par identifiant : sans ce '
              'lien le serveur rejette le fil.');
    });

    test('deux appels du MÊME outil gardent des identifiants distincts, '
        'appariés dans l\'ordre', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': 'read_workspace_file',
                'args': {'path': 'a.nc'}
              }
            },
            {
              'functionCall': {
                'name': 'read_workspace_file',
                'args': {'path': 'b.nc'}
              }
            },
          ]
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'read_workspace_file',
                'response': {'result': 'contenu de a'}
              }
            },
            {
              'functionResponse': {
                'name': 'read_workspace_file',
                'response': {'result': 'contenu de b'}
              }
            },
          ]
        },
      ], null);

      final calls =
          (msgs.firstWhere((m) => m['role'] == 'assistant')['tool_calls']
              as List);
      final tools = msgs.where((m) => m['role'] == 'tool').toList();

      expect(calls.length, 2);
      expect(tools.length, 2);
      expect((calls[0] as Map)['id'], isNot((calls[1] as Map)['id']));
      expect(tools[0]['tool_call_id'], (calls[0] as Map)['id']);
      expect(tools[1]['tool_call_id'], (calls[1] as Map)['id']);
      expect(jsonDecode(tools[0]['content'] as String)['result'], 'contenu de a');
      expect(jsonDecode(tools[1]['content'] as String)['result'], 'contenu de b');
    });

    test('les arguments d\'appel sont sérialisés en JSON', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': 'jog_axis',
                'args': {'axis': 'X', 'distance': 10.5}
              }
            }
          ]
        },
      ], null);

      final call = ((msgs.single['tool_calls'] as List).single as Map);
      final args = jsonDecode(call['function']['arguments'] as String) as Map;
      expect(args['axis'], 'X');
      expect(args['distance'], 10.5);
    });

    test('une image devient un contenu multipart avec data URI', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'user',
          'parts': [
            {'text': 'Regarde cette pièce'},
            {
              'inlineData': {'mimeType': 'image/png', 'data': 'QUJD'}
            },
          ]
        },
      ], null);

      final content = msgs.single['content'] as List;
      expect(content.first, {'type': 'text', 'text': 'Regarde cette pièce'});
      expect((content[1] as Map)['image_url']['url'],
          'data:image/png;base64,QUJD');
    });

    test('une réponse d\'outil orpheline reste exploitable', () {
      // La compaction de l'historique peut couper un appel en gardant sa
      // réponse : mieux vaut un identifiant dérivé du nom qu'un plantage.
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'get_config',
                'response': {'result': '{}'}
              }
            }
          ]
        },
      ], null);

      expect(msgs.single['role'], 'tool');
      expect(msgs.single['tool_call_id'], 'call_get_config');
    });
  });

  group('Gemini → OpenAI : déclarations d\'outils', () {
    test('les types du schéma repassent en minuscules, en profondeur', () {
      final tools = LocalAiAgentService.toOpenAiTools([
        {
          'name': 'run_gcode',
          'description': 'Exécute un programme',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'lines': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
              },
              'options': {
                'type': 'OBJECT',
                'properties': {
                  'dry_run': {'type': 'BOOLEAN'},
                },
              },
            },
            'required': ['lines'],
          },
        },
      ]);

      final params = tools.single['function']['parameters'] as Map;
      expect(tools.single['type'], 'function');
      expect(params['type'], 'object');
      expect(params['properties']['lines']['type'], 'array');
      expect(params['properties']['lines']['items']['type'], 'string');
      expect(params['properties']['options']['properties']['dry_run']['type'],
          'boolean');
      expect(params['required'], ['lines'],
          reason: 'les mots-clés hors « type » passent inchangés');
    });

    test('un objet sans propriétés reçoit un properties vide', () {
      // OpenAI refuse `{"type":"object"}` sans `properties`.
      final tools = LocalAiAgentService.toOpenAiTools([
        {
          'name': 'get_machine_state',
          'description': 'État courant',
          'parameters': {'type': 'OBJECT'},
        },
      ]);

      expect(tools.single['function']['parameters']['properties'],
          isA<Map>().having((m) => m.isEmpty, 'vide', true));
    });
  });

  group('OpenAI → Gemini : réponses', () {
    test('texte et appels d\'outils deviennent des parts', () {
      final r = LocalAiAgentService.fromOpenAiJson({
        'choices': [
          {
            'finish_reason': 'tool_calls',
            'message': {
              'content': 'Je vérifie.',
              'tool_calls': [
                {
                  'id': 'call_abc',
                  'type': 'function',
                  'function': {
                    'name': 'get_machine_state',
                    'arguments': '{"verbose":true}',
                  },
                },
              ],
            },
          },
        ],
        'usage': {'total_tokens': 412},
      });

      expect(r.text, 'Je vérifie.');
      expect(r.totalTokens, 412);
      expect(r.finishReason, 'STOP');
      expect(r.functionCalls.single['functionCall']['name'],
          'get_machine_state');
      expect(
          r.functionCalls.single['functionCall']['args'], {'verbose': true});
    });

    test('une réponse sans choix ne casse pas', () {
      final r = LocalAiAgentService.fromOpenAiJson({'choices': []});
      expect(r.parts, isEmpty);
      expect(r.finishReason, 'EMPTY');
    });

    test('finish_reason est traduit', () {
      expect(LocalAiAgentService.mapFinishReason('stop'), 'STOP');
      expect(LocalAiAgentService.mapFinishReason('tool_calls'), 'STOP');
      expect(LocalAiAgentService.mapFinishReason('length'), 'MAX_TOKENS');
      expect(LocalAiAgentService.mapFinishReason(null), '');
    });
  });

  group('robustesse des arguments', () {
    // Un petit modèle quantisé rend parfois des arguments malformés. Un appel
    // aux arguments vides, que l'outil rejettera proprement, vaut mieux qu'une
    // exception qui casse le tour entier.
    test('du JSON invalide donne des arguments vides plutôt qu\'une erreur',
        () {
      expect(LocalAiAgentService.decodeArgs('{"axis":'), isEmpty);
      expect(LocalAiAgentService.decodeArgs('pas du json'), isEmpty);
    });

    test('une chaîne vide ou nulle donne des arguments vides', () {
      expect(LocalAiAgentService.decodeArgs(''), isEmpty);
      expect(LocalAiAgentService.decodeArgs('   '), isEmpty);
      expect(LocalAiAgentService.decodeArgs(null), isEmpty);
    });

    test('un objet déjà décodé passe tel quel', () {
      expect(LocalAiAgentService.decodeArgs({'axis': 'Z'}), {'axis': 'Z'});
    });

    test('un JSON qui n\'est pas un objet est ignoré', () {
      expect(LocalAiAgentService.decodeArgs('[1,2,3]'), isEmpty);
    });
  });

  group('joignabilité', () {
    // Sur Android, l'agent exigeait la 4G avant CHAQUE envoi — même vers un
    // modèle local joint par le WiFi de l'atelier. Résultat : données mobiles
    // coupées = agent muet, au moment précisément où le hors-ligne sert.
    LocalAiAgentService avec(http.Client client) => LocalAiAgentService(
        baseUrl: 'http://192.168.0.120:11434', model: 'm', client: client);

    test('un modèle local n\'exige pas le réseau mobile, Gemini si', () {
      expect(avec(MockClient((_) async => http.Response('', 200))).usesCellular,
          isFalse);
      expect(AiAgentService(apiKey: 'k').usesCellular, isTrue);
    });

    test('joignable quand /v1/models répond 200', () async {
      final seen = <Uri>[];
      final s = avec(MockClient((req) async {
        seen.add(req.url);
        return http.Response('{"data":[]}', 200);
      }));
      expect(await s.isReachable(), isTrue);
      expect(seen.single.toString(), 'http://192.168.0.120:11434/v1/models');
    });

    test('injoignable sur refus de connexion ou statut d\'erreur', () async {
      expect(await avec(MockClient((_) async => throw Exception('refusé'))).isReachable(),
          isFalse);
      expect(await avec(MockClient((_) async => http.Response('nope', 503))).isReachable(),
          isFalse);
    });

    test('le message dit où chercher, sans parler de 4G', () {
      final msg = avec(MockClient((_) async => http.Response('', 200)))
          .unreachableMessage;
      expect(msg, contains('http://192.168.0.120:11434'));
      expect(msg, contains('Ollama'));
      expect(msg, isNot(contains('4G')));
      expect(AiAgentService(apiKey: 'k').unreachableMessage, contains('4G/5G'));
    });
  });

  group('dérive en chinois', () {
    // Relevé dans l'application : Qwen2.5 bascule en pleine phrase française
    // (« …à côté de la讨论中… ») et finit sa réponse dans cette langue.
    const derive = 'L\'aperçu a été affiché à côté de la讨论中。我已经生成了预览。';
    const propre = 'L\'aperçu a été affiché à côté de la discussion.';

    List<Map<String, dynamic>> question(String t) => [
          {
            'role': 'user',
            'parts': [
              {'text': t}
            ]
          }
        ];

    AiApiResponse reponse(String t, {String finish = 'STOP'}) => AiApiResponse(
        parts: [
          {'text': t}
        ],
        finishReason: finish,
        totalTokens: 100);

    test('reconnaît les caractères chinois, pas le français accentué', () {
      expect(LocalAiAgentService.containsCjk('讨论'), isTrue);
      expect(LocalAiAgentService.containsCjk('fin。'), isTrue);
      expect(LocalAiAgentService.containsCjk('Ｘ１'), isTrue);
      expect(LocalAiAgentService.containsCjk(propre), isFalse);
      expect(LocalAiAgentService.containsCjk('10776.68 mm³ • 45° Ø40 œuvre'),
          isFalse);
    });

    test('une réponse chinoise à une question française est une dérive', () {
      expect(
          LocalAiAgentService.driftedToChinese(
              reponse(derive), question('Ouvre l\'aperçu')),
          isTrue);
      expect(
          LocalAiAgentService.driftedToChinese(
              reponse(propre), question('Ouvre l\'aperçu')),
          isFalse);
    });

    test('si l\'opérateur écrit en chinois, la réponse chinoise est légitime',
        () {
      expect(
          LocalAiAgentService.driftedToChinese(
              reponse(derive), question('请打开预览')),
          isFalse);
    });

    test('un résultat d\'outil ne compte pas : on remonte à la vraie question',
        () {
      final contents = [
        ...question('Ouvre l\'aperçu'),
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {'name': 'preview_step_file', 'args': {}}
            }
          ]
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'preview_step_file',
                'response': {'result': '{"triangles": 284}'}
              }
            }
          ]
        },
      ];
      expect(LocalAiAgentService.driftedToChinese(reponse(derive), contents),
          isTrue);
    });

    test('une réponse annulée n\'est jamais retentée', () {
      expect(
          LocalAiAgentService.driftedToChinese(
              reponse(derive, finish: 'CANCELLED'), question('Salut')),
          isFalse);
    });

    // Serveur factice : sert `reponses` dans l'ordre, en flux ou non selon ce
    // que la requête demande, et garde les corps reçus.
    ({LocalAiAgentService service, List<Map<String, dynamic>> corps}) serveur(
        List<String> reponses) {
      final corps = <Map<String, dynamic>>[];
      final client = MockClient.streaming((request, body) async {
        final b = jsonDecode(await body.bytesToString()) as Map<String, dynamic>;
        corps.add(b);
        final texte = reponses[(corps.length - 1).clamp(0, reponses.length - 1)];
        final bytes = b['stream'] == true
            ? utf8.encode('data: ${jsonEncode({
                    'choices': [
                      {
                        'delta': {'content': texte},
                        'finish_reason': null
                      }
                    ]
                  })}\n\ndata: ${jsonEncode({
                    'choices': [],
                    'usage': {'total_tokens': 50}
                  })}\n\ndata: [DONE]\n\n')
            : utf8.encode(jsonEncode({
                'choices': [
                  {
                    'message': {'content': texte},
                    'finish_reason': 'stop'
                  }
                ],
                'usage': {'total_tokens': 50},
              }));
        return http.StreamedResponse(Stream.value(bytes), 200);
      });
      return (
        service: LocalAiAgentService(
            baseUrl: 'http://localhost:11434', model: 'm', client: client),
        corps: corps
      );
    }

    String systeme(Map<String, dynamic> corps) =>
        ((corps['messages'] as List).first as Map)['content'] as String;

    test('complet : redemande avec le rappel de langue et rend le français',
        () async {
      final s = serveur([derive, propre]);
      final r = await s.service.sendMessages(
          contents: question('Ouvre l\'aperçu'),
          functionDeclarations: const [],
          systemPrompt: 'Tu es un assistant.');
      expect(r.text, propre);
      expect(s.corps, hasLength(2));
      expect(systeme(s.corps[0]), 'Tu es un assistant.');
      expect(systeme(s.corps[1]),
          'Tu es un assistant.${LocalAiAgentService.languageReminder}');
      expect(r.totalTokens, 100, reason: 'les deux tentatives sont comptées');
    });

    test('complet : s\'arrête après le nombre de tentatives prévu', () async {
      final s = serveur([derive]);
      final r = await s.service.sendMessages(
          contents: question('Ouvre l\'aperçu'),
          functionDeclarations: const [],
          systemPrompt: 'S');
      expect(s.corps, hasLength(1 + LocalAiAgentService.maxLanguageRetries));
      expect(r.text, derive, reason: 'on rend la dernière, sans rien inventer');
    });

    test('complet : une réponse française n\'est jamais redemandée', () async {
      final s = serveur([propre]);
      await s.service.sendMessages(
          contents: question('Salut'),
          functionDeclarations: const [],
          systemPrompt: 'S');
      expect(s.corps, hasLength(1));
    });

    test('complet : un opérateur qui écrit en chinois n\'est pas contrarié',
        () async {
      final s = serveur([derive]);
      final r = await s.service.sendMessages(
          contents: question('请打开预览'),
          functionDeclarations: const [],
          systemPrompt: 'S');
      expect(s.corps, hasLength(1));
      expect(r.text, derive);
    });

    test('flux : l\'aperçu final est la réponse corrigée', () async {
      final s = serveur([derive, propre]);
      final apercus = <String>[];
      final r = await s.service.streamMessages(
          contents: question('Ouvre l\'aperçu'),
          functionDeclarations: const [],
          systemPrompt: 'S',
          onDelta: apercus.add);
      expect(r.text, propre);
      expect(apercus.first, derive);
      expect(apercus.last, propre,
          reason: 'l\'aperçu doit finir sur la réponse retenue');
      expect(s.corps, hasLength(2));
      expect(s.corps[0]['stream'], isTrue);
      expect(s.corps[1]['stream'], isFalse);
    });

    test('flux : annulé, on ne retente pas', () async {
      final s = serveur([derive]);
      final r = await s.service.streamMessages(
          contents: question('Ouvre l\'aperçu'),
          functionDeclarations: const [],
          systemPrompt: 'S',
          shouldCancel: () => true);
      expect(s.corps, hasLength(1));
      expect(r.finishReason, 'CANCELLED');
    });

    test('la nouvelle tentative est tracée dans les notes de la réponse',
        () async {
      final s = serveur([derive, propre]);
      final r = await s.service.sendMessages(
          contents: question('Ouvre l\'aperçu'),
          functionDeclarations: const [],
          systemPrompt: 'S');
      expect(r.notes, [LocalAiAgentService.noteLanguageRetry]);
    });

    group('réponse vide', () {
      // Mesuré au banc : 4 réponses vides sur 231 — « Arrête tout, c'est
      // urgent ! » une fois, « passe en mode maintenance » trois fois sur trois.
      test('redemandée une fois avec un rappel, puis rendue', () async {
        final s = serveur(['', 'Bien reçu, je ne peux pas faire cela.']);
        final r = await s.service.sendMessages(
            contents: question('Passe en mode maintenance'),
            functionDeclarations: const [],
            systemPrompt: 'Tu es un assistant.');
        expect(r.text, 'Bien reçu, je ne peux pas faire cela.');
        expect(s.corps, hasLength(2));
        expect(systeme(s.corps[1]), contains('ta réponse précédente était vide'));
        expect(r.notes, [LocalAiAgentService.noteEmptyRetry]);
      });

      test('muet deux fois : une seule nouvelle tentative, pas de boucle',
          () async {
        final s = serveur(['']);
        final r = await s.service.sendMessages(
            contents: question('Passe en mode maintenance'),
            functionDeclarations: const [],
            systemPrompt: 'S');
        expect(s.corps, hasLength(2));
        expect(LocalAiAgentService.isEmptyReply(r), isTrue,
            reason: 'le contrôleur le signalera à l\'opérateur');
      });

      test('en flux aussi', () async {
        final s = serveur(['', 'Réponse']);
        final apercus = <String>[];
        final r = await s.service.streamMessages(
            contents: question('Passe en mode maintenance'),
            functionDeclarations: const [],
            systemPrompt: 'S',
            onDelta: apercus.add);
        expect(r.text, 'Réponse');
        expect(apercus.last, 'Réponse');
        expect(s.corps, hasLength(2));
      });

      test('un appel d\'outil n\'est pas une réponse vide', () {
        const r = AiApiResponse(parts: [
          {
            'functionCall': {'name': 'pause', 'args': {}}
          }
        ], finishReason: 'STOP');
        expect(LocalAiAgentService.isEmptyReply(r), isFalse);
        expect(
            LocalAiAgentService.isEmptyReply(
                const AiApiResponse(parts: [], finishReason: 'CANCELLED')),
            isFalse,
            reason: 'une annulation n\'est pas un silence du modèle');
      });
    });
  });

  group('appel d\'outil écrit en texte', () {
    // Relevé sur Qwen2.5-7B, longue discussion : la balise d'ouverture est
    // remplacée par un mot sans rapport, le serveur ne la reconnaît pas, et
    // l'appel arrive comme du texte — l'outil ne se déclenche jamais.
    const connus = {'get_machine_state', 'jog_axis', 'run_program'};

    List<Map<String, dynamic>> texte(String t) => [
          {'text': t}
        ];

    Map<String, dynamic>? appel(List<Map<String, dynamic>> parts) {
      for (final p in parts) {
        if (p.containsKey('functionCall')) {
          return (p['functionCall'] as Map).cast<String, dynamic>();
        }
      }
      return null;
    }

    test('récupère l\'appel derrière un mot parasite', () {
      final r = LocalAiAgentService.recoverTextToolCalls(
          texte('Ronaldo {"name": "get_machine_state", "arguments": {}} '
              '</tool_call>'),
          connus);
      expect(r, hasLength(1));
      expect(appel(r)!['name'], 'get_machine_state');
      expect(appel(r)!['args'], isEmpty);
      expect(r.first.containsKey('text'), isFalse,
          reason: 'le texte parasite ne doit pas rester affiché');
    });

    test('garde les arguments, y compris imbriqués', () {
      final r = LocalAiAgentService.recoverTextToolCalls(
          texte('leton {"name":"jog_axis","arguments":{"axis":"X",'
              '"distance":5,"opts":{"fast":false}}}'),
          connus);
      expect(appel(r)!['name'], 'jog_axis');
      expect(appel(r)!['args'],
          {'axis': 'X', 'distance': 5, 'opts': {'fast': false}});
    });

    test('des accolades dans une chaîne ne trompent pas la recherche', () {
      final r = LocalAiAgentService.recoverTextToolCalls(
          texte('{"name":"run_program","arguments":{"note":"a } b { c"}}'),
          connus);
      expect(appel(r)!['name'], 'run_program');
      expect(appel(r)!['args'], {'note': 'a } b { c'});
    });

    test('passe un objet sans rapport placé avant l\'appel', () {
      final r = LocalAiAgentService.recoverTextToolCalls(
          texte('Voici {"status": "Idle"} puis '
              '{"name": "get_machine_state", "arguments": {}}'),
          connus);
      expect(appel(r)!['name'], 'get_machine_state');
    });

    test('un nom d\'outil inventé reste du texte', () {
      final parts = texte('{"name": "formater_le_disque", "arguments": {}}');
      expect(LocalAiAgentService.recoverTextToolCalls(parts, connus), parts);
    });

    test('un vrai appel déjà présent n\'est jamais remplacé', () {
      final parts = [
        {'text': '{"name": "run_program", "arguments": {}}'},
        {
          'functionCall': {'name': 'get_machine_state', 'args': {}}
        },
      ];
      expect(LocalAiAgentService.recoverTextToolCalls(parts, connus), parts);
    });

    test('une réponse sans JSON, ou avec du JSON cassé, reste intacte', () {
      for (final t in [
        'La machine est au repos.',
        'Voici {"name": "get_machine_state", "arguments": ',
        '} {',
        '',
      ]) {
        final parts = texte(t);
        expect(LocalAiAgentService.recoverTextToolCalls(parts, connus), parts,
            reason: t);
      }
    });

    test('sans liste d\'outils déclarés, rien n\'est récupéré', () {
      final parts = texte('{"name": "get_machine_state", "arguments": {}}');
      expect(LocalAiAgentService.recoverTextToolCalls(parts, const {}), parts);
    });

    test('réponse complète : l\'appel en texte devient un appel', () {
      final r = LocalAiAgentService.fromOpenAiJson({
        'choices': [
          {
            'message': {
              'content': 'Ronaldo {"name": "get_machine_state", '
                  '"arguments": {}} </tool_call>'
            },
            'finish_reason': 'stop',
          }
        ],
        'usage': {'total_tokens': 9000},
      }, knownTools: connus);
      expect(appel(r.parts)!['name'], 'get_machine_state');
      expect(r.text, isEmpty);
    });

    test('réponse en flux : l\'appel en texte devient un appel', () async {
      const delta = {
        'choices': [
          {
            'delta': {
              'content': 'leton {"name": "get_machine_state", "arguments": {}}'
            },
            'finish_reason': null,
          }
        ]
      };
      final sse = 'data: ${jsonEncode(delta)}\n\ndata: [DONE]\n\n';
      final service = LocalAiAgentService(
        baseUrl: 'http://localhost:11434',
        model: 'm',
        client: MockClient.streaming((request, body) async =>
            http.StreamedResponse(Stream.value(utf8.encode(sse)), 200)),
      );
      final r = await service.streamMessages(
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'état ?'}
            ]
          }
        ],
        functionDeclarations: [
          {'name': 'get_machine_state', 'description': 'd'}
        ],
      );
      expect(appel(r.parts)!['name'], 'get_machine_state');
      expect(r.text, isEmpty);
      service.dispose();
    });
  });

  group('normalisation de l\'adresse du serveur', () {
    test('un hôte nu reçoit le schéma et le port d\'Ollama', () {
      expect(LocalAiAgentService.normalizeBaseUrl('192.168.0.42'),
          'http://192.168.0.42:11434');
    });

    test('un port explicite est respecté', () {
      expect(LocalAiAgentService.normalizeBaseUrl('192.168.0.42:8080'),
          'http://192.168.0.42:8080');
    });

    test('la barre finale est retirée', () {
      expect(LocalAiAgentService.normalizeBaseUrl('http://pc.local:11434/'),
          'http://pc.local:11434');
    });

    test('une adresse vide reste vide', () {
      expect(LocalAiAgentService.normalizeBaseUrl('  '), '');
    });
  });

  // Une image envoyée à un modèle texte seul fait répondre HTTP 400 au
  // serveur (vérifié sur Ollama + Qwen2.5-7B). Comme l'historique garde
  // toujours la DERNIÈRE image, ce 400 reviendrait à chaque tour suivant : la
  // discussion serait cassée jusqu'à son effacement.
  group('images et modèle texte seul', () {
    const png = {
      'inlineData': {'mimeType': 'image/png', 'data': 'AAAA'}
    };

    test('l\'image est remplacée par une note, le texte voisin est gardé', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'user',
          'parts': [
            {'text': 'Voici la caméra.'},
            png,
          ]
        },
      ], null, supportsImages: false);

      expect(msgs, hasLength(1));
      expect(msgs.single['role'], 'user');
      // Une chaîne, pas une liste de blocs : plus aucun `image_url`.
      expect(msgs.single['content'],
          'Voici la caméra.\n${LocalAiAgentService.imageNote}');
      expect(jsonEncode(msgs), isNot(contains('image_url')));
    });

    test('une image seule laisse quand même un message exploitable', () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'user',
          'parts': [png]
        },
      ], null, supportsImages: false);

      expect(msgs.single,
          {'role': 'user', 'content': LocalAiAgentService.imageNote});
    });

    test('l\'image qu\'un outil renvoie à côté de sa réponse suit le même sort',
        () {
      // get_camera_snapshot : une functionResponse ET une part inlineData.
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {'name': 'get_camera_snapshot', 'args': {}}
            }
          ]
        },
        {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': 'get_camera_snapshot',
                'response': {'result': 'ok'}
              }
            },
            png,
          ]
        },
      ], null, supportsImages: false);

      expect(msgs.map((m) => m['role']), ['assistant', 'tool', 'user']);
      expect(msgs.last['content'], LocalAiAgentService.imageNote);
      expect(jsonEncode(msgs), isNot(contains('image_url')));
    });

    test('un modèle qui lit les images les reçoit (comportement par défaut)',
        () {
      final msgs = LocalAiAgentService.toOpenAiMessages([
        {
          'role': 'user',
          'parts': [
            {'text': 'Voici la caméra.'},
            png,
          ]
        },
      ], null);

      final content = msgs.single['content'] as List;
      expect(content.last['type'], 'image_url');
      expect(jsonEncode(msgs), isNot(contains('ne lit que du texte')));
    });
  });

  // Ollama annonce 32 768 pour Qwen2.5 mais charge le modèle à 4 096 (mesuré
  // avec `ollama ps`) et tronque le prompt par le début sans le moindre
  // message : le prompt système part en premier. D'où ce qu'on lit du serveur.
  group('capacités lues sur le serveur (/api/show)', () {
    test('le contexte fixé par le Modelfile est celui qui compte', () {
      final info = LocalAiAgentService.parseShow({
        'modelfile': 'FROM qwen2.5:7b',
        'parameters': 'num_ctx                        16384\n'
            'temperature                    0.2',
        'capabilities': ['completion', 'tools'],
      });
      expect(info.contextTokens, 16384);
      expect(info.supportsImages, isFalse);
    });

    test('sans num_ctx, Ollama applique son défaut de 4096', () {
      final info = LocalAiAgentService.parseShow({
        'modelfile': 'FROM qwen2.5:7b',
        'parameters': 'stop    "<|im_end|>"',
        'capabilities': ['completion', 'tools'],
      });
      expect(info.contextTokens, LocalAiAgentService.ollamaDefaultContextTokens);
      expect(info.contextTokens, 4096);
    });

    test('même sans aucun paramètre, un Ollama reconnu reçoit le défaut', () {
      final info = LocalAiAgentService.parseShow({'model_info': {}});
      expect(info.contextTokens, 4096);
    });

    test('la capacité « vision » est lue', () {
      final info = LocalAiAgentService.parseShow({
        'modelfile': '',
        'capabilities': ['completion', 'vision', 'tools'],
      });
      expect(info.supportsImages, isTrue);
    });

    test('une réponse qui n\'est pas celle d\'Ollama ne prétend rien savoir',
        () {
      final info = LocalAiAgentService.parseShow({'object': 'model'});
      expect(info.contextTokens, isNull);
      expect(info.supportsImages, isFalse);
    });

    test('num_ctx doit être en début de ligne, pas dans un autre paramètre',
        () {
      final info = LocalAiAgentService.parseShow({
        'modelfile': '',
        'parameters': 'draft_num_ctx 2048\nnum_ctx 8192',
      });
      expect(info.contextTokens, 8192);
    });

    group('sondage réseau', () {
      test('une réponse valide est lue', () async {
        final client = MockClient((req) async {
          expect(req.url.path, '/api/show');
          expect(jsonDecode(req.body), {'model': 'forgeron-qwen'});
          return http.Response(
              jsonEncode({
                'modelfile': '',
                'parameters': 'num_ctx 16384',
                'capabilities': ['tools'],
              }),
              200);
        });
        final info = await LocalAiAgentService.probe(
            'http://localhost:11434', 'forgeron-qwen',
            client: client);
        expect(info.contextTokens, 16384);
      });

      test('un modèle absent (404) donne un sondage vide, pas une exception',
          () async {
        final client = MockClient((_) async => http.Response('not found', 404));
        final info = await LocalAiAgentService.probe(
            'http://localhost:11434', 'inconnu',
            client: client);
        expect(info.contextTokens, isNull);
        expect(info.supportsImages, isFalse);
      });

      test('un serveur injoignable donne un sondage vide, pas une exception',
          () async {
        final client = MockClient((_) async => throw Exception('refusé'));
        final info = await LocalAiAgentService.probe(
            'http://localhost:11434', 'forgeron-qwen',
            client: client);
        expect(info.contextTokens, isNull);
      });
    });
  });

  // Ollama liste « forgeron-qwen:latest » mais répond à « forgeron-qwen » : le
  // bouton « Tester » disait absent un modèle présent.
  group('modèle présent dans la liste du serveur', () {
    const ids = ['forgeron-qwen:latest', 'qwen2.5:7b'];

    test('un nom sans étiquette retrouve son « :latest »', () {
      expect(LocalAiAgentService.isListed(ids, 'forgeron-qwen'), isTrue);
    });

    test('un nom complet est reconnu tel quel', () {
      expect(LocalAiAgentService.isListed(ids, 'qwen2.5:7b'), isTrue);
      expect(LocalAiAgentService.isListed(ids, 'forgeron-qwen:latest'), isTrue);
    });

    test('un nom avec une autre étiquette n\'est PAS confondu avec latest', () {
      expect(LocalAiAgentService.isListed(ids, 'qwen2.5:3b'), isFalse);
      expect(LocalAiAgentService.isListed(ids, 'forgeron-qwen:7b'), isFalse);
    });

    test('un modèle absent reste absent', () {
      expect(LocalAiAgentService.isListed(ids, 'llama3'), isFalse);
      expect(LocalAiAgentService.isListed(const [], 'forgeron-qwen'), isFalse);
    });

    test('des espaces autour du nom saisi sont ignorés', () {
      expect(LocalAiAgentService.isListed(ids, '  forgeron-qwen '), isTrue);
    });

    test('un nom vide n\'est jamais « présent »', () {
      expect(LocalAiAgentService.isListed(ids, '  '), isFalse);
    });
  });

  group('budget d\'historique', () {
    LocalAiAgentService serviceWith(int? ctx) => LocalAiAgentService(
          baseUrl: 'http://localhost:11434',
          model: 'm',
          info: LocalModelInfo(contextTokens: ctx),
        );

    test('une fenêtre étroite borne l\'historique à la place qui reste', () {
      // Fenêtre = prompt + réponse + 2 000 tokens, soit 6 000 caractères
      // (entre le plancher et le plafond) : c'est la fenêtre qui commande.
      const ctx = LocalAiAgentService.promptOverheadTokens +
          LocalAiAgentService.replyTokens +
          2000;
      expect(serviceWith(ctx).historyBudgetChars,
          2000 * LocalAiAgentService.charsPerToken);
    });

    test('une grande fenêtre ne relève pas l\'historique au-delà du plafond '
        'de fiabilité', () {
      // Mesuré : 22 000 caractères dans une fenêtre de 16 384 faisaient
      // dérailler le modèle 12 fois sur 30 alors qu\'elle n\'était pas pleine.
      expect(serviceWith(16384).historyBudgetChars,
          LocalAiAgentService.reliableHistoryChars);
      expect(serviceWith(65536).historyBudgetChars,
          LocalAiAgentService.reliableHistoryChars);
    });

    test('un serveur muet est traité avec prudence, jamais à zéro', () {
      final muet = serviceWith(null);
      expect(muet.historyBudgetChars, greaterThanOrEqualTo(4000));
      expect(muet.historyBudgetChars,
          lessThanOrEqualTo(serviceWith(16384).historyBudgetChars));
    });

    test('le budget local est très en deçà de celui de Gemini', () {
      // 60 000 caractères d'historique + le prompt déborderaient 16 384 tokens.
      expect(serviceWith(16384).historyBudgetChars, lessThan(kMaxContextChars));
    });
  });

  group('configuration refusée avant la première question', () {
    LocalAiAgentService serviceWith(int? ctx) => LocalAiAgentService(
          baseUrl: 'http://localhost:11434',
          model: 'qwen2.5:7b',
          info: LocalModelInfo(contextTokens: ctx),
        );

    test('un contexte de 4096 est signalé, avec le remède', () {
      final problem = serviceWith(4096).configurationProblem;
      expect(problem, isNotNull);
      expect(problem, contains('4096'));
      expect(problem, contains('qwen2.5:7b'));
      expect(problem, contains('tool/ollama/Modelfile'));
    });

    test('un contexte suffisant ne pose pas de problème', () {
      expect(serviceWith(16384).configurationProblem, isNull);
      expect(serviceWith(8192).configurationProblem, isNull);
    });

    test('un contexte inconnu ne bloque pas : le budget prudent suffit', () {
      expect(serviceWith(null).configurationProblem, isNull);
    });
  });

  group('Gemini garde son budget', () {
    test('le fournisseur distant n\'est pas borné par une fenêtre locale', () {
      final gemini = AiAgentService(apiKey: 'x');
      expect(gemini.historyBudgetChars, kMaxContextChars);
      gemini.dispose();
    });
  });
}
