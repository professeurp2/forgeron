// Mesure du lexique fermé (étude des langues locales).
//
//   flutter test tool/eval/lang/lexique_eval_test.dart
//
// Trois mesures, sans modèle ni réseau :
//
//   1. SUR LES ÉNONCÉS DE L'ÉTUDE (`tool/eval/scenarios_langues`) — les mêmes
//      que ceux du modèle local. Pour chaque ordre : compris (bon outil, bons
//      arguments), compris de travers, ou refusé. Pour chaque phrase qui n'est
//      pas un ordre : refusée, ou activée à tort.
//   2. SUR DES ÉNONCÉS ÉCRITS AVANT LE LEXIQUE (`tool/eval/scenarios`, les 77
//      scénarios du produit) — le seul contrôle un peu indépendant de l'auteur
//      du lexique : où le lexique réagit, a-t-il raison ?
//   3. SOUS BRUIT — le même énoncé abîmé comme le ferait une dictée ou une
//      frappe fautive (substitution, perte, ajout de lettres). Ce qu'on attend :
//      le taux de refus monte, le taux de MAUVAISE compréhension reste à zéro.
//
// Rapport : `eval_reports/<date>_lexique.md`.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/command_lexicon.dart';

import '../bench_core.dart';

enum _O { correct, wrong, refused }

List<BenchScenario> _load(String dir) {
  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final raw = <Object?>[];
  for (final f in files) {
    raw.addAll(jsonDecode(f.readAsStringSync(encoding: utf8)) as List);
  }
  return parseScenarios(raw);
}

/// Le scénario est-il un ordre (un outil est attendu) ?
bool _isOrder(BenchScenario s) => s.expect.tools.isNotEmpty;

_O _classify(BenchScenario s, LexiconResult r) {
  final m = r.match;
  if (m == null) return _O.refused;
  if (!_isOrder(s)) return _O.wrong; // activation à tort
  final v = evaluate(s.expect,
      BenchTrace(calls: [BenchCall(m.tool, m.args)], turns: 1));
  return v.pass ? _O.correct : _O.wrong;
}

String _pct(int k, int n) => n == 0 ? '—' : '${(100 * k / n).round()} %';

String _noisy(String s, double p, math.Random rnd) {
  final letters = RegExp(r'\p{L}', unicode: true);
  const alphabet = 'abcdefghijklmnopqrstuvwxyz';
  final out = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (!letters.hasMatch(ch) || rnd.nextDouble() >= p) {
      out.write(ch);
      continue;
    }
    switch (rnd.nextInt(3)) {
      case 0: // substitution
        out.write(alphabet[rnd.nextInt(alphabet.length)]);
      case 1: // perte
        break;
      default: // ajout
        out
          ..write(ch)
          ..write(alphabet[rnd.nextInt(alphabet.length)]);
    }
  }
  return out.toString();
}

void main() {
  test('Lexique fermé — mesure', () {
    final lex = CommandLexicon.fromJson(
        jsonDecode(File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8))
            as Map<String, dynamic>);
    final b = StringBuffer();
    final date = DateTime.now().toIso8601String().substring(0, 16);

    b.writeln('# Lexique fermé — mesure');
    b.writeln();
    b.writeln('*$date · sans modèle ni réseau · lexique `assets/lexicon/lexique.json`*');
    b.writeln();
    b.writeln('Langues du lexique : ${lex.languages.map((l) => '`$l` (${lex.statuses[l]})').join(', ')}.');
    b.writeln();
    b.writeln('Taille (mots et expressions déclarés) : '
        '${lex.sizes().entries.map((e) => '**${e.key}** ${e.value.values.fold<int>(0, (a, c) => a + c)}').join(' · ')}.');
    b.writeln();
    expect(lex.conflicts(), isEmpty);

    // ── 1. Énoncés de l'étude ─────────────────────────────────────────────
    final study = _load('tool/eval/scenarios_langues');
    final byLang = <String, List<(BenchScenario, _O)>>{};
    for (final s in study) {
      byLang.putIfAbsent(s.language, () => []).add((s, _classify(s, lex.interpret(s.user!))));
    }
    const order = ['fr', 'en', 'ar', 'sw', 'ha', 'yo', 'am', 'wo', 'bm', 'bm-mixte', 'bm-ascii'];
    b.writeln('## 1. Énoncés de l\'étude (les mêmes que pour le modèle local)');
    b.writeln();
    b.writeln('| langue | ordres : compris | ordres : refusés | ordres : MAL compris | non-ordres : activés à tort | énoncés |');
    b.writeln('|---|---:|---:|---:|---:|---:|');
    for (final l in order) {
      final rows = byLang[l];
      if (rows == null) continue;
      final orders = rows.where((r) => _isOrder(r.$1)).toList();
      final non = rows.where((r) => !_isOrder(r.$1)).toList();
      final ok = orders.where((r) => r.$2 == _O.correct).length;
      final ref = orders.where((r) => r.$2 == _O.refused).length;
      final bad = orders.where((r) => r.$2 == _O.wrong).length;
      final act = non.where((r) => r.$2 == _O.wrong).length;
      b.writeln('| $l | **${_pct(ok, orders.length)}** ($ok/${orders.length}) | ${_pct(ref, orders.length)} | ${_pct(bad, orders.length)} | ${_pct(act, non.length)} | ${rows.length} |');
    }
    b.writeln();
    b.writeln('> Les langues sans lexique (`ar`, `sw`, `ha`, `yo`, `am`, `wo`) sont refusées en bloc : '
        'c\'est le coût marginal d\'une langue — un bloc de données à écrire et à faire relire.');
    b.writeln();

    final detail = StringBuffer();
    for (final l in ['fr', 'en', 'bm', 'bm-mixte', 'bm-ascii']) {
      for (final r in byLang[l] ?? const <(BenchScenario, _O)>[]) {
        if (r.$2 == _O.correct && _isOrder(r.$1)) continue;
        if (r.$2 == _O.refused && !_isOrder(r.$1)) continue;
        final res = lex.interpret(r.$1.user!);
        detail.writeln('- `${r.$1.id}` « ${r.$1.user} » → '
            '${res.match ?? 'refusé (${res.refusal})'} — ${r.$2 == _O.wrong ? '**MAL COMPRIS**' : 'refusé'}');
      }
    }
    b.writeln('Détail des ordres non compris et des activations à tort (langues du lexique) :');
    b.writeln();
    b.writeln(detail.isEmpty ? 'Aucun.' : detail.toString());

    // ── 2. Énoncés écrits avant le lexique ────────────────────────────────
    final product = _load('tool/eval/scenarios').where((s) => s.user != null).toList();
    var right = 0, wrong = 0, refused = 0;
    final wrongList = StringBuffer();
    final rightList = StringBuffer();
    final reasons = <String, List<String>>{};
    for (final s in product) {
      final r = lex.interpret(s.user!);
      if (r.match == null) {
        refused++;
        (reasons[r.refusal ?? '?'] ??= []).add(s.id);
        continue;
      }
      final v = evaluate(s.expect, BenchTrace(calls: [BenchCall(r.match!.tool, r.match!.args)], turns: 1));
      // Les attentes qui exigent un texte (réponse) ne se jugent pas sans modèle.
      final onlyTool = s.expect.tools.isNotEmpty;
      if (onlyTool && v.pass) {
        right++;
        rightList.writeln('- `${s.id}` « ${s.user} » → ${r.match}');
      } else {
        wrong++;
        wrongList.writeln('- `${s.id}` (${s.category}) « ${s.user} » → ${r.match} ; attendu : '
            '${s.expect.tools.isNotEmpty ? s.expect.tools : s.expect.noTool ? 'aucun outil' : '—'}');
      }
    }
    b.writeln('## 2. Énoncés écrits AVANT le lexique (${product.length} scénarios du produit, français et anglais)');
    b.writeln();
    b.writeln('| le lexique… | nombre |');
    b.writeln('|---|---:|');
    b.writeln('| a raison (bon outil, bons arguments) | $right |');
    b.writeln('| a tort (activation inattendue ou mauvais outil) | **$wrong** |');
    b.writeln('| refuse (le modèle prend le relais) | $refused |');
    b.writeln();
    b.writeln('Pourquoi il refuse (les $refused refus) : '
        '${(reasons.entries.toList()..sort((a, c) => c.value.length.compareTo(a.value.length))).map((e) => '`${e.key}` ×${e.value.length}').join(' · ')}.');
    b.writeln();
    b.writeln('Où il réagit, et a raison :');
    b.writeln();
    b.writeln(rightList.isEmpty ? 'Nulle part.' : rightList.toString());
    b.writeln('Où il réagit, et a TORT :');
    b.writeln();
    b.writeln(wrongList.isEmpty ? 'Nulle part.' : wrongList.toString());

    // Mode souple, mêmes énoncés : ce qu'il ajoute, ce qu'il risque.
    var sRight = 0, sWrong = 0, sRefused = 0;
    final sWrongList = StringBuffer();
    for (final s in product) {
      final r = lex.interpret(s.user!, relaxed: true);
      if (r.match == null) {
        sRefused++;
        continue;
      }
      final v = evaluate(s.expect,
          BenchTrace(calls: [BenchCall(r.match!.tool, r.match!.args)], turns: 1));
      if (s.expect.tools.isNotEmpty && v.pass) {
        sRight++;
      } else {
        sWrong++;
        sWrongList.writeln('- `${s.id}` « ${s.user} » → ${r.match}');
      }
    }
    b.writeln('Mode **souple** (suggestions à confirmer), mêmes ${product.length} scénarios : '
        '$sRight justes · **$sWrong faux** · $sRefused refusés.');
    b.writeln();
    if (sWrongList.isNotEmpty) {
      b.writeln('Faux en mode souple :');
      b.writeln();
      b.writeln(sWrongList.toString());
    }
    final softConflicts = lex.conflicts(relaxed: true);
    b.writeln('Mots que le mode souple pourrait confondre (sens différents, orthographe proche) : '
        '**${softConflicts.length}**${softConflicts.isEmpty ? '' : ' — ${softConflicts.take(8).join(' ; ')}'}.');
    b.writeln();

    // Temps de calcul.
    final timed = study.where((s) => s.user != null).map((s) => s.user!).toList();
    final clock = Stopwatch()..start();
    const loops = 200;
    for (var i = 0; i < loops; i++) {
      for (final u in timed) {
        lex.interpret(u);
      }
    }
    clock.stop();
    final perCall = clock.elapsedMicroseconds / (loops * timed.length);
    b.writeln('Temps de calcul : **${perCall.toStringAsFixed(0)} µs** par énoncé en moyenne '
        '(${timed.length} énoncés × $loops, ce poste).');
    b.writeln();

    // ── 3. Sous bruit ─────────────────────────────────────────────────────
    final rnd = math.Random(20261023);
    const levels = [0.0, 0.05, 0.10, 0.15, 0.20, 0.30];
    const trials = 30;
    final lexLangs = study.where((s) => const {'fr', 'en', 'bm', 'bm-mixte', 'bm-ascii'}.contains(s.language)).toList();
    b.writeln('## 3. Sous bruit (dictée ou frappe fautive simulée)');
    b.writeln();
    b.writeln('Chaque énoncé de l\'étude, dans les langues du lexique, abîmé $trials fois à chaque niveau '
        '(part des lettres touchées : substitution, perte ou ajout). Bruit UNIFORME : une vraie dictée '
        'confond des sons voisins, pas des lettres au hasard — ces chiffres bornent mal, ils ne mesurent pas '
        'une dictée réelle.');
    b.writeln();
    b.writeln('| bruit | ordres : compris | ordres : refusés | ordres : MAL compris | non-ordres : activés à tort |');
    b.writeln('|---:|---:|---:|---:|---:|');
    final wrongNoise = <String>[];
    for (final p in levels) {
      var ok = 0, ref = 0, bad = 0, orders = 0, act = 0, non = 0;
      for (final s in lexLangs) {
        for (var t = 0; t < trials; t++) {
          final said = p == 0 ? s.user! : _noisy(s.user!, p, rnd);
          final c = _classify(s, lex.interpret(said));
          if (_isOrder(s)) {
            orders++;
            switch (c) {
              case _O.correct:
                ok++;
              case _O.refused:
                ref++;
              case _O.wrong:
                bad++;
                if (wrongNoise.length < 12) wrongNoise.add('`${s.id}` (bruit ${(p * 100).round()} %) « $said » → ${lex.interpret(said).match}');
            }
          } else {
            non++;
            if (c == _O.wrong) {
              act++;
              if (wrongNoise.length < 12) wrongNoise.add('`${s.id}` (bruit ${(p * 100).round()} %) « $said » → ${lex.interpret(said).match}');
            }
            if (p == 0) break; // sans bruit, un seul essai suffit
          }
          if (p == 0) break;
        }
      }
      b.writeln('| ${(p * 100).round()} % | **${_pct(ok, orders)}** | ${_pct(ref, orders)} | ${_pct(bad, orders)} | ${_pct(act, non)} |');
    }
    b.writeln();
    b.writeln('Cas de « mal compris » sous bruit (12 premiers) :');
    b.writeln();
    b.writeln(wrongNoise.isEmpty ? 'Aucun.' : wrongNoise.map((e) => '- $e').join('\n'));
    b.writeln();

    // ── 3 bis. Sous bruit, avec le mode souple (suggestion à confirmer) ────
    b.writeln('### Avec le mode souple (strict d\'abord ; si le strict refuse, une SUGGESTION à confirmer)');
    b.writeln();
    b.writeln('| bruit | ordres : compris ou suggéré juste | ordres : refusés | ordres : suggestion FAUSSE | non-ordres : suggestion à tort |');
    b.writeln('|---:|---:|---:|---:|---:|');
    final rnd2 = math.Random(20261023);
    final wrongSoft = <String>[];
    for (final p in levels) {
      var ok = 0, ref = 0, bad = 0, orders = 0, act = 0, non = 0;
      for (final s in lexLangs) {
        for (var t = 0; t < trials; t++) {
          final said = p == 0 ? s.user! : _noisy(s.user!, p, rnd2);
          var res = lex.interpret(said);
          if (res.match == null) res = lex.interpret(said, relaxed: true);
          final c = _classify(s, res);
          if (_isOrder(s)) {
            orders++;
            switch (c) {
              case _O.correct:
                ok++;
              case _O.refused:
                ref++;
              case _O.wrong:
                bad++;
                if (wrongSoft.length < 12) wrongSoft.add('`${s.id}` (bruit ${(p * 100).round()} %) « $said » → ${res.match}');
            }
          } else {
            non++;
            if (c == _O.wrong) {
              act++;
              if (wrongSoft.length < 12) wrongSoft.add('`${s.id}` (bruit ${(p * 100).round()} %) « $said » → ${res.match}');
            }
            if (p == 0) break;
          }
          if (p == 0) break;
        }
      }
      b.writeln('| ${(p * 100).round()} % | **${_pct(ok, orders)}** | ${_pct(ref, orders)} | ${_pct(bad, orders)} | ${_pct(act, non)} |');
    }
    b.writeln();
    b.writeln('Suggestions fausses (12 premières) :');
    b.writeln();
    b.writeln(wrongSoft.isEmpty ? 'Aucune.' : wrongSoft.map((e) => '- $e').join('\n'));
    b.writeln();

    Directory('eval_reports').createSync(recursive: true);
    final stamp = date.replaceAll(RegExp(r'[:T]'), '-');
    final path = 'eval_reports/${stamp}_lexique.md';
    File(path).writeAsStringSync(b.toString(), encoding: utf8);
    // ignore: avoid_print
    print(b.toString());
    // ignore: avoid_print
    print('Rapport : $path');
  });
}
