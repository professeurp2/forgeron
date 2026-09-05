import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';

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
}
