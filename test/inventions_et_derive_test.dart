import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/language_detector.dart';
import 'package:forgeron/domain/models/machine_state.dart';

/// Trois inventions trouvées par le banc de conversation (5 nov. 2026), et
/// leurs garde-fous. Les réponses citées sont celles du modèle, recopiées du
/// rapport du banc.
void main() {
  group('hors ligne : aucune valeur, jamais des zéros', () {
    test("l'outil d'état ne livre ni position ni avance hors ligne", () {
      final m = machineStateMap(
          const MachineState(status: MachineStatus.offline));
      expect(m['status'], 'offline');
      for (final k in ['wPos', 'mPos', 'feedrate', 'spindleSpeed',
          'activeWCS', 'activeToolNum', 'alarmCode']) {
        expect(m.containsKey(k), isFalse, reason: k);
      }
      expect('${m['note']}', contains('ne présente jamais 0'));
    });

    test('en ligne, les valeurs lues sont toutes là', () {
      final m = machineStateMap(const MachineState(status: MachineStatus.idle));
      expect(m.keys, containsAll(['wPos', 'mPos', 'activeWCS', 'feedrate']));
    });
  });

  group('langue cible lue dans la consigne de fin', () {
    String? cible(String id, [String? detecte]) =>
        LocalAiAgentService.targetLanguageFromPrompt('…\n\n'
            '${appLanguageById(id).trailingPromptAnchor(detectedLanguageCode: detecte)}');

    test('chaque langue de l\'app est retrouvée', () {
      for (final l in kAppLanguages.where((l) => !l.isAuto)) {
        expect(cible(l.id), l.id, reason: l.id);
      }
      expect(cible('auto', 'ha'), 'ha');
      expect(LocalAiAgentService.targetLanguageFromPrompt('sans consigne'),
          isNull);
    });
  });

  group('dérive hors de la langue cible', () {
    bool derive(String texte, String cible) =>
        LanguageDetector.driftsFromLanguage(texte, cible);

    test("arabe qui repasse au français à mi-réponse (cas réel)", () {
      const r = 'الآلة موجودة حاليا خارج الخدمة (OFFLINE). لذا لا يمكننا '
          'الحصول على معلومات حية حول وضع المpiece ou la machine.\n\n'
          'Position de la pièce\nPosition de la machine:\n- X: 0.0 mm\n'
          'Système de Coordonnées Actif (WCS): G54\n'
          "Aucune Outil Activé (Numéro d'outil actif : 0)";
      expect(derive(r, 'ar'), isTrue);
    });

    test('arabe propre, avec mots d\'atelier et libellé cité', () {
      const r = 'الآلة غير متصلة حاليًا. لا توجد بيانات عن المواقع. '
          'أنصحك بإجراء الـ homing قبل أي تشغيل، ثم تحقق من برنامج G-code. '
          'يمكنك تغيير اللغة من « Paramètres > Langue ».';
      expect(derive(r, 'ar'), isFalse);
    });

    test('bambara qui finit par « reformule en français » (cas réel)', () {
      const r = 'Djin ci, wu ne maa maa ci cogo ci ni. Ni bennu ne yi sili '
          'sii ko yàppa ci wolof moo maa cekkole ba. Ci mëna, je ne comprends '
          'pas complètement ta question. Pourrais-tu reformuler ta demande en '
          'français ou en bambara afin que je comprenne mieux ?';
      expect(derive(r, 'bm'), isTrue);
    });

    test('wolof, haoussa, swahili du banc : pas de fausse alerte', () {
      expect(
          derive(
              'Salaam aleikum. Ngu kaw lu am mën a def ngir man. Am naa '
              'bëgër kopp ndaw ni jàng. Moom bëgërram dafa am fii jàng?',
              'wo'),
          isFalse);
      expect(
          derive(
              'Sannu, mene za ka iya yi mini. Minin zuwa ni "jog_axis", '
              '"home", "set_spindle" kuma kwallon iya zuwa wani fakirin '
              'kawai za iya bayar.',
              'ha'),
          isFalse);
      expect(
          derive(
              'Habari! Ninaweza kukusaidia kuangalia hali ya mashine, kupakia '
              'programu ya G-code na kuwasha spindle. Unataka nini sasa?',
              'sw'),
          isFalse);
    });

    test("swahili avec mots d'atelier français : pas de dérive", () {
      expect(
          derive(
              'Spindle imewashwa. Broche iko tayari, avance ni 300 mm/min. '
              'Homing imekamilika na origine G54 imewekwa.',
              'sw'),
          isFalse);
    });

    test('anglais qui passe au français', () {
      expect(
          derive(
              "The interface is now in French. L'interface est maintenant en "
              'français pour vous. Vous pouvez revenir à la langue anglaise '
              'dans les paramètres avec le bouton.',
              'en'),
          isTrue);
      expect(
          derive(
              'The interface is now in French. You can switch back in '
              'Settings > Language at any time.',
              'en'),
          isFalse);
    });

    test('le français cible est laissé au contrôle anglais existant', () {
      expect(derive('Bonjour, la broche est allumée et prête.', 'fr'),
          isFalse);
    });

    test('la boucle de relance voit la dérive via le prompt', () {
      final prompt = appLanguageById('auto')
          .trailingPromptAnchor(detectedLanguageCode: 'bm');
      const r = AiApiResponse(parts: [
        {
          'text': 'Ci mëna, je ne comprends pas complètement ta question. '
              'Pourrais-tu reformuler ta demande en français afin que je '
              'comprenne mieux ?'
        }
      ], finishReason: 'STOP');
      expect(
          LocalAiAgentService.hasLanguageDrift(r, const [],
              systemPrompt: prompt),
          isTrue);
    });
  });

  group('dernier recours : couper avant le chinois', () {
    AiApiResponse rep(String t) =>
        AiApiResponse(parts: [{'text': t}], finishReason: 'STOP');

    test('la phrase est coupée au premier caractère CJK (cas réel)', () {
      final r = LocalAiAgentService.cutAtCjk(
          rep("L'interface de l'application a été切换到法语，请确认。"));
      expect(r.text, "L'interface de l'application a été …");
      expect(r.notes, contains(LocalAiAgentService.noteCjkCut));
    });

    test('tout en chinois : réponse vide, que le garde-fou relancera', () {
      final r = LocalAiAgentService.cutAtCjk(rep('请将应用程序界面切换到法语。'));
      expect(r.text, isEmpty);
      expect(LocalAiAgentService.isEmptyReply(r), isTrue);
    });
  });

  test('le hangeul et les kana comptent comme dérive CJK', () {
    expect(LocalAiAgentService.containsCjk('الأ축 X'), isTrue);
    expect(LocalAiAgentService.containsCjk('ひらがな'), isTrue);
    expect(LocalAiAgentService.containsCjk('Broche allumée'), isFalse);
  });
}
