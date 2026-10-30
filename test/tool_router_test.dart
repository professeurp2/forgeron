import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/tool_router.dart';

void main() {
  const router = ToolRouter();
  final all = AiToolCatalog.tools.map((t) => t.name).toList();

  Routing route(String text, {Set<String> recent = const {}}) =>
      router.route(text: text, allTools: all, recentGroups: recent);

  group('cohérence avec le catalogue', () {
    test('chaque outil cité par un groupe ou le noyau existe vraiment', () {
      final known = all.toSet();
      for (final e in ToolRouter.groups.entries) {
        expect(known.containsAll(e.value.tools), isTrue,
            reason: 'groupe « ${e.key} » : '
                '${e.value.tools.difference(known)} absent du catalogue');
      }
      expect(known.containsAll(ToolRouter.core), isTrue);
    });

    test('le noyau de sécurité contient l\'arrêt d\'urgence', () {
      expect(ToolRouter.core, contains('emergency_stop'));
      expect(ToolRouter.core, contains('get_machine_state'));
    });

    test('chaque outil du catalogue est atteignable par au moins un groupe '
        'ou le noyau', () {
      final reachable = {
        ...ToolRouter.core,
        for (final g in ToolRouter.groups.values) ...g.tools,
      };
      expect(all.toSet().difference(reachable), isEmpty,
          reason: 'un outil inatteignable ne serait JAMAIS déclaré quand le '
              'routeur est actif');
    });
  });

  group('routage', () {
    test('« état » : les outils de lecture, pas le pipeline STEP', () {
      final r = route('Donne-moi l\'état de la machine.');
      expect(r.routed, isTrue);
      expect(r.tools, containsAll(['get_machine_state', 'get_diagnostics']));
      expect(r.tools, isNot(contains('run_step_pipeline')));
      expect(r.tools, isNot(contains('write_workspace_file')));
      expect(r.tools.length, lessThan(all.length ~/ 2));
    });

    test('mouvement chiffré', () {
      final r = route('Avance l\'axe X de 5 mm à 300 mm/min.');
      expect(r.tools, contains('jog_axis'));
      expect(r.tools, isNot(contains('run_step_pipeline')));
    });

    test('broche', () {
      expect(route('Allume la broche.').tools, contains('set_spindle'));
      expect(route('Éteins la broche.').tools, contains('set_spindle'));
      expect(route('Mets l\'avance à 80 %.').tools, contains('set_feed_override'));
      expect(route('Active l\'arrosage liquide.').tools, contains('set_coolant'));
    });

    test('fichier STEP : aperçu et pipeline', () {
      final r = route('Ouvre l\'aperçu 3D du fichier C:\\pieces\\support.step');
      expect(r.tools, containsAll(['preview_step_file', 'run_step_pipeline']));
    });

    test('fichiers de l\'espace de travail', () {
      final r = route('Lis le fichier dome_r20.nc.');
      expect(r.tools, containsAll(['read_workspace_file', 'list_workspace_files']));
    });

    test('plusieurs intentions : l\'union des groupes', () {
      final r = route('Fais l\'origine, allume la broche puis lance le programme.');
      expect(r.tools,
          containsAll(['home', 'set_spindle', 'run_program']));
    });

    test('anglais', () {
      expect(route('What is the machine status?').tools, contains('get_machine_state'));
      expect(route('Jog the C axis by 90 degrees at feed 800.').tools, contains('jog_axis'));
      expect(route('List the files in my workspace.').tools, contains('list_workspace_files'));
    });

    test('scan 3D et reco3d', () {
      final r1 = route('Scanne la pièce sur la machine avec 24 photos.');
      expect(r1.tools, containsAll(['start_machine_scan', 'get_reco3d_status']));

      final r2 = route('Quel est l\'état du poste de calcul reco3d ?');
      expect(r2.tools, containsAll(['get_reco3d_status', 'discover_reco3d_server']));

      final r3 = route('Télécharge le modèle 3D du scan');
      expect(r3.tools, containsAll(['download_scan_result', 'get_scan_job_status']));
    });
  });

  group('prudence', () {
    test('le noyau de sécurité est toujours là quand le routage agit', () {
      for (final m in [
        'Donne-moi l\'état.',
        'Allume la broche.',
        'Lis le fichier a.nc.',
        'Ouvre l\'aperçu du fichier x.step',
      ]) {
        expect(route(m).tools, containsAll(ToolRouter.core), reason: m);
      }
    });

    test('rien de reconnu : TOUS les outils, routage déclaré inactif', () {
      for (final m in [
        'oui',
        'vas-y',
        'Merci, c\'est tout pour aujourd\'hui.',
        'ሁሉንም ነገር አሁኑኑ አቁም!',
        '',
      ]) {
        final r = route(m);
        expect(r.routed, isFalse, reason: m);
        expect(r.tools, all.toSet(), reason: m);
      }
    });

    test('un « oui » garde les groupes du tour précédent', () {
      final r = route('oui', recent: {'broche'});
      expect(r.routed, isTrue);
      expect(r.tools, contains('set_spindle'));
      expect(r.tools, containsAll(ToolRouter.core));
    });

    test('ne sort jamais du catalogue fourni', () {
      final partial = ['get_machine_state', 'emergency_stop', 'jog_axis'];
      final r = router.route(text: 'Avance X de 5 mm', allTools: partial);
      expect(partial.toSet().containsAll(r.tools), isTrue);
    });

    test('un mot-clé court ne se trouve pas au milieu d\'un autre mot', () {
      // « log » ne doit pas être reconnu dans « analogique ».
      final r = route('Le signal analogique est bizarre');
      expect(r.routed, isFalse,
          reason: '« log » ne doit pas être reconnu dans « analogique »');
    });
  });
}
