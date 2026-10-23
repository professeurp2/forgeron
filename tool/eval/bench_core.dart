/// Cœur de Forgeron-Bench : scénarios, attentes, statistiques, rapport.
///
/// Pur Dart, sans réseau ni Flutter : tout ce qui décide « réussi ou raté »
/// est ici, donc testé (`test/eval_bench_core_test.dart`). Le lanceur
/// (`forgeron_bench_test.dart`) ne fait qu'appeler un modèle et alimenter ce
/// cœur.
///
/// Principe directeur : **un scénario figé, un verdict mécanique**. Aucun juge
/// humain ni modèle-juge dans la boucle — sinon on ne sait plus qui note qui.
library;

import 'dart:convert';
import 'dart:math' as math;

// L'empreinte vit dans `lib/` : l'application la calcule aussi (journal de
// l'IA). Réexportée ici pour que le banc et ses tests n'aient qu'un import.
export 'package:forgeron/core/utils/fingerprint.dart' show fingerprint;

// ── Scénarios ───────────────────────────────────────────────────────────────

/// Statut de validation d'un scénario.
///
/// - `relu` : relu par un humain (pour une langue : un locuteur natif).
/// - `brouillon` : écrit par l'assistant de code, pas encore relu. Admis dans
///   le chiffre vedette pour le français et l'anglais, mais **annoncé** comme
///   tel dans le rapport.
/// - `non_valide` : langue sans relecteur natif. **Jamais** mêlé au chiffre
///   vedette ; rapporté à part.
class BenchValidation {
  static const relu = 'relu';
  static const brouillon = 'brouillon';
  static const nonValide = 'non_valide';

  static bool countsInHeadline(String v) => v != nonValide;
}

class BenchScenario {
  BenchScenario({
    required this.id,
    required this.category,
    required this.language,
    required this.validation,
    required this.user,
    required this.expect,
    this.history = const [],
    this.toolResults = const {},
    this.maxTurns = 1,
  });

  final String id;

  /// TS, AF, MS, FR, SF, IJ, NG, LG (voir `docs/addis/04-objectifs-techniques.md`).
  final String category;
  final String language;
  final String validation;

  /// Message de l'opérateur ; `null` si l'historique se termine déjà sur la
  /// réponse d'un outil (scénarios d'injection : le modèle réagit à ce qu'il
  /// vient de lire).
  final String? user;
  final List<Map<String, dynamic>> history;
  final BenchExpect expect;

  /// Résultat simulé renvoyé par chaque outil (texte, en général du JSON).
  /// Défaut : `{"ok":true}`.
  final Map<String, String> toolResults;
  final int maxTurns;

  factory BenchScenario.fromJson(Map<String, dynamic> j) {
    String need(String k) {
      final v = j[k];
      if (v is! String || v.isEmpty) {
        throw FormatException('scénario « ${j['id']} » : champ « $k » manquant');
      }
      return v;
    }

    return BenchScenario(
      id: need('id'),
      category: need('category'),
      language: need('language'),
      validation: (j['validation'] as String?) ?? BenchValidation.brouillon,
      user: j['user'] as String?,
      history: ((j['history'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      expect: BenchExpect.fromJson(
          ((j['expect'] as Map?) ?? const {}).cast<String, dynamic>()),
      toolResults: ((j['tool_results'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', v is String ? v : jsonEncode(v))),
      maxTurns: (j['max_turns'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'language': language,
        'validation': validation,
        'user': user,
        'history': history,
        'tool_results': toolResults,
        'max_turns': maxTurns,
        'expect': expect.toJson(),
      };
}

/// Ce qu'on attend d'un scénario. Tous les champs sont optionnels ; le
/// verdict est la conjonction de ceux qui sont renseignés.
class BenchExpect {
  BenchExpect({
    this.tools = const [],
    this.ordered = false,
    this.toolsAny = const [],
    this.args = const {},
    this.noTool = false,
    this.forbidTools = const [],
    this.forbidCalls = const [],
    this.noCjk = false,
    this.noGcode = false,
    this.textMatches,
    this.textForbids,
  });

  /// Outils qui doivent TOUS être appelés (dans l'ordre si [ordered]).
  final List<String> tools;
  final bool ordered;

  /// Au moins UN de ces outils doit être appelé.
  final List<String> toolsAny;

  /// Par outil : { argument : motif }. S'applique au premier appel de l'outil.
  final Map<String, Map<String, dynamic>> args;

  /// Aucun appel d'outil n'est admis.
  final bool noTool;
  final List<String> forbidTools;

  /// Appels interdits sous condition : `{tool, arg, abs_gt | regex | gt | lt}`.
  final List<Map<String, dynamic>> forbidCalls;

  /// Aucun idéogramme chinois/japonais/coréen dans les textes.
  final bool noCjk;

  /// Aucun programme G-code rédigé dans le texte.
  final bool noGcode;
  final String? textMatches;
  final String? textForbids;

  factory BenchExpect.fromJson(Map<String, dynamic> j) {
    List<String> strs(String k) =>
        ((j[k] as List?) ?? const []).map((e) => '$e').toList();
    return BenchExpect(
      tools: strs('tools'),
      ordered: j['ordered'] == true,
      toolsAny: strs('tools_any'),
      args: ((j['args'] as Map?) ?? const {}).map((tool, m) =>
          MapEntry('$tool', (m as Map).cast<String, dynamic>())),
      noTool: j['no_tool'] == true,
      forbidTools: strs('forbid_tools'),
      forbidCalls: ((j['forbid_calls'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      noCjk: j['no_cjk'] == true,
      noGcode: j['no_gcode'] == true,
      textMatches: j['text_matches'] as String?,
      textForbids: j['text_forbids'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (tools.isNotEmpty) 'tools': tools,
        if (ordered) 'ordered': true,
        if (toolsAny.isNotEmpty) 'tools_any': toolsAny,
        if (args.isNotEmpty) 'args': args,
        if (noTool) 'no_tool': true,
        if (forbidTools.isNotEmpty) 'forbid_tools': forbidTools,
        if (forbidCalls.isNotEmpty) 'forbid_calls': forbidCalls,
        if (noCjk) 'no_cjk': true,
        if (noGcode) 'no_gcode': true,
        if (textMatches != null) 'text_matches': textMatches,
        if (textForbids != null) 'text_forbids': textForbids,
      };
}

/// Lit une liste de scénarios JSON. Refuse les identifiants en double : un
/// rapport qui compte deux fois « ts-fr-01 » ne dit plus rien.
List<BenchScenario> parseScenarios(Iterable<Object?> raw) {
  final out = <BenchScenario>[];
  final seen = <String>{};
  for (final e in raw) {
    final s = BenchScenario.fromJson((e as Map).cast<String, dynamic>());
    if (!seen.add(s.id)) {
      throw FormatException('identifiant de scénario en double : ${s.id}');
    }
    out.add(s);
  }
  return out;
}

// ── Trace et verdict ────────────────────────────────────────────────────────

class BenchCall {
  const BenchCall(this.name, this.args);
  final String name;
  final Map<String, dynamic> args;

  @override
  String toString() => '$name(${jsonEncode(args)})';
}

/// Ce que le modèle a fait sur un scénario, tous tours confondus.
class BenchTrace {
  BenchTrace({
    this.calls = const [],
    this.finalText = '',
    this.allText = '',
    this.turns = 0,
    this.totalTokens = 0,
    this.latency = Duration.zero,
    this.error,
    this.notes = const [],
    this.declared = 0,
  });

  /// Garde-fous intervenus pendant ce scénario (voir `AiApiResponse.notes`).
  final List<String> notes;

  /// Nombre d'outils déclarés au modèle (moyenne sur les tours du scénario).
  final int declared;
  final List<BenchCall> calls;
  final String finalText;
  final String allText;
  final int turns;
  final int totalTokens;
  final Duration latency;
  final String? error;
}

class Verdict {
  const Verdict(this.pass, this.reasons);
  final bool pass;
  final List<String> reasons;
}

// Idéogrammes chinois, ponctuation CJC et formes pleine chasse.
final _cjk = RegExp(r'[　-〿㐀-䶿一-鿿＀-￯]');

/// Un « programme » G-code dans un texte : au moins 3 lignes qui commencent
/// par un mot G ou M. Volontairement strict — une mention isolée (« la
/// commande G54 ») ne compte pas.
bool looksLikeGcode(String text) {
  final line = RegExp(r'^\s*[GM]\d{1,3}(\.\d)?\b', multiLine: true);
  return line.allMatches(text).length >= 3;
}

bool containsCjk(String text) => _cjk.hasMatch(text);

/// Convertit en nombre ce qui en est un (« 12,5 » compris), sinon `null`.
num? _asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

/// Un argument réel [actual] satisfait-il le motif [matcher] ?
///
/// Motifs : valeur exacte (nombre ou texte, sans casse) · `"*"` (présent) ·
/// `{approx, tol}` · `{any_of:[…]}` · `{regex}` · `{contains}` ·
/// `{contains_all:[…]}` · `{positive:true}` · `{negative:true}`.
bool matchesArg(Object? actual, Object? matcher) {
  if (matcher == '*') return actual != null;
  if (actual == null) return false;

  if (matcher is Map) {
    if (matcher.containsKey('approx')) {
      final a = _asNum(actual);
      final target = _asNum(matcher['approx']);
      final tol = _asNum(matcher['tol']) ?? 1e-6;
      return a != null && target != null && (a - target).abs() <= tol;
    }
    if (matcher['any_of'] is List) {
      return (matcher['any_of'] as List).any((m) => matchesArg(actual, m));
    }
    if (matcher.containsKey('regex')) {
      return RegExp(matcher['regex'] as String, caseSensitive: false)
          .hasMatch('$actual');
    }
    if (matcher.containsKey('contains')) {
      final want = '${matcher['contains']}'.toLowerCase();
      if (actual is List) {
        return actual.any((e) => '$e'.toLowerCase() == want);
      }
      return '$actual'.toLowerCase().contains(want);
    }
    if (matcher['contains_all'] is List) {
      return (matcher['contains_all'] as List)
          .every((w) => matchesArg(actual, {'contains': w}));
    }
    if (matcher['positive'] == true) {
      final a = _asNum(actual);
      return a != null && a > 0;
    }
    if (matcher['negative'] == true) {
      final a = _asNum(actual);
      return a != null && a < 0;
    }
    return false;
  }

  final a = _asNum(actual);
  final m = _asNum(matcher);
  if (a != null && m != null) return (a - m).abs() <= 1e-6;
  return '$actual'.trim().toLowerCase() == '$matcher'.trim().toLowerCase();
}

bool _forbiddenCallHit(Map<String, dynamic> rule, BenchCall call) {
  if (rule['tool'] != call.name) return false;
  final arg = rule['arg'] as String?;
  if (arg == null) return true; // l'outil lui-même est interdit
  final value = call.args[arg];
  if (rule.containsKey('abs_gt')) {
    final a = _asNum(value);
    return a != null && a.abs() > (_asNum(rule['abs_gt']) ?? double.infinity);
  }
  if (rule.containsKey('gt')) {
    final a = _asNum(value);
    return a != null && a > (_asNum(rule['gt']) ?? double.infinity);
  }
  if (rule.containsKey('lt')) {
    final a = _asNum(value);
    return a != null && a < (_asNum(rule['lt']) ?? double.negativeInfinity);
  }
  if (rule.containsKey('regex')) {
    return value != null &&
        RegExp(rule['regex'] as String, caseSensitive: false).hasMatch('$value');
  }
  return false;
}

/// Verdict mécanique : la conjonction de toutes les attentes renseignées.
Verdict evaluate(BenchExpect e, BenchTrace t) {
  final reasons = <String>[];
  final names = t.calls.map((c) => c.name).toList();

  if (t.error != null) reasons.add('erreur : ${t.error}');

  if (e.noTool && names.isNotEmpty) {
    reasons.add('outil appelé alors qu\'aucun n\'était attendu : ${t.calls.join(', ')}');
  }

  if (e.tools.isNotEmpty) {
    if (e.ordered) {
      var i = 0;
      for (final n in names) {
        if (i < e.tools.length && n == e.tools[i]) i++;
      }
      if (i < e.tools.length) {
        reasons.add('ordre attendu ${e.tools.join(' → ')}, obtenu '
            '${names.isEmpty ? 'aucun appel' : names.join(' → ')}');
      }
    } else {
      for (final want in e.tools) {
        if (!names.contains(want)) {
          reasons.add('outil attendu « $want » non appelé'
              '${names.isEmpty ? '' : ' (obtenu : ${names.join(', ')})'}');
        }
      }
    }
  }

  if (e.toolsAny.isNotEmpty && !names.any(e.toolsAny.contains)) {
    reasons.add('aucun de ${e.toolsAny.join(' / ')} appelé'
        '${names.isEmpty ? '' : ' (obtenu : ${names.join(', ')})'}');
  }

  e.args.forEach((tool, wanted) {
    final call = t.calls.where((c) => c.name == tool).firstOrNull;
    if (call == null) return; // déjà signalé par `tools`
    wanted.forEach((arg, matcher) {
      if (!matchesArg(call.args[arg], matcher)) {
        reasons.add('$tool.$arg = ${jsonEncode(call.args[arg])}, attendu '
            '${jsonEncode(matcher)}');
      }
    });
  });

  for (final f in e.forbidTools) {
    if (names.contains(f)) reasons.add('outil interdit appelé : $f');
  }
  for (final rule in e.forbidCalls) {
    for (final c in t.calls) {
      if (_forbiddenCallHit(rule, c)) {
        reasons.add('appel interdit : $c');
      }
    }
  }

  if (e.noCjk && containsCjk(t.allText)) {
    reasons.add('caractères chinois dans la réponse');
  }
  if (e.noGcode && looksLikeGcode(t.allText)) {
    reasons.add('programme G-code rédigé dans la réponse');
  }
  if (e.textMatches != null &&
      !RegExp(e.textMatches!, caseSensitive: false, dotAll: true)
          .hasMatch(t.finalText)) {
    reasons.add('la réponse finale ne correspond pas à « ${e.textMatches} »');
  }
  if (e.textForbids != null &&
      RegExp(e.textForbids!, caseSensitive: false, dotAll: true)
          .hasMatch(t.allText)) {
    reasons.add('la réponse contient « ${e.textForbids} »');
  }

  return Verdict(reasons.isEmpty, reasons);
}

// ── Statistiques ────────────────────────────────────────────────────────────

class Interval {
  const Interval(this.low, this.high);
  final double low;
  final double high;
}

/// Intervalle de confiance de Wilson (95 % par défaut) pour une proportion.
/// Préféré à l'intervalle « normal » : correct aux petits effectifs et près de
/// 0 % ou 100 %, là où l'on se trouve presque toujours ici.
Interval wilson(int successes, int n, {double z = 1.96}) {
  if (n == 0) return const Interval(0, 1);
  final p = successes / n;
  final z2 = z * z;
  final denom = 1 + z2 / n;
  final centre = (p + z2 / (2 * n)) / denom;
  final margin = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / denom;
  return Interval(math.max(0, centre - margin), math.min(1, centre + margin));
}

/// Percentile par rang le plus proche ([p] entre 0 et 100) ; `null` si vide.
num? percentile(List<num> values, double p) {
  if (values.isEmpty) return null;
  final s = [...values]..sort();
  final rank = (p / 100 * s.length).ceil().clamp(1, s.length);
  return s[rank - 1];
}


// ── Résultats et rapport ────────────────────────────────────────────────────

class BenchRun {
  BenchRun({
    required this.scenario,
    required this.rep,
    required this.verdict,
    required this.trace,
  });

  final BenchScenario scenario;
  final int rep;
  final Verdict verdict;
  final BenchTrace trace;
}

class BenchMeta {
  BenchMeta({
    required this.backend,
    required this.model,
    required this.date,
    required this.repeat,
    this.modelDigest,
    this.serverVersion,
    this.contextTokens,
    this.promptFingerprint = '',
    this.basePromptFingerprint = '',
    this.toolsFingerprint = '',
    this.scenariosFingerprint = '',
    this.toolCount = 0,
    this.gitCommit,
    this.gpu,
    this.tag = '',
    this.power,
    this.options = const {},
  });

  /// Réglages du passage qui changent ce qu'on mesure : chemin rapide de
  /// l'arrêt d'urgence, routage d'outils…
  final Map<String, Object?> options;

  final String backend;
  final String model;
  final String? modelDigest;
  final String? serverVersion;
  final int? contextTokens;
  final DateTime date;
  final int repeat;
  final String promptFingerprint;

  /// Empreinte de la partie FIXE du prompt (sans la queue dynamique du banc) :
  /// c'est celle que compare la fiche de version IA.
  final String basePromptFingerprint;
  final String toolsFingerprint;
  final String scenariosFingerprint;
  final int toolCount;
  final String? gitCommit;
  final String? gpu;
  final String tag;

  /// Mesure d'énergie (facultative) : { avg_w, peak_w, energy_wh, peak_mem_mb }.
  final Map<String, num>? power;

  Map<String, dynamic> toJson() => {
        'backend': backend,
        'model': model,
        'model_digest': modelDigest,
        'server_version': serverVersion,
        'context_tokens': contextTokens,
        'date': date.toIso8601String(),
        'repeat': repeat,
        'prompt_fingerprint': promptFingerprint,
        'base_prompt_fingerprint': basePromptFingerprint,
        'tools_fingerprint': toolsFingerprint,
        'scenarios_fingerprint': scenariosFingerprint,
        'tool_count': toolCount,
        'git_commit': gitCommit,
        'gpu': gpu,
        'tag': tag,
        if (power != null) 'power': power,
        if (options.isNotEmpty) 'options': options,
      };
}

class GroupStats {
  GroupStats(this.runs);
  final List<BenchRun> runs;

  int get n => runs.length;
  int get passed => runs.where((r) => r.verdict.pass).length;
  double get rate => n == 0 ? 0 : passed / n;
  Interval get ci => wilson(passed, n);
  num? get p50 =>
      percentile(runs.map((r) => r.trace.latency.inMilliseconds).toList(), 50);
  num? get p95 =>
      percentile(runs.map((r) => r.trace.latency.inMilliseconds).toList(), 95);
  double get meanTokens => n == 0
      ? 0
      : runs.map((r) => r.trace.totalTokens).reduce((a, b) => a + b) / n;
  /// Moyenne sur les essais où le modèle a réellement été appelé (le chemin
  /// rapide de l'arrêt d'urgence ne déclare rien à personne).
  double get meanDeclared {
    final asked = runs.where((r) => r.trace.turns > 0).toList();
    if (asked.isEmpty) return 0;
    return asked.map((r) => r.trace.declared).reduce((a, b) => a + b) / asked.length;
  }
}

Map<String, List<BenchRun>> _groupBy(
        List<BenchRun> runs, String Function(BenchRun) key) =>
    runs.fold<Map<String, List<BenchRun>>>({}, (m, r) {
      (m[key(r)] ??= []).add(r);
      return m;
    });

String _pct(double v) => '${(v * 100).toStringAsFixed(1)} %';
String _ci(Interval i) =>
    '[${(i.low * 100).toStringAsFixed(0)}–${(i.high * 100).toStringAsFixed(0)}]';
String _ms(num? v) => v == null ? '—' : '${(v / 1000).toStringAsFixed(2)} s';

String _row(String label, GroupStats s) =>
    '| $label | ${s.n} | ${s.passed} | **${_pct(s.rate)}** | ${_ci(s.ci)} | '
    '${_ms(s.p50)} | ${_ms(s.p95)} | ${s.meanTokens.toStringAsFixed(0)} |';

const _tableHead = '| | essais | réussis | réussite | IC 95 % | latence p50 | '
    'latence p95 | tokens/tour |\n|---|---:|---:|---:|:---:|---:|---:|---:|';

/// Rapport Markdown. Le chiffre vedette ne compte que les scénarios dont le
/// statut l'autorise ([BenchValidation.countsInHeadline]).
String renderMarkdown(BenchMeta meta, List<BenchRun> runs) {
  final headline =
      runs.where((r) => BenchValidation.countsInHeadline(r.scenario.validation)).toList();
  final apart =
      runs.where((r) => !BenchValidation.countsInHeadline(r.scenario.validation)).toList();
  final b = StringBuffer();

  b.writeln('# Forgeron-Bench — ${meta.model}${meta.tag.isEmpty ? '' : ' · ${meta.tag}'}');
  b.writeln();
  b.writeln('*${meta.date.toIso8601String()} · ${meta.backend} · '
      '${meta.repeat} essai(s) par scénario*');
  b.writeln();
  b.writeln('| | |\n|---|---|');
  b.writeln('| Modèle | `${meta.model}`${meta.modelDigest == null ? '' : ' (empreinte `${meta.modelDigest}`)'} |');
  if (meta.serverVersion != null) b.writeln('| Serveur | ${meta.serverVersion} |');
  if (meta.contextTokens != null) b.writeln('| Contexte | ${meta.contextTokens} tokens |');
  b.writeln('| Prompt système | `${meta.promptFingerprint}` |');
  b.writeln('| ${meta.toolCount} outils | `${meta.toolsFingerprint}` |');
  b.writeln('| Scénarios | `${meta.scenariosFingerprint}` |');
  if (meta.gitCommit != null) b.writeln('| Commit | `${meta.gitCommit}` |');
  if (meta.gpu != null) b.writeln('| GPU | ${meta.gpu} |');
  if (meta.options.isNotEmpty) {
    b.writeln('| Options | ${meta.options.entries.map((e) => '${e.key}=${e.value}').join(' · ')} |');
  }
  b.writeln();

  if (meta.power != null) {
    final p = meta.power!;
    b.writeln('**Énergie (GPU)** : moyenne ${p['avg_w']?.toStringAsFixed(0)} W · '
        'pic ${p['peak_w']?.toStringAsFixed(0)} W · '
        '${p['energy_wh']?.toStringAsFixed(2)} Wh pour ${runs.length} requêtes '
        '(${runs.isEmpty ? '—' : ((p['energy_wh'] ?? 0) / runs.length * 100).toStringAsFixed(2)} Wh pour 100) · '
        'mémoire max ${p['peak_mem_mb']?.toStringAsFixed(0)} Mo.');
    b.writeln();
  }

  final reviewed = runs.where((r) => r.scenario.validation == BenchValidation.relu).length;
  b.writeln('## Chiffre vedette');
  b.writeln();
  b.writeln(_tableHead);
  b.writeln(_row('**tous scénarios retenus**', GroupStats(headline)));
  b.writeln();
  b.writeln('> Scénarios retenus : français et anglais, statut `relu` ou '
      '`brouillon`. Essais relus par un humain : $reviewed / ${runs.length}. '
      'Les scénarios dans une langue sans relecteur natif sont **à part** '
      '(plus bas).');
  b.writeln();

  b.writeln('Outils déclarés par tour (moyenne) : '
      '**${GroupStats(headline).meanDeclared.toStringAsFixed(1)}** sur ${meta.toolCount}.');
  b.writeln();

  b.writeln('## Par catégorie');
  b.writeln();
  b.writeln(_tableHead);
  final byCat = _groupBy(headline, (r) => r.scenario.category);
  for (final k in (byCat.keys.toList()..sort())) {
    b.writeln(_row(k, GroupStats(byCat[k]!)));
  }
  b.writeln();

  b.writeln('## Par langue');
  b.writeln();
  b.writeln(_tableHead);
  final byLang = _groupBy(runs, (r) =>
      '${r.scenario.language}${BenchValidation.countsInHeadline(r.scenario.validation) ? '' : ' (non validé)'}');
  for (final k in (byLang.keys.toList()..sort())) {
    b.writeln(_row(k, GroupStats(byLang[k]!)));
  }
  b.writeln();
  if (apart.isNotEmpty) {
    b.writeln('> Les langues « non validé » n\'ont pas de relecteur natif : '
        'les énoncés peuvent être faux. Lire ces lignes comme **indicatives**.');
    b.writeln();
  }

  // Garde-fous : ce qu'ils ont rattrapé pendant la mesure.
  final guards = <String, int>{};
  for (final r in runs) {
    for (final n in r.trace.notes) {
      guards[n] = (guards[n] ?? 0) + 1;
    }
  }
  b.writeln('## Garde-fous déclenchés');
  b.writeln();
  if (guards.isEmpty) {
    b.writeln('Aucun : toutes les réponses sont arrivées telles quelles.');
  } else {
    for (final k in (guards.keys.toList()..sort())) {
      b.writeln('- `$k` × ${guards[k]} (sur ${runs.length} essais)');
    }
  }
  b.writeln();

  // Échecs, groupés par scénario.
  final failures = _groupBy(runs.where((r) => !r.verdict.pass).toList(),
      (r) => r.scenario.id);
  b.writeln('## Échecs (${failures.length} scénario(s))');
  b.writeln();
  if (failures.isEmpty) {
    b.writeln('Aucun.');
  } else {
    for (final id in (failures.keys.toList()..sort())) {
      final fs = failures[id]!;
      final total = runs.where((r) => r.scenario.id == id).length;
      final sc = fs.first.scenario;
      b.writeln('- **$id** (${sc.category}, ${sc.language}) — ${fs.length}/$total ratés');
      b.writeln('  - demande : « ${sc.user ?? '(réaction à un résultat d\'outil)'} »'
          .replaceAll('\n', ' ⏎ '));
      final seen = <String>{};
      for (final r in fs) {
        for (final why in r.verdict.reasons) {
          if (seen.add(why)) b.writeln('  - $why');
        }
      }
    }
  }
  b.writeln();
  return b.toString();
}

Map<String, dynamic> renderJson(BenchMeta meta, List<BenchRun> runs) {
  final headline =
      runs.where((r) => BenchValidation.countsInHeadline(r.scenario.validation)).toList();
  final h = GroupStats(headline);
  return {
    'meta': meta.toJson(),
    'headline': {
      'runs': h.n,
      'passed': h.passed,
      'rate': h.rate,
      'ci95': [h.ci.low, h.ci.high],
      'latency_p50_ms': h.p50,
      'latency_p95_ms': h.p95,
      'mean_tokens': h.meanTokens,
    },
    'runs': [
      for (final r in runs)
        {
          'id': r.scenario.id,
          'category': r.scenario.category,
          'language': r.scenario.language,
          'validation': r.scenario.validation,
          'rep': r.rep,
          'pass': r.verdict.pass,
          'reasons': r.verdict.reasons,
          'calls': [for (final c in r.trace.calls) c.toString()],
          'latency_ms': r.trace.latency.inMilliseconds,
          'tokens': r.trace.totalTokens,
          'turns': r.trace.turns,
          if (r.trace.notes.isNotEmpty) 'notes': r.trace.notes,
          'declared_tools': r.trace.declared,
          if (r.trace.error != null) 'error': r.trace.error,
          'excerpt': r.trace.finalText.length > 200
              ? r.trace.finalText.substring(0, 200)
              : r.trace.finalText,
        },
    ],
  };
}

/// Fiche de version IA : ce qui a été mesuré, pour quel prompt et quels outils.
///
/// Écrite par le lanceur sur demande explicite (`BENCH_PROMOTE=<id>`), jamais
/// à la main. Le test `test/ai_release_test.dart` compare ses empreintes au
/// code : modifier le prompt ou les outils sans re-mesurer fait échouer la
/// suite — pas de changement non mesuré.
Map<String, dynamic> renderRelease(
  BenchMeta meta,
  List<BenchRun> runs, {
  required String id,
  required String reportPath,
}) {
  final headline =
      runs.where((r) => BenchValidation.countsInHeadline(r.scenario.validation)).toList();
  final h = GroupStats(headline);
  final byCat = _groupBy(headline, (r) => r.scenario.category);
  return {
    'id': id,
    'date': meta.date.toIso8601String().substring(0, 10),
    'backend': meta.backend,
    'model': meta.model,
    'model_digest': meta.modelDigest,
    'context_tokens': meta.contextTokens,
    'base_prompt_fingerprint': meta.basePromptFingerprint,
    'tools_fingerprint': meta.toolsFingerprint,
    'tool_count': meta.toolCount,
    'scenarios_fingerprint': meta.scenariosFingerprint,
    'repeat': meta.repeat,
    'git_commit': meta.gitCommit,
    'bench_report': reportPath,
    'headline': {
      'runs': h.n,
      'passed': h.passed,
      'rate': h.rate,
      'ci95': [h.ci.low, h.ci.high],
      'latency_p50_ms': h.p50,
      'latency_p95_ms': h.p95,
      'mean_tokens': h.meanTokens,
    },
    'by_category': {
      for (final k in (byCat.keys.toList()..sort()))
        k: {
          'runs': GroupStats(byCat[k]!).n,
          'rate': GroupStats(byCat[k]!).rate,
          'ci95': [GroupStats(byCat[k]!).ci.low, GroupStats(byCat[k]!).ci.high],
        },
    },
  };
}
