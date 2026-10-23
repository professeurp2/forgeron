import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/command_lexicon.dart';

/// « Pas de changement de lexique non daté. » Le fichier .lock porte la version,
/// l'empreinte et les statuts de relecture ; modifier les mots sans relancer
/// `dart run tool/lexicon/lock.dart` (et sans changer `version`) fait échouer ici.
void main() {
  test('le lexique correspond à son verrou', () {
    final lex = CommandLexicon.fromJsonString(
        File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8));
    final lock = jsonDecode(File('assets/lexicon/lexique.lock.json')
        .readAsStringSync(encoding: utf8)) as Map;
    expect(lex.fingerprint, lock['fingerprint'],
        reason: 'Le lexique a changé : incrémenter `version` puis '
            '`dart run tool/lexicon/lock.dart`, et committer les deux fichiers.');
    expect(lex.version, lock['version']);
    for (final l in lex.languages) {
      expect((lock['languages'] as Map)[l]['status'], lex.statuses[l], reason: l);
    }
  });

  test('l\'empreinte ne dépend pas des fins de ligne', () {
    final raw = File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8);
    final crlf = raw.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
    expect(CommandLexicon.fromJsonString(crlf).fingerprint,
        CommandLexicon.fromJsonString(raw).fingerprint);
  });
}
