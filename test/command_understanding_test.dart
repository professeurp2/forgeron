import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_settings_provider.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/command_understanding.dart';
import 'package:forgeron/core/utils/command_lexicon.dart';

Map<String, dynamic> _json() => (jsonDecode(
        File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8))
    as Map).cast<String, dynamic>();

CommandUnderstanding _u(CommandLexicon lex,
        {AiAutonomyLevel level = AiAutonomyLevel.requireConfirmation}) =>
    CommandUnderstanding(lex,
        categoryOf: (t) => AiToolCatalog.byName(t)?.category,
        levelFor: (_) => level);

CommandLexicon _reviewed(Set<String> langs) {
  final j = _json();
  for (final l in langs) {
    final b = (j['languages'] as Map)[l] as Map;
    b['status'] = 'relu';
    b['reviewed_by'] = 'Awa Traoré';
    b['reviewed_on'] = '2026-10-23';
  }
  return CommandLexicon.fromJson(j);
}

void main() {
  final draft = CommandLexicon.fromJson(_json());

  group('arrêt d\'urgence et lecture', () {
    test('arrêt strict : immédiat, même dans une langue en brouillon', () {
      for (final said in ['Stop', 'Mansin jɔ sisan, joona!', 'Au secours']) {
        final d = _u(draft).decide(said);
        expect(d, isA<RunNow>(), reason: said);
        expect((d as RunNow).reason, RunReason.emergencyStop);
      }
    });
    test('arrêt approximatif : suggestion à confirmer', () {
      final d = _u(draft).decide('Arete tout');
      expect(d, isA<AskConfirmation>());
      expect(
          (d as AskConfirmation).reasons, contains(ConfirmReason.suggestion));
    });
    test('lecture d\'état : immédiate', () {
      final d = _u(draft).decide('État de la machine');
      expect((d as RunNow).reason, RunReason.readOnly);
    });
  });

  group('ordres qui agissent', () {
    test('défaut : confirmation (brouillon + réglage)', () {
      final d = _u(draft).decide('Allume la broche') as AskConfirmation;
      expect(d.reasons,
          {ConfirmReason.draftLanguage, ConfirmReason.autonomy});
    });
    test('autonomie accordée mais langue en brouillon : confirme quand même',
        () {
      final d = _u(draft, level: AiAutonomyLevel.autoExecute)
          .decide('Allume la broche') as AskConfirmation;
      expect(d.reasons, {ConfirmReason.draftLanguage});
    });
    test('langue relue + autonomie accordée : exécuté', () {
      final d = _u(_reviewed({'fr'}), level: AiAutonomyLevel.autoExecute)
          .decide('Allume la broche');
      expect((d as RunNow).reason, RunReason.trustedAutonomy);
    });
    test('langue relue mais réglage « confirmer » : confirme', () {
      final d =
          _u(_reviewed({'fr'})).decide('Allume la broche') as AskConfirmation;
      expect(d.reasons, {ConfirmReason.autonomy});
    });
    test('mélange avec une langue non relue : pas de confiance', () {
      final d = _u(_reviewed({'fr'}), level: AiAutonomyLevel.autoExecute)
          .decide('Broche daminɛ');
      expect(d, isA<AskConfirmation>());
    });
    test('mot partagé : validé dès qu\'une de ses langues est relue', () {
      expect(_reviewed({'en'}).interpret('Spindle off').match!.trusted, isTrue);
      expect(draft.interpret('Spindle off').match!.trusted, isFalse);
    });
  });

  group('refus', () {
    test('question ou négation : lecture seule pour le modèle', () {
      for (final said in [
        'Ne démarre pas la broche',
        'Explique-moi le homing',
        'Broche kana daminɛ'
      ]) {
        expect(_u(draft).decide(said), isA<RestrictToReading>(), reason: said);
      }
    });
    test('autre refus : le modèle reprend', () {
      expect(_u(draft).decide('Recule X de 5 mm à 300'), isA<DeferToModel>());
    });
    test('outils de lecture : préfixes', () {
      expect(isReadOnlyToolName('get_machine_state'), isTrue);
      expect(isReadOnlyToolName('jog_axis'), isFalse);
      expect(isReadOnlyToolName('emergency_stop'), isFalse);
    });
  });

  group('ce que l\'opérateur lit', () {
    test('libellé d\'action', () {
      final m = draft.interpret('Déplace X de -5 mm vitesse 300').match!;
      expect(lexiconActionLabel(m), contains('-5'));
      expect(lexiconActionLabel(m), contains('X'));
    });
    test('état : hors ligne = aucune position', () {
      expect(describeMachineState({'status': 'offline'}),
          isNot(contains('Position')));
      expect(
          describeMachineState({
            'status': 'idle',
            'wPos': [1.5, 0, 0, 0, 0],
            'mPos': [1.5, 0, 0, 0, 0]
          }),
          contains('X 1.5'));
    });
    test('réponse : phrase d\'une langue relue seulement si elle est relue',
        () {
      final j = _json();
      final bm = (j['languages'] as Map)['bm'] as Map;
      bm['replies'] = {'spindle_on': 'Broche mɛnɛna.'};
      final lex1 = CommandLexicon.fromJson(j);
      expect(
          lexiconReply(
              match: lex1.interpret('Broche daminɛ').match!,
              toolResult: 'OK: M3 S1000',
              lexicon: lex1),
          'Broche allumée.');
      bm['status'] = 'relu';
      bm['reviewed_by'] = 'Awa Traoré';
      bm['reviewed_on'] = '2026-10-23';
      final lex2 = CommandLexicon.fromJson(j);
      // « broche » est aussi français (brouillon) : on cherche la phrase dans
      // les langues de l'énoncé, bm en fait partie.
      expect(
          lexiconReply(
              match: lex2.interpret('Broche daminɛ').match!,
              toolResult: 'OK',
              lexicon: lex2),
          contains('mɛnɛna'));
    });
    test('échec d\'outil : dit non exécuté', () {
      final m = draft.interpret('Déplace X de 5 mm vitesse 300').match!;
      expect(
          lexiconReply(
              match: m,
              toolResult: 'REFUSÉ (sécurité) : hors course',
              lexicon: draft),
          contains('hors course'));
    });
    test('aide sans modèle : une phrase par raison', () {
      expect(lexiconHelp('negation'), isNot(equals(lexiconHelp('question'))));
      expect(lexiconHelp(null), contains('arrête'));
    });
  });
}
