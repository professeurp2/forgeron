// Banc du traducteur local (LocalTranslator) sur de vraies réponses d'agent.
//
//   flutter test tool/eval/traducteur_test.dart
//   (TRAD_URL=http://127.0.0.1:11434  TRAD_MODEL=gemma3:12b  TRAD_LANGS=sw,ha)
//
// Mesure, par langue : traductions acceptées par le contrôle (nombres, code),
// motifs de rejet, latence. Écrit le détail dans
// tool/eval/traducteur_<date>.md pour relecture par un locuteur : le contrôle
// vérifie les nombres, pas le sens.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/local_translator.dart';

const _replies = [
  'La machine est prête. Les axes sont à l\'origine.',
  'Je déplace l\'axe Z de -5 mm. Vérifie que rien ne gêne l\'outil.',
  'Alarme 2 : fin de course atteinte sur X. Dégage l\'axe à la main, puis fais un homing.',
  'Le programme piece.nc dure environ 12 minutes. Je le lance quand tu confirmes.',
  'Arrêt fait. La broche est coupée.',
  'Voici le programme :\n```gcode\nG21 G90\nG0 X10 Y20\nM3 S1000\n```\nVérifie-le avant de lancer.',
  'Je ne trouve pas ce fichier. Dis-moi son nom exact.',
  'Mets tes lunettes de protection avant de démarrer la broche.',
];

const _names = {'sw': 'swahili', 'ha': 'haoussa', 'wo': 'wolof'};

void main() {
  final env = Platform.environment;
  final url = env['TRAD_URL'] ?? 'http://127.0.0.1:11434';
  final model = env['TRAD_MODEL'] ?? LocalTranslator.defaultModel;
  final langs = (env['TRAD_LANGS'] ?? 'sw,ha').split(',');

  test('traducteur $model', () async {
    final out = StringBuffer()
      ..writeln('# Banc du traducteur — $model, ${DateTime.now()}')
      ..writeln()
      ..writeln('Contrôle automatique : nombres et blocs de code. Le SENS est '
          'à faire relire par un locuteur.')
      ..writeln();
    final t = LocalTranslator(
        baseUrl: url, model: model, languages: langs.toSet());
    for (final lang in langs) {
      var ok = 0;
      final times = <int>[];
      final reasons = <String, int>{};
      out
        ..writeln('## ${_names[lang] ?? lang}')
        ..writeln();
      for (final fr in _replies) {
        final sw = Stopwatch()..start();
        final r = await t.translate(fr, _names[lang] ?? lang);
        times.add(sw.elapsedMilliseconds);
        if (r.text != null) ok++;
        if (r.rejection != null) {
          reasons[r.rejection!] = (reasons[r.rejection!] ?? 0) + 1;
        }
        out
          ..writeln('- FR : ${fr.replaceAll('\n', ' ⏎ ')}')
          ..writeln('  - ${r.text != null ? 'OK' : 'REJET ${r.rejection}'} '
              '(${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s) : '
              '${(r.text ?? r.raw ?? '—').replaceAll('\n', ' ⏎ ')}');
      }
      times.sort();
      final line = '$lang : $ok/${_replies.length} acceptées, '
          'médiane ${(times[times.length ~/ 2] / 1000).toStringAsFixed(1)} s, '
          'max ${(times.last / 1000).toStringAsFixed(1)} s, rejets $reasons';
      // ignore: avoid_print
      print(line);
      out
        ..writeln()
        ..writeln('**$line**')
        ..writeln();
    }
    final day = DateTime.now().toIso8601String().substring(0, 10);
    File('tool/eval/traducteur_$day.md').writeAsStringSync(out.toString());
  }, timeout: const Timeout(Duration(minutes: 30)));
}
