import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/core/utils/lexicon_schema.dart';

Map<String, dynamic> _shipped() => (jsonDecode(
        File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8))
    as Map).cast<String, dynamic>();

Map<String, dynamic> _copy() =>
    (jsonDecode(jsonEncode(_shipped())) as Map).cast<String, dynamic>();

LexiconValidation _check(Map<String, dynamic> j) =>
    validateLexiconJson(j, tools: lexiconToolInfos());

List _intents(Map<String, dynamic> j) => j['intents'] as List;
Map _lang(Map<String, dynamic> j, String l) =>
    (j['languages'] as Map)[l] as Map;

void main() {
  test('le lexique livré est valide, sans erreur', () {
    final v = _check(_shipped());
    expect(v.errors, isEmpty, reason: '$v');
  });

  test('loadLexiconFromSource : livré = disponible, cassé = indisponible', () {
    expect(
        loadLexiconFromSource(File('assets/lexicon/lexique.json')
                .readAsStringSync(encoding: utf8))
            .available,
        isTrue);
    expect(loadLexiconFromSource('pas du json').available, isFalse);
    expect(loadLexiconFromSource('[]').available, isFalse);
  });

  void rejects(String name, void Function(Map<String, dynamic>) mutate,
      String path) {
    test('refuse : $name', () {
      final j = _copy();
      mutate(j);
      final v = _check(j);
      expect(
          v.errors
              .any((e) => e.path.contains(path) || e.message.contains(path)),
          isTrue,
          reason: 'attendu une erreur sur « $path », trouvé :\n$v');
    });
  }

  rejects('format inconnu', (j) => j['schema'] = 99, 'schema');
  rejects('version mal formée', (j) => j['version'] = 'v2', 'version');
  rejects('outil inexistant',
      (j) => (_intents(j)[0] as Map)['tool'] = 'fait_cafe', 'tool');
  rejects('tolérance sur un ordre qui agit', (j) {
    for (final i in _intents(j)) {
      if ((i as Map)['id'] == 'jog') i['tolerance'] = 1;
    }
  }, 'tolerance');
  rejects('lecture seule sur un outil soumis à confirmation', (j) {
    for (final i in _intents(j)) {
      if ((i as Map)['id'] == 'jog') i['read_only'] = true;
    }
  }, 'read_only');
  rejects('mot d\'alarme isolé sur un autre outil que l\'arrêt', (j) {
    for (final i in _intents(j)) {
      if ((i as Map)['id'] == 'pause') i['alarm_alone'] = true;
    }
  }, 'alarm_alone');
  rejects('argument obligatoire manquant', (j) {
    for (final i in _intents(j)) {
      if ((i as Map)['id'] == 'jog') i['slots'] = ['axis', 'distance'];
    }
  }, 'feedrate');
  rejects('valeur hors énumération', (j) {
    for (final i in _intents(j)) {
      if ((i as Map)['id'] == 'brocheon') i['args'] = {'state': 'sideways'};
    }
  }, 'args.state');
  rejects('verbe défini dans aucune langue',
      (j) => (_intents(j)[0] as Map)['action'] = ['voler'], 'voler');
  rejects('langue relue sans relecteur',
      (j) => _lang(j, 'fr')['status'] = 'relu', 'reviewed_by');
  rejects('relecteur qui est un modèle', (j) {
    _lang(j, 'fr')['status'] = 'relu';
    _lang(j, 'fr')['reviewed_by'] = 'Claude';
    _lang(j, 'fr')['reviewed_on'] = '2026-10-23';
  }, 'reviewed_by');
  rejects('brouillon avec relecteur',
      (j) => _lang(j, 'bm')['reviewed_by'] = 'Awa Traoré', 'status');
  rejects('mots confondables', (j) {
    ((_lang(j, 'fr')['actions'] as Map)['start'] as List).add('arrête');
  }, 'confondables');
  rejects('nombre déclaré deux fois', (j) {
    ((_lang(j, 'bm')['numbers'] as Map)['tens'] as Map)['kelen'] = 10;
  }, 'kelen');
  rejects('phrase fixe inconnue',
      (j) => _lang(j, 'bm')['replies'] = {'blague': 'ha'}, 'blague');

  test('langue relue avec une personne et une date : acceptée', () {
    final j = _copy();
    _lang(j, 'fr')['status'] = 'relu';
    _lang(j, 'fr')['reviewed_by'] = 'Awa Traoré';
    _lang(j, 'fr')['reviewed_on'] = '2026-10-23';
    expect(_check(j).errors, isEmpty);
  });

  test('un fichier de mauvaise forme donne des erreurs, jamais une exception',
      () {
    expect(_check({'languages': [], 'intents': 3}).ok, isFalse);
    expect(_check({}).ok, isFalse);
  });
}
