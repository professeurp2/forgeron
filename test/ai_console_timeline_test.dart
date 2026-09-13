import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/core/utils/chat_markdown.dart';
import 'package:forgeron/presentation/screens/desktop/ai_console_timeline.dart';

/// Rassemble le texte de tous les fragments, pour vérifier ce qui s'affiche
/// réellement sans dépendre de la façon dont c'est découpé.
String _flatten(List<InlineSpan> spans) =>
    spans.map((s) => (s as TextSpan).text ?? '').join();

void main() {
  group('étape d\'outil', () {
    test('une étape démarrée n\'a pas de résultat', () {
      final step = AiChatMessage.toolStarted('home', const {'axis': 'Z'});

      expect(step.isTool, isTrue);
      expect(step.isRunningTool, isTrue);
      expect(step.toolResult, isNull);
      expect(step.toolFailed, isFalse);
      expect(step.toolArgs, {'axis': 'Z'});
    });

    test('une étape aboutie garde son horodatage de départ', () {
      final step = AiChatMessage.toolStarted('home', const {});
      final done = step.toolFinished('OK: origine prise');

      expect(done.isRunningTool, isFalse);
      expect(done.toolResult, 'OK: origine prise');
      expect(done.text, 'home → OK: origine prise');
      expect(done.toolDuration, isNotNull);
      // L'étape ne doit pas sauter en bas du fil en se terminant.
      expect(done.timestamp, step.timestamp);
    });

    test('un résultat préfixé « Erreur » compte comme un échec', () {
      final done =
          AiChatMessage.toolStarted('probe', const {}).toolFinished('Erreur: pas de contact');
      expect(done.toolFailed, isTrue);
    });
  });

  group('persistance d\'une étape', () {
    test('aller-retour JSON : nom, arguments et durée survivent', () {
      final done = AiChatMessage.toolStarted('jog_axis', const {'axis': 'X', 'mm': 10})
          .toolFinished('OK');
      final relu = AiChatMessage.fromJson(done.toJson());

      expect(relu.toolName, 'jog_axis');
      expect(relu.toolResult, 'OK');
      expect(relu.toolArgs, {'axis': 'X', 'mm': 10});
      expect(relu.toolDuration, isNotNull);
      expect(relu.isRunningTool, isFalse);
    });

    test('ancien format « nom → résultat » redécoupé', () {
      final relu = AiChatMessage.fromJson({
        'role': 'tool',
        'text': 'get_machine_state → IDLE',
        'ts': 1700000000000,
      });

      expect(relu.toolName, 'get_machine_state');
      expect(relu.toolResult, 'IDLE');
      expect(relu.isRunningTool, isFalse);
    });

    test('une étape relue ne peut pas rester en cours', () {
      // Cas d'une application fermée pendant l'appel : sans ce garde-fou,
      // l'étape tournerait pour toujours au rechargement.
      final relu = AiChatMessage.fromJson({
        'role': 'tool',
        'text': 'run_step_pipeline → …',
        'ts': 1700000000000,
      });

      expect(relu.isRunningTool, isFalse);
      expect(relu.toolFailed, isTrue);
    });

    test('des arguments énormes ne sont pas recopiés dans le stockage', () {
      final gros = {'content': 'G1 X1\n' * 2000};
      final done = AiChatMessage.toolStarted('write_workspace_file', gros)
          .toolFinished('OK');

      expect(done.toJson().containsKey('args'), isFalse);
      // Le reste de l'étape reste lisible.
      expect(AiChatMessage.fromJson(done.toJson()).toolName, 'write_workspace_file');
    });
  });

  group('regroupement du fil', () {
    AiChatMessage msg(String role) =>
        AiChatMessage(role: role, text: role, timestamp: DateTime(2026));

    test('les étapes consécutives forment une seule activité', () {
      final items = groupConsoleItems([
        msg('user'),
        AiChatMessage.toolStarted('a', const {}).toolFinished('OK'),
        AiChatMessage.toolStarted('b', const {}).toolFinished('OK'),
        msg('assistant'),
        AiChatMessage.toolStarted('c', const {}).toolFinished('OK'),
      ]);

      expect(items.length, 4);
      expect(items[0], isA<AiChatMessage>());
      expect((items[1] as ToolRun).steps.length, 2);
      expect(items[2], isA<AiChatMessage>());
      expect((items[3] as ToolRun).steps.length, 1);
    });

    test('une activité en cours se sait en cours', () {
      final run = ToolRun([
        AiChatMessage.toolStarted('a', const {}).toolFinished('OK'),
        AiChatMessage.toolStarted('b', const {}),
      ]);

      expect(run.isRunning, isTrue);
      expect(run.done, 1);
      expect(run.failures, 0);
    });

    test('le résumé nomme l\'étape en cours, pas la première', () {
      final run = ToolRun([
        AiChatMessage.toolStarted('home', const {}).toolFinished('OK'),
        AiChatMessage.toolStarted('probe', const {}),
      ]);

      expect(run.headline, contains('Palpage'));
      expect(run.headline, contains('+1 autre'));
    });
  });

  group('mise en forme', () {
    test('durées lisibles', () {
      expect(formatDuration(const Duration(milliseconds: 240)), '240 ms');
      expect(formatDuration(const Duration(seconds: 12)), '12 s');
      expect(formatDuration(const Duration(seconds: 64)), '1 min 04 s');
    });

    test('jetons abrégés au-delà du millier', () {
      expect(formatTokens(840), '840');
      expect(formatTokens(240800), '240.8k');
    });

    test('un nom d\'outil inconnu reste affichable', () {
      expect(friendlyToolLabel('run_step_pipeline'),
          'Génération du G-code depuis le fichier STEP');
      expect(friendlyToolLabel('outil_inedit'), 'Outil inedit');
    });

    test('le rapport du pipeline devient une phrase', () {
      const rapport =
          '{"pipeline":"revolution","operations":[1,2],"lignes_gcode":420}';
      final resume = resultSummary('run_step_pipeline', rapport);

      expect(resume, contains('révolution'));
      expect(resume, contains('2 opération(s)'));
      expect(resume, contains('420 lignes'));
    });

    test('un résultat qui n\'est pas du JSON passe tel quel', () {
      expect(resultSummary('home', 'OK: origine prise'), 'OK: origine prise');
    });
  });

  group('prose de l\'assistant', () {
    test('le gras est reconnu', () {
      final spans = chatProseSpans('avant **gras** après');

      expect(_flatten(spans), 'avant gras après');
      final bold = spans.firstWhere((s) => (s as TextSpan).text == 'gras') as TextSpan;
      expect(bold.style?.fontWeight, FontWeight.bold);
    });

    test('le code inline prend le style donné', () {
      const style = TextStyle(fontFamily: 'JetBrainsMono');
      final spans = chatProseSpans('lance `G28` puis', codeStyle: style);

      expect(_flatten(spans), 'lance G28 puis');
      final code = spans.firstWhere((s) => (s as TextSpan).text == 'G28') as TextSpan;
      expect(code.style?.fontFamily, 'JetBrainsMono');
    });

    test('les puces deviennent des puces', () {
      expect(_flatten(chatProseSpans('- un\n- deux')), contains('• un'));
      expect(_flatten(chatProseSpans('* un')), contains('• un'));
    });

    test('les dièses des titres disparaissent', () {
      final spans = chatProseSpans('## Bilan\ntout va bien');

      expect(_flatten(spans), 'Bilan\ntout va bien');
      final titre = spans.firstWhere((s) => (s as TextSpan).text == 'Bilan') as TextSpan;
      expect(titre.style?.fontWeight, FontWeight.bold);
    });

    test('le LaTeX est nettoyé plutôt qu\'affiché brut', () {
      expect(_flatten(chatProseSpans(r'$\text{Ø}20$')), 'Ø20');
    });
  });
}
