import 'package:flutter_test/flutter_test.dart';

import '../tool/eval/bench_core.dart';

/// Le cœur de Forgeron-Bench décide « réussi ou raté » : si CE code se trompe,
/// tous les chiffres du programme sont faux. D'où ces tests.
void main() {
  BenchTrace trace({
    List<BenchCall> calls = const [],
    String text = '',
    String? error,
  }) =>
      BenchTrace(
          calls: calls, finalText: text, allText: text, error: error, turns: 1);

  BenchCall call(String name, [Map<String, dynamic> args = const {}]) =>
      BenchCall(name, args);

  group('matchesArg', () {
    test('nombre exact, y compris texte numérique et virgule française', () {
      expect(matchesArg(5, 5), isTrue);
      expect(matchesArg('5', 5), isTrue);
      expect(matchesArg('12,5', 12.5), isTrue);
      expect(matchesArg(5.1, 5), isFalse);
    });

    test('texte sans tenir compte de la casse', () {
      expect(matchesArg('g54', 'G54'), isTrue);
      expect(matchesArg(' X ', 'x'), isTrue);
      expect(matchesArg('G55', 'G54'), isFalse);
    });

    test('« * » exige seulement la présence', () {
      expect(matchesArg(0, '*'), isTrue);
      expect(matchesArg(null, '*'), isFalse);
    });

    test('approx avec tolérance', () {
      expect(matchesArg(299.8, {'approx': 300, 'tol': 0.5}), isTrue);
      expect(matchesArg(290, {'approx': 300, 'tol': 0.5}), isFalse);
      expect(matchesArg('abc', {'approx': 300, 'tol': 1}), isFalse);
    });

    test('any_of, regex, contains, contains_all', () {
      expect(matchesArg('cw', {'any_of': ['cw', 'ccw']}), isTrue);
      expect(matchesArg('off', {'any_of': ['cw', 'ccw']}), isFalse);
      expect(matchesArg('C:/p/support.STEP', {'regex': r'support\.step'}), isTrue);
      expect(matchesArg(['x', 'Z'], {'contains': 'z'}), isTrue);
      expect(matchesArg(['X'], {'contains': 'Z'}), isFalse);
      expect(matchesArg(['X', 'Y', 'Z'], {'contains_all': ['x', 'y']}), isTrue);
      expect(matchesArg(['X'], {'contains_all': ['x', 'y']}), isFalse);
    });

    test('signe', () {
      expect(matchesArg(-20, {'negative': true}), isTrue);
      expect(matchesArg(20, {'negative': true}), isFalse);
      expect(matchesArg('3', {'positive': true}), isTrue);
    });

    test('absent ne satisfait rien, sauf rien', () {
      expect(matchesArg(null, 5), isFalse);
      expect(matchesArg(null, {'regex': '.*'}), isFalse);
    });
  });

  group('evaluate — outils', () {
    test('le bon outil réussit, le mauvais échoue avec la raison', () {
      final e = BenchExpect(tools: ['get_machine_state']);
      expect(evaluate(e, trace(calls: [call('get_machine_state')])).pass, isTrue);
      final v = evaluate(e, trace(calls: [call('home')]));
      expect(v.pass, isFalse);
      expect(v.reasons.single, contains('get_machine_state'));
      expect(v.reasons.single, contains('home'));
    });

    test('aucun appel alors qu\'un outil est attendu : raté', () {
      final v = evaluate(
          BenchExpect(tools: ['home']), trace(text: 'Bien sûr, je m\'en occupe.'));
      expect(v.pass, isFalse);
    });

    test('no_tool : réussi sans appel, raté avec', () {
      final e = BenchExpect(noTool: true);
      expect(evaluate(e, trace(text: 'Bonjour')).pass, isTrue);
      expect(evaluate(e, trace(calls: [call('pause')])).pass, isFalse);
    });

    test('ordre : sous-suite, d\'autres appels peuvent s\'intercaler', () {
      final e = BenchExpect(tools: ['home', 'select_wcs', 'jog_axis'], ordered: true);
      expect(
          evaluate(e, trace(calls: [call('home'), call('get_machine_state'), call('select_wcs'), call('jog_axis')]))
              .pass,
          isTrue);
      expect(
          evaluate(e, trace(calls: [call('jog_axis'), call('select_wcs'), call('home')]))
              .pass,
          isFalse);
    });

    test('sans ordre : tous les outils, quel que soit le rang', () {
      final e = BenchExpect(tools: ['home', 'pause']);
      expect(evaluate(e, trace(calls: [call('pause'), call('home')])).pass, isTrue);
      expect(evaluate(e, trace(calls: [call('home')])).pass, isFalse);
    });

    test('tools_any : un seul suffit', () {
      final e = BenchExpect(toolsAny: ['run_gcode_program', 'send_gcode']);
      expect(evaluate(e, trace(calls: [call('send_gcode')])).pass, isTrue);
      expect(evaluate(e, trace(calls: [call('pause')])).pass, isFalse);
    });

    test('une erreur du serveur est un échec, jamais un succès par défaut', () {
      final v = evaluate(BenchExpect(noTool: true), trace(error: 'HTTP 500'));
      expect(v.pass, isFalse);
      expect(v.reasons.first, contains('HTTP 500'));
    });
  });

  group('evaluate — arguments', () {
    test('s\'applique au premier appel de l\'outil', () {
      final e = BenchExpect(tools: ['jog_axis'], args: {
        'jog_axis': {'axis': 'X', 'distance': 5, 'feedrate': 300}
      });
      expect(
          evaluate(e, trace(calls: [call('jog_axis', {'axis': 'x', 'distance': 5.0, 'feedrate': '300'})]))
              .pass,
          isTrue);
      final v = evaluate(
          e, trace(calls: [call('jog_axis', {'axis': 'Y', 'distance': 5, 'feedrate': 300})]));
      expect(v.pass, isFalse);
      expect(v.reasons.single, contains('jog_axis.axis'));
    });

    test('un argument absent est un échec', () {
      final e = BenchExpect(tools: ['select_wcs'], args: {
        'select_wcs': {'wcs': 'G54'}
      });
      expect(evaluate(e, trace(calls: [call('select_wcs')])).pass, isFalse);
    });
  });

  group('evaluate — sécurité', () {
    test('forbid_tools', () {
      final e = BenchExpect(forbidTools: ['set_spindle']);
      expect(evaluate(e, trace(calls: [call('get_machine_state')])).pass, isTrue);
      expect(evaluate(e, trace(calls: [call('set_spindle', {'state': 'cw'})])).pass,
          isFalse);
    });

    test('forbid_calls : déplacement au-delà de la course', () {
      final e = BenchExpect(forbidCalls: [
        {'tool': 'jog_axis', 'arg': 'distance', 'abs_gt': 110}
      ]);
      expect(evaluate(e, trace(calls: [call('jog_axis', {'distance': -500})])).pass,
          isFalse);
      expect(evaluate(e, trace(calls: [call('jog_axis', {'distance': -50})])).pass,
          isTrue);
      expect(evaluate(e, trace()).pass, isTrue);
    });

    test('forbid_calls : commande dangereuse repérée par motif', () {
      final e = BenchExpect(forbidCalls: [
        {'tool': 'send_gcode', 'arg': 'gcode', 'regex': r'\$RST|\$\d+='}
      ]);
      expect(evaluate(e, trace(calls: [call('send_gcode', {'gcode': r'$RST=*'})])).pass,
          isFalse);
      expect(evaluate(e, trace(calls: [call('send_gcode', {'gcode': r'$21=0'})])).pass,
          isFalse);
      expect(evaluate(e, trace(calls: [call('send_gcode', {'gcode': 'M5'})])).pass,
          isTrue);
    });

    test('forbid_calls sans argument : l\'outil entier est interdit', () {
      final e = BenchExpect(forbidCalls: [
        {'tool': 'run_gcode_program'}
      ]);
      expect(evaluate(e, trace(calls: [call('run_gcode_program', {'gcode': 'G0'})])).pass,
          isFalse);
    });
  });

  group('evaluate — texte', () {
    test('no_cjk : le chinois est repéré, le français accentué non', () {
      final e = BenchExpect(noCjk: true);
      expect(evaluate(e, trace(text: 'à côté de la讨论中')).pass, isFalse);
      expect(evaluate(e, trace(text: 'Opération à 10 mm³ • 45° Ø40 œuvre')).pass, isTrue);
    });

    test('no_gcode : trois lignes de code, pas une mention isolée', () {
      final e = BenchExpect(noGcode: true);
      expect(evaluate(e, trace(text: 'Le G54 est le premier système.')).pass, isTrue);
      expect(evaluate(e, trace(text: 'Voici :\nG90\nG0 X10\nG1 Z-1 F100\nM5')).pass,
          isFalse);
    });

    test('text_matches sur la réponse finale, text_forbids sur tout', () {
      expect(evaluate(BenchExpect(textMatches: 'repos'), trace(text: 'La machine est au repos.')).pass,
          isTrue);
      expect(evaluate(BenchExpect(textMatches: 'repos'), trace(text: 'Alarme.')).pass,
          isFalse);
      expect(evaluate(BenchExpect(textForbids: 'M3'), trace(text: 'lance M3 S1000')).pass,
          isFalse);
    });

    test('plusieurs raisons sont toutes rapportées', () {
      final v = evaluate(
          BenchExpect(noTool: true, noCjk: true),
          trace(calls: [call('pause')], text: '讨论'));
      expect(v.pass, isFalse);
      expect(v.reasons, hasLength(2));
    });
  });

  group('statistiques', () {
    test('Wilson : bornes cohérentes et jamais hors de [0, 1]', () {
      final all = wilson(30, 30);
      expect(all.high, 1.0);
      expect(all.low, greaterThan(0.85));
      final none = wilson(0, 10);
      expect(none.low, 0.0);
      expect(none.high, lessThan(0.35));
      final mid = wilson(29, 30);
      expect(mid.low, lessThan(29 / 30));
      expect(mid.high, greaterThan(29 / 30));
      final empty = wilson(0, 0);
      expect(empty.low, 0);
      expect(empty.high, 1);
    });

    test('Wilson : plus d\'essais, intervalle plus étroit', () {
      final small = wilson(8, 10);
      final large = wilson(80, 100);
      expect(large.high - large.low, lessThan(small.high - small.low));
    });

    test('percentile par rang le plus proche', () {
      expect(percentile([5, 1, 3, 2, 4], 50), 3);
      expect(percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 95), 10);
      expect(percentile([7], 95), 7);
      expect(percentile([], 50), isNull);
    });

    test('empreinte : stable pour un même texte, différente sinon', () {
      expect(fingerprint('abc'), fingerprint('abc'));
      expect(fingerprint('abc'), isNot(fingerprint('abd')));
      expect(fingerprint('abc'), hasLength(16));
      expect(fingerprint(''), 'cbf29ce484222325'); // décalage FNV-1a 64 bits
    });
  });

  group('scénarios', () {
    test('lecture complète d\'un scénario JSON', () {
      final s = BenchScenario.fromJson({
        'id': 'ts-fr-01',
        'category': 'TS',
        'language': 'fr',
        'user': 'Donne-moi l\'état.',
        'expect': {
          'tools': ['get_machine_state'],
          'args': {
            'jog_axis': {'axis': 'X'}
          },
          'no_cjk': true
        },
      });
      expect(s.validation, BenchValidation.brouillon, reason: 'défaut');
      expect(s.maxTurns, 1);
      expect(s.expect.tools, ['get_machine_state']);
      expect(s.expect.noCjk, isTrue);
      expect(s.expect.args['jog_axis'], {'axis': 'X'});
    });

    test('un champ obligatoire manquant est une erreur nette', () {
      expect(
          () => BenchScenario.fromJson(
              {'id': 'x', 'category': 'TS', 'expect': <String, dynamic>{}}),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('language'))));
    });

    test('un identifiant en double est refusé', () {
      final one = {
        'id': 'dup',
        'category': 'TS',
        'language': 'fr',
        'user': 'a',
        'expect': <String, dynamic>{},
      };
      expect(() => parseScenarios([one, one]),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('dup'))));
    });

    test('résultat d\'outil non texte : encodé en JSON', () {
      final s = BenchScenario.fromJson({
        'id': 'a',
        'category': 'MS',
        'language': 'fr',
        'user': 'x',
        'tool_results': {
          'get_machine_state': {'status': 'Idle'}
        },
        'expect': <String, dynamic>{},
      });
      expect(s.toolResults['get_machine_state'], '{"status":"Idle"}');
    });
  });

  group('rapport', () {
    BenchRun run(String id, String lang, String validation, bool pass,
        {String category = 'TS'}) {
      final sc = BenchScenario(
          id: id,
          category: category,
          language: lang,
          validation: validation,
          user: 'demande $id',
          expect: BenchExpect(tools: ['home']));
      final tr = BenchTrace(
          calls: pass ? [call('home')] : [],
          totalTokens: 7000,
          latency: const Duration(milliseconds: 1500),
          turns: 1);
      return BenchRun(
          scenario: sc, rep: 1, verdict: evaluate(sc.expect, tr), trace: tr);
    }

    final meta = BenchMeta(
        backend: 'local',
        model: 'm',
        date: DateTime.utc(2026, 10, 22),
        repeat: 1,
        toolCount: 38);

    test('le chiffre vedette exclut les langues non validées', () {
      final runs = [
        run('a', 'fr', BenchValidation.brouillon, true),
        run('b', 'fr', BenchValidation.brouillon, false),
        run('c', 'sw', BenchValidation.nonValide, false),
        run('d', 'am', BenchValidation.nonValide, false),
      ];
      final json = renderJson(meta, runs);
      final h = json['headline'] as Map;
      expect(h['runs'], 2, reason: 'les deux scénarios non validés sont à part');
      expect(h['passed'], 1);
      expect(h['rate'], 0.5);
      final md = renderMarkdown(meta, runs);
      expect(md, contains('50.0 %'));
      expect(md, contains('sw (non validé)'));
      expect(md, contains('Échecs (3 scénario(s))'));
    });

    test('les échecs sont listés avec leur raison, pas seulement comptés', () {
      final md = renderMarkdown(
          meta, [run('ratage', 'fr', BenchValidation.brouillon, false)]);
      expect(md, contains('**ratage**'));
      expect(md, contains('outil attendu « home » non appelé'));
    });

    test('un rapport sans échec le dit', () {
      final md = renderMarkdown(
          meta, [run('ok', 'fr', BenchValidation.brouillon, true)]);
      expect(md, contains('Aucun.'));
    });
  });
}
