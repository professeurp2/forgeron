// Régénère assets/lexicon/lexique.lock.json : version, empreinte et statut de
// relecture de chaque langue. À lancer après toute modification du lexique :
//   dart run tool/lexicon/lock.dart
// Refuse d'écrire si le contenu a changé sans changement de `version`.
import 'dart:convert';
import 'dart:io';

import 'package:forgeron/core/utils/command_lexicon.dart';

void main() {
  final data = File('assets/lexicon/lexique.json');
  final lockFile = File('assets/lexicon/lexique.lock.json');
  final lex = CommandLexicon.fromJsonString(data.readAsStringSync(encoding: utf8));
  final lock = {
    'version': lex.version,
    'fingerprint': lex.fingerprint,
    'languages': {
      for (final l in lex.languages)
        l: {
          'status': lex.statuses[l],
          'reviewed_by': lex.reviews[l]?.by,
          'reviewed_on': lex.reviews[l]?.on,
        },
    },
  };
  if (lockFile.existsSync()) {
    final old = jsonDecode(lockFile.readAsStringSync()) as Map;
    if (old['version'] == lex.version && old['fingerprint'] != lex.fingerprint) {
      stderr.writeln('Le lexique a changé mais `version` est restée ${lex.version} : '
          'incrémentez-la dans assets/lexicon/lexique.json avant de verrouiller.');
      exit(1);
    }
  }
  lockFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(lock)}\n');
  stdout.writeln('Verrou écrit : ${lex.version} / ${lex.fingerprint}');
}
