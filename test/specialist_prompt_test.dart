import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/services/tool_router.dart';

/// Phrases du tronc commun qui ne doivent JAMAIS disparaître d'un prompt de
/// spécialiste : ce sont des règles de sécurité.
const _safety = [
  'Tu n\'écris JAMAIS toi-même un programme G-code',
  'laisse l\'utilisateur confirmer les actions gatées',
  'est PÉRIMÉ dès que la machine bouge',
  '=== SPÉCIFICITÉS DE CETTE MACHINE',
  '=== QUESTIONS TECHNIQUES ===',
];

void main() {
  final full = AiAgentController.baseSystemPrompt;

  test('tous les groupes réunis redonnent le prompt complet', () {
    expect(
        AiAgentController.specialistSystemPrompt(ToolRouter.groups.keys.toSet()),
        full);
  });

  test('question d\'état : ni scan, ni FAO, ni fichiers, mais toute la sécurité', () {
    final p = AiAgentController.specialistSystemPrompt({'etat'});
    for (final s in _safety) {
      expect(p, contains(s), reason: s);
    }
    expect(p, isNot(contains('SCAN 3D')));
    expect(p, isNot(contains('preview_step_file')));
    expect(p, isNot(contains('COWORK')));
    expect(p.length, lessThan(full.length * 0.8),
        reason: 'le spécialiste doit alléger le prompt');
  });

  test('chaque spécialiste reçoit sa section', () {
    expect(AiAgentController.specialistSystemPrompt({'scan'}), contains('SCAN 3D'));
    expect(AiAgentController.specialistSystemPrompt({'cao'}),
        contains('preview_step_file'));
    expect(AiAgentController.specialistSystemPrompt({'programme'}),
        contains('VÉRIFIE qu\'aucun mouvement ne dépasse'));
    expect(AiAgentController.specialistSystemPrompt({'fichiers'}),
        contains('COWORK'));
  });

  test('aucun groupe de spécialiste n\'enlève une règle de sécurité', () {
    for (final g in ToolRouter.groups.keys) {
      final p = AiAgentController.specialistSystemPrompt({g});
      for (final s in _safety) {
        expect(p, contains(s), reason: '$g : $s');
      }
    }
  });
}
