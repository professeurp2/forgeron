import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/command_lexicon.dart';

/// Le lexique d'étude est une donnée (`assets/lexicon/lexique.json`) : ces tests
/// tiennent le MOTEUR — et, pour le français et l'anglais, ce que le lexique
/// livré en fait. Le bambara y figure en `brouillon` : ces lignes disent ce que
/// le brouillon actuel comprend, pas que c'est du bambara correct.
CommandLexicon _shipped() => CommandLexicon.fromJson(
    jsonDecode(File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8))
        as Map<String, dynamic>);

void main() {
  final lex = _shipped();

  void ok(String said, String tool, [Map<String, dynamic>? args]) {
    test('« $said » → $tool${args == null ? '' : ' $args'}', () {
      final r = lex.interpret(said);
      expect(r.match, isNotNull, reason: 'refusé : ${r.refusal}');
      expect(r.match!.tool, tool);
      if (args != null) expect(r.match!.args, args);
    });
  }

  void refused(String said, [String? why]) {
    test('« $said » → refusé${why == null ? '' : ' ($why)'}', () {
      final r = lex.interpret(said);
      expect(r.match, isNull, reason: 'compris à tort : ${r.match}');
      if (why != null) expect(r.refusal, why);
    });
  }

  group('pliage orthographique', () {
    test('les lettres africaines se replient sur l\'ASCII', () {
      expect(foldWord('Mashini jɔ'), 'mashini jo');
      expect(foldWord('ɲɛfɔ'), 'nyefo');
      expect(foldWord('Œuvre à côté'), 'oeuvre a cote');
      expect(foldWord('kɔnɔntɔn'), 'kononton');
    });

    test('un accent décomposé est retiré, une lettre non latine est conservée', () {
      expect(foldWord('été'), 'ete');
      expect(foldWord('አቁም'), 'አቁም');
    });
  });

  group('français', () {
    ok('Donne-moi l\'état de la machine.', 'get_machine_state');
    ok('Où est la machine en ce moment ?', 'get_machine_state');
    ok('Quel est l\'état de la machine ?', 'get_machine_state');
    ok('Arrête tout, c\'est urgent !', 'emergency_stop');
    ok('ARRÊT D\'URGENCE', 'emergency_stop');
    ok('Stop', 'emergency_stop');
    ok('Urgence !', 'emergency_stop');
    ok('Au secours', 'emergency_stop');
    ok('Stoppe la machine', 'emergency_stop');
    ok('Mets le programme en pause.', 'pause');
    ok('Pause', 'pause');
    ok('Fais le homing.', 'home');
    ok('Fais l\'origine de tous les axes.', 'home');
    ok('Déplace l\'axe X de 5 mm à la vitesse de 300.', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('Avance Y de 12,5 mm vitesse 200', 'jog_axis',
        {'axis': 'Y', 'distance': 12.5, 'feedrate': 200});
    ok('Déplace Z de -3 mm F150', 'jog_axis',
        {'axis': 'Z', 'distance': -3, 'feedrate': 150});
    ok('Déplace X de 2 cm vitesse 300', 'jog_axis',
        {'axis': 'X', 'distance': 20, 'feedrate': 300});
    ok('Déplace l\'axe X de cinq millimètres à la vitesse de trois cents.',
        'jog_axis', {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('Déplace X de 5 mm vitesse quatre vingt dix', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 90});
    // Sans mot « vitesse » : le nombre collé à l'unité de longueur est la distance.
    ok('Déplace X 300 5 mm', 'jog_axis', {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('Déplace X 5 mm 300', 'jog_axis', {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('Allume la broche.', 'set_spindle', {'state': 'cw'});
    ok('Démarre la broche s\'il te plaît', 'set_spindle', {'state': 'cw'});
    ok('Éteins la broche.', 'set_spindle', {'state': 'off'});
    ok('Arrête la broche', 'set_spindle', {'state': 'off'});
    ok('Pose le zéro pièce ici.', 'set_work_zero');
  });

  group('anglais', () {
    ok('Show me the machine state.', 'get_machine_state');
    ok('Emergency stop', 'emergency_stop');
    ok('E-stop', 'emergency_stop');
    ok('Stop', 'emergency_stop');
    ok('Please stop everything now', 'emergency_stop');
    ok('Pause the program.', 'pause');
    ok('Do the homing.', 'home');
    ok('Home all axes', 'home');
    ok('Turn on the spindle.', 'set_spindle', {'state': 'cw'});
    ok('Turn off the spindle', 'set_spindle', {'state': 'off'});
    ok('Spindle on', 'set_spindle', {'state': 'cw'});
    ok('Spindle off', 'set_spindle', {'state': 'off'});
    ok('Set the work zero here.', 'set_work_zero');
    ok('Move the X axis by 5 millimeters at a speed of 300.', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('Move X by five mm at speed three hundred', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
  });

  group('bambara (brouillon — à corriger par un locuteur)', () {
    ok('Mansin cogoya jira n ye.', 'get_machine_state');
    ok('Mansin bɛ cogo di?', 'get_machine_state');
    ok('Mansin jɔ sisan, joona!', 'emergency_stop');
    ok('Programme jɔ dɔɔnin.', 'pause');
    ok('Programme makɔnɔ.', 'pause');
    ok('Mansin segin a daminɛ yɔrɔ la.', 'home');
    ok('X taa mm 5 la, teliya 300.', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('X taa mm duuru la, teliya kɛmɛ saba.', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('X taa mm mugan ni duuru la, teliya kɛmɛ ni saba', 'jog_axis',
        {'axis': 'X', 'distance': 25, 'feedrate': 103});
    ok('X taa mm bi saba ni duuru, teliya waa fila', 'jog_axis',
        {'axis': 'X', 'distance': 35, 'feedrate': 2000});
    // Les dizaines sont un seul mot dans le dictionnaire (« bisaba »), deux dans la
    // saisie courante (« bi saba ») : les deux sont lus.
    ok('X taa mm bisaba ni duuru, teliya waa fila', 'jog_axis',
        {'axis': 'X', 'distance': 35, 'feedrate': 2000});
    ok('X taa mm biwooro, teliya kɛmɛ', 'jog_axis',
        {'axis': 'X', 'distance': 60, 'feedrate': 100});
    ok('Zero in da yan.', 'set_work_zero');
    ok('Broche daminɛ.', 'set_spindle', {'state': 'cw'});
    ok('Broche dabila.', 'set_spindle', {'state': 'off'});
    // Mélange avec le français, tel qu'on parle en atelier.
    ok('Arrêt d\'urgence mansin la, sisan!', 'emergency_stop');
    ok('Programme pause kɛ.', 'pause');
    ok('Homing kɛ.', 'home');
    ok('Axe X taa 5 mm la, vitesse 300.', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
    ok('Broche allumer sisan.', 'set_spindle', {'state': 'cw'});
  });

  group('la saisie sans les lettres africaines se fait comprendre', () {
    ok('Mansin jo sisan, joona!', 'emergency_stop');
    ok('Programme jo doonin.', 'pause');
    ok('Mansin segin a damine yoro la.', 'home');
    ok('Broche damine.', 'set_spindle', {'state': 'cw'});
    ok('X taa mm duuru la, teliya keme saba.', 'jog_axis',
        {'axis': 'X', 'distance': 5, 'feedrate': 300});
  });

  group('une faute de frappe sur un mot long est tolérée', () {
    ok('Demare la broche', 'set_spindle', {'state': 'cw'});
    ok('Mansin cogoyya jira n ye', 'get_machine_state');
  });

  group('refus : jamais une action à l\'envers', () {
    refused('Ne démarre pas la broche', 'negation');
    refused('Ne t\'arrête pas', 'negation');
    refused('Don\'t start the spindle', 'negation');
    refused('Broche kana daminɛ', 'negation');
    refused('Broche tɛ daminɛ', 'negation');
    refused('Démarre la broche après le homing', 'condition');
    refused('Allume la broche et lance le programme', 'condition');
    refused('Stop the spindle when the program ends', 'condition');
    refused('Recule X de 5 mm à 300', 'direction');
    refused('Monte Z de 3 mm à 200', 'direction');
    refused('Déplace X de moins 5 mm vitesse 300', 'direction');
    refused('Move X back by 5 mm at 300', 'direction');
    refused('Z jigin mm 3 la, teliya 200', 'direction');
  });

  group('refus : une question n\'est pas un ordre', () {
    refused('Pourquoi l\'arrêt d\'urgence ne marche pas ?');
    refused('Est-ce que tu peux arrêter tout ?', 'question');
    refused('Allume la broche ?', 'question');
    refused('Explique-moi le homing', 'question');
    refused('What is homing?', 'question');
    refused('Why does the emergency stop not work?');
    refused('Homing ye mun ye, a ɲɛfɔ n ye.');
  });

  group('refus : ce que le lexique ne sait pas', () {
    refused('');
    refused('   ');
    refused('Est-ce qu\'il va pleuvoir demain ?');
    refused('Sanji bɛna na sini wa?');
    refused('Reprends le programme.', 'aucune_intention');
    refused('Arrête le programme', 'aucune_intention');
    refused('Stop the program at line 40', 'aucune_intention');
    refused('Mets le programme en pause à la ligne 40', 'mots_inconnus');
    refused('Stop, je me suis trompé de fichier', 'mots_inconnus');
    refused('Fais le homing de l\'axe Z uniquement');
    refused('Pose le zéro sur X et Y');
    refused('Avance X de 2 mm', 'manque:vitesse');
    refused('Déplace de 5 mm à 300', 'manque:axe');
    // Un nombre seul, sans unité ni mot « vitesse », est pris pour la distance :
    // il manque donc la vitesse. Refus dans tous les cas — jamais deviné.
    refused('Déplace X à 300', 'manque:vitesse');
    refused('Déplace X de 5 mm Y de 3 mm vitesse 300', 'axes_multiples');
    refused('Déplace X de 5 mm 3 cm', 'trop_de_nombres'); // deux longueurs : ambigu
    // « mm/min » n'est pas compris (limite connue) : refus, le modèle reprend.
    refused('Déplace Z de 10 mm à 500 mm/min', 'mots_inconnus');
    refused('Allume la broche et éteins la broche');
    refused('Mets l\'avance à 80 %');
  });

  group('un mot d\'arrêt court sans objet vaut arrêt d\'urgence, pas plus', () {
    ok('Stop !', 'emergency_stop');
    refused('Stop la broche et le programme');
    refused('Urgence ou pas, je veux voir la position');
    // Mesuré sous bruit : « Éteins la brohe » (faute sur « broche ») ne doit
    // JAMAIS devenir un arrêt d'urgence — l'objet perdu n'est pas « aucun objet ».
    refused('Éteins la brohe', 'mots_inconnus');
    refused('Stop la brohe', 'mots_inconnus');
    refused('Brche dabila', 'mots_inconnus');
  });

  group('lecture d\'état : un mot inconnu toléré, pas deux', () {
    ok('Où est la machine en ce moment ?', 'get_machine_state');
    refused('Sini météo bɛ cogo di?', 'mots_inconnus');
  });

  group('le lexique livré', () {
    test('aucun mot ne peut être pris pour un mot de sens différent', () {
      expect(lex.conflicts(), isEmpty);
    });

    test('chaque langue est annoncée en brouillon tant que personne ne l\'a relue', () {
      expect(lex.languages, containsAll(['fr', 'en', 'bm']));
      for (final l in lex.languages) {
        expect(lex.statuses[l], 'brouillon');
      }
    });

    test('la charge de relecture est connue', () {
      final s = lex.sizes();
      expect(s['bm'], isNotNull);
      final bm = s['bm']!.values.fold<int>(0, (a, b) => a + b);
      expect(bm, lessThan(100), reason: 'une langue doit rester relisable en une séance');
    });
  });

  group('nombres : jamais deviner', () {
    // Deux langues où « saba » vaut 3 et 7 : sans indice dans la phrase, refus.
    final twoLangs = CommandLexicon.fromJson({
      'intents': [
        {'id': 'jog', 'tool': 'jog_axis', 'action': ['move'], 'object': ['axe', null], 'slots': ['axis', 'distance', 'feedrate'], 'tolerance': 0},
      ],
      'languages': {
        'bm': {
          'status': 'brouillon',
          'actions': {'move': ['taa']},
          'units': {'mm': ['mm']},
          'feed': ['teliya'],
          'numbers': {'style': 'multiplier_after', 'units': {'saba': 3, 'duuru': 5}},
        },
        'sw': {
          'status': 'brouillon',
          'actions': {'move': ['sogeza']},
          'units': {'mm': ['mm']},
          'feed': ['kasi'],
          'numbers': {'style': 'multiplier_after', 'units': {'saba': 7, 'tano': 5}},
        },
      },
    });

    test('« saba » seul entre deux langues : refusé', () {
      expect(twoLangs.interpret('X mm saba 300').refusal, isNotNull);
      expect(twoLangs.interpret('X mm saba teliya 300').match, isNull);
    });

    test('un mot propre à une langue lève l\'ambiguïté', () {
      final bm = twoLangs.interpret('X taa mm saba teliya 300');
      expect(bm.match?.args['distance'], 3);
      final sw = twoLangs.interpret('X sogeza mm saba kasi 300');
      expect(sw.match?.args['distance'], 7);
    });

    test('« duuru » n\'est jamais lu « wooro » : pas de nombre deviné', () {
      final r = lex.interpret('X taa mm wooro la, teliya 300');
      expect(r.match?.args['distance'], 6);
      // Une dictée qui transforme « duuru » en « duuri » ne devient pas un autre
      // nombre : le mot est inconnu, la commande refusée.
      expect(lex.interpret('X taa mm duuri la, teliya 300').match, isNull);
    });
  });

  group('mode souple : des suggestions, pas des ordres', () {
    LexiconMatch? soft(String said) => lex.interpret(said, relaxed: true).match;

    test('une dictée abîmée est suggérée, marquée « souple »', () {
      expect(lex.interpret('Allume la brohe').match, isNull); // strict : refus
      final m = soft('Allume la brohe');
      expect(m, isNotNull);
      expect(m!.tool, 'set_spindle');
      expect(m.args, {'state': 'cw'});
      expect(m.relaxed, isTrue);
    });

    test('« Éteins la brohe » devient « éteindre la broche », pas un arrêt d\'urgence', () {
      final m = soft('Éteins la brohe');
      expect(m?.tool, 'set_spindle');
      expect(m?.args, {'state': 'off'});
    });

    test('un résultat strict n\'est pas marqué souple', () {
      final m = lex.interpret('Allume la broche').match;
      expect(m?.relaxed, isFalse);
    });

    test('les refus ne s\'assouplissent pas', () {
      expect(lex.interpret('Ne démarre pas la brohe', relaxed: true).refusal, 'negation');
      expect(lex.interpret('Démarre la brohe après le homing', relaxed: true).refusal, 'condition');
      expect(lex.interpret('Explique le homing', relaxed: true).refusal, 'question');
      expect(lex.interpret('Recule X de 5 mm à 300', relaxed: true).refusal, 'direction');
    });

    test('un nombre reste exact même en mode souple', () {
      expect(soft('X taa mm duuri la, teliya 300'), isNull);
      expect(soft('X taa mm duuru la, teliya 300')?.args['distance'], 5);
    });

    test('un mot abîmé n\'est jamais avalé comme un mot-outil (« trois cets » ≠ 3)', () {
      // Mesuré : « cets » devenait « cet » (mot-outil) et la vitesse valait 3.
      expect(soft('Déplace l\'axe X de cinq millimètres à la vitesse de trois cets'), isNull);
      expect(soft('Déplace l\'axe X de cinq millimètres à la vitesse de trois cents')?.args['feedrate'], 300);
    });

    test('un mot court n\'est jamais deviné (« sini » ≠ « sigi »)', () {
      expect(soft('Sini météo bɛ cogo di?'), isNull);
    });

    test('le hors-sujet reste refusé en mode souple', () {
      expect(soft('Sanji bɛna na sini wa?'), isNull);
      expect(soft('Est-ce qu\'il va pleuvoir demain ?'), isNull);
    });

    test('aucun mot d\'arrêt ne peut être pris pour un mot de démarrage, même en souple', () {
      final crossed = lex
          .conflicts(relaxed: true)
          .where((c) => c.contains('action/stop') && c.contains('action/start'));
      expect(crossed, isEmpty);
    });
  });

  group('mots proches : le garde-fou de la distance', () {
    test('deux mots de sens opposé trop proches sont signalés', () {
      final risky = CommandLexicon.fromJson({
        'intents': <Map<String, dynamic>>[],
        'languages': {
          'x': {
            'status': 'brouillon',
            'actions': {'stop': ['arretez'], 'start': ['arretes']},
          },
        },
      });
      expect(risky.conflicts(), isNotEmpty);
    });
  });
}
