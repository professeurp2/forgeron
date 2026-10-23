// Forgeron-Bench — lanceur.
//
//   flutter test tool/eval/forgeron_bench_test.dart --reporter expanded
//
// Rejoue les scénarios de `tool/eval/scenarios/` contre un VRAI modèle, avec le
// prompt système et les 38 outils réels de l'agent, et écrit un rapport daté
// dans `eval_reports/`. Voir `tool/eval/README.md` pour les variables.
//
// Se SAUTE seul quand aucun serveur ne répond : la suite reste verte sur un
// poste sans Ollama.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart'
    show AiAgentController;
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/ai_agent_tools.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/application/services/tool_router.dart';
import 'package:forgeron/application/services/command_understanding.dart' show isReadOnlyToolName;
import 'package:forgeron/core/utils/command_lexicon.dart';
import 'package:forgeron/core/utils/emergency_intent.dart';
import 'package:http/http.dart' as http;

import 'bench_core.dart';

/// Ce que `AiAgentController._buildSystemPrompt` ajoute à la partie fixe, en
/// taille représentative : cinématique, directive de langue, journal.
const _dynamicTail = '''
Cinématique réelle (lue dans la config FluidNC de la machine) :
- X : course 80 mm, 264 pas/mm, F max 1000 mm/min, accél. 100 mm/s²
- Y : course 150 mm, 400 pas/mm, F max 1000 mm/min, accél. 100 mm/s²
- Z : course 110 mm, 400 pas/mm, F max 800 mm/min, accél. 80 mm/s²
- A : course 360 °, 16.667 pas/°, F max 2000 °/min, accél. 50 °/s²
- C : course 360 °, 16.667 pas/°, F max 2000 °/min, accél. 50 °/s²

Réponds en français.

=== JOURNAL D'ACTIVITÉ MACHINE (récent, opérateur + toi) ===
12:10:00 opérateur : jog X+1.0 (F300)
12:10:05 opérateur : jog X+1.0 (F300)
12:10:09 opérateur : jog Y+1.0 (F300)''';

/// Échantillonne la puissance et la mémoire du GPU pendant le banc
/// (`nvidia-smi`), pour chiffrer l'énergie par requête — objectif 5.
class _PowerSampler {
  final _watts = <double>[];
  final _memMb = <double>[];
  final _clock = Stopwatch();
  Timer? _timer;
  bool _busy = false;

  Future<bool> start() async {
    if (!await _sample()) return false;
    _clock.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
    return true;
  }

  Future<bool> _sample() async {
    if (_busy) return true;
    _busy = true;
    try {
      final r = await Process.run('nvidia-smi', [
        '--query-gpu=power.draw,memory.used',
        '--format=csv,noheader,nounits',
      ]);
      if (r.exitCode != 0) return false;
      final parts = '${r.stdout}'.trim().split(',');
      final w = double.tryParse(parts[0].trim());
      final m = double.tryParse(parts.length > 1 ? parts[1].trim() : '');
      if (w == null) return false;
      _watts.add(w);
      if (m != null) _memMb.add(m);
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  Map<String, num>? stop() {
    _timer?.cancel();
    _clock.stop();
    if (_watts.isEmpty) return null;
    final avg = _watts.reduce((a, b) => a + b) / _watts.length;
    final peak = _watts.reduce((a, b) => a > b ? a : b);
    return {
      'avg_w': avg,
      'peak_w': peak,
      'energy_wh': avg * _clock.elapsed.inMilliseconds / 3600000,
      'peak_mem_mb': _memMb.isEmpty ? 0 : _memMb.reduce((a, b) => a > b ? a : b),
    };
  }
}

Future<String?> _run(String cmd, List<String> args) async {
  try {
    final r = await Process.run(cmd, args);
    if (r.exitCode != 0) return null;
    final out = '${r.stdout}'.trim();
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

List<BenchScenario> _loadScenarios(String path) {
  final dir = Directory(path);
  final files = dir
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

bool _selected(BenchScenario s, String? filter) {
  if (filter == null || filter.trim().isEmpty) return true;
  return filter.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).any(
      (t) =>
          s.category.toLowerCase() == t.toLowerCase() ||
          s.id.startsWith(t) ||
          t == 'lang:${s.language}' ||
          t == 'validation:${s.validation}');
}

void main() {
  final env = Platform.environment;
  final backendKind = (env['BENCH_BACKEND'] ?? 'local').toLowerCase();
  final url = LocalAiAgentService.normalizeBaseUrl(
      env['BENCH_URL'] ?? 'http://localhost:11434');
  final model = env['BENCH_MODEL'] ??
      (backendKind == 'gemini' ? 'gemini-flash-lite-latest' : 'forgeron-qwen');
  final repeat = int.tryParse(env['BENCH_REPEAT'] ?? '') ?? 3;
  final filter = env['BENCH_FILTER'];
  // Dossier des scénarios : celui du produit par défaut ; l'étude des langues
  // locales a le sien (`tool/eval/scenarios_langues`), pour ne pas changer
  // l'empreinte des scénarios sur lesquels les versions IA sont comparées.
  final scenariosDir = env['BENCH_SCENARIOS'] ?? 'tool/eval/scenarios';
  final outDir = env['BENCH_OUT'] ?? 'eval_reports';
  final tag = env['BENCH_TAG'] ?? '';
  final measurePower = env['BENCH_POWER'] == '1';
  // Chemin rapide de l'arrêt d'urgence (celui de l'application) : activé par
  // défaut, car on mesure le PRODUIT. `BENCH_FASTPATH=0` mesure le modèle seul.
  final fastPath = env['BENCH_FASTPATH'] != '0';
  final promoteId = env['BENCH_PROMOTE'];
  // Routage d'outils (expérience E1) : n'exposer au modèle que les outils
  // utiles au message. Désactivé par défaut ; adopté seulement si le banc le
  // justifie.
  final routing = env['BENCH_ROUTING'] == '1';
  // Frontal à lexique fermé (étude des langues locales) : un énoncé que le
  // lexique comprend sans réserve est exécuté SANS le modèle ; sinon le modèle
  // prend le relais. `BENCH_FRONT=lexique`. Désactivé par défaut.
  // Garde par refus (`BENCH_GATE=1`, avec le frontal) : quand le lexique refuse
  // parce que l'énoncé est une QUESTION ou une NÉGATION, le modèle ne reçoit que
  // les outils de lecture pour ce tour — il ne peut plus lancer le homing en
  // réponse à « c'est quoi le homing ? ».
  final gate = env['BENCH_GATE'] == '1';
  // Suffixe ajouté à la fin du prompt système — ex. `/no_think` pour Qwen3, qui
  // « réfléchit » par défaut (latence incompatible avec un opérateur devant sa
  // machine). Il est dans l'empreinte du prompt et dans les options du rapport.
  final systemSuffix = env['BENCH_SYSTEM_SUFFIX'];
  // Pivot de traduction (route B) : { id de scénario : { traduction } }, produit
  // par `tool/eval/lang/pivot_translate.py`. Le modèle reçoit la traduction
  // française à la place de l'énoncé d'origine.
  final Map<String, dynamic>? pivot = env['BENCH_PIVOT'] == null
      ? null
      : (jsonDecode(File(env['BENCH_PIVOT']!).readAsStringSync(encoding: utf8))
              as Map)
          .cast<String, dynamic>();
  final CommandLexicon? lexicon = env['BENCH_FRONT'] == 'lexique'
      ? CommandLexicon.fromJson(jsonDecode(
              File('assets/lexicon/lexique.json').readAsStringSync(encoding: utf8))
          as Map<String, dynamic>)
      : null;

  test('Forgeron-Bench', () async {
    // ── Serveur joignable ? ────────────────────────────────────────────────
    String? serverVersion;
    String? digest;
    LocalModelInfo? info;
    if (backendKind == 'local') {
      try {
        final tags = await http
            .get(Uri.parse('$url/api/tags'))
            .timeout(const Duration(seconds: 3));
        if (tags.statusCode != 200 || !tags.body.contains('"$model')) {
          markTestSkipped('Aucun serveur local ne sert « $model » sur $url.');
          return;
        }
        for (final m in ((jsonDecode(tags.body)['models'] as List?) ?? const [])) {
          final name = '${(m as Map)['name']}';
          if (name == model || name == '$model:latest') digest = '${m['digest']}'.substring(0, 12);
        }
        final v = await http
            .get(Uri.parse('$url/api/version'))
            .timeout(const Duration(seconds: 3));
        if (v.statusCode == 200) {
          serverVersion = 'Ollama ${jsonDecode(v.body)['version']}';
        }
      } catch (_) {
        markTestSkipped('Aucun serveur local ne répond sur $url.');
        return;
      }
      info = await LocalAiAgentService.probe(url, model);
    } else if (env['GEMINI_API_KEY'] == null) {
      markTestSkipped('BENCH_BACKEND=gemini demande GEMINI_API_KEY.');
      return;
    }

    final AiBackend service = backendKind == 'gemini'
        ? AiAgentService(apiKey: env['GEMINI_API_KEY']!, model: model)
        : LocalAiAgentService(baseUrl: url, model: model, info: info!);

    // ── Ce qu'on mesure : prompt, outils, scénarios ────────────────────────
    final declarations = AiToolCatalog.tools
        .map((t) => t.toGeminiFunctionDeclaration())
        .toList();
    // `baseSystemPrompt` est exposé « pour les tests » : ce banc en est un —
    // il mesure le prompt RÉEL, pas une copie qui dériverait.
    // ignore: invalid_use_of_visible_for_testing_member
    final defaultPrompt = AiAgentController.baseSystemPrompt;
    final basePrompt = env['BENCH_PROMPT_FILE'] != null
        ? File(env['BENCH_PROMPT_FILE']!).readAsStringSync(encoding: utf8)
        : defaultPrompt;
    final systemPrompt =
        '$basePrompt\n\n$_dynamicTail${systemSuffix == null ? '' : '\n\n$systemSuffix'}';

    final all = _loadScenarios(scenariosDir);
    final scenarios = all.where((s) => _selected(s, filter)).toList();
    expect(scenarios, isNotEmpty, reason: 'Aucun scénario ne correspond à « $filter ».');

    // Échauffement : charge le modèle et amorce le cache du préfixe, pour que
    // le premier scénario ne paie pas le démarrage à froid.
    try {
      await service.sendMessages(
        contents: [
          {'role': 'user', 'parts': [{'text': 'Bonjour'}]}
        ],
        functionDeclarations: declarations,
        systemPrompt: systemPrompt,
      );
    } catch (_) {/* l'erreur réapparaîtra, mesurée, sur les scénarios */}

    final power = _PowerSampler();
    final powerOn = measurePower && await power.start();

    // ── Rejeu ──────────────────────────────────────────────────────────────
    final runs = <BenchRun>[];
    for (final sc in scenarios) {
      var passed = 0;
      for (var rep = 1; rep <= repeat; rep++) {
        final tr = await _runScenario(service, sc, declarations, systemPrompt,
            fastPath: fastPath,
            router: routing ? const ToolRouter() : null,
            lexicon: lexicon,
            gate: gate,
            pivot: pivot);
        final v = evaluate(sc.expect, tr);
        if (v.pass) passed++;
        runs.add(BenchRun(scenario: sc, rep: rep, verdict: v, trace: tr));
      }
      // ignore: avoid_print
      print('  ${sc.id.padRight(14)} $passed/$repeat');
    }
    final powerStats = powerOn ? power.stop() : null;

    // ── Rapport ────────────────────────────────────────────────────────────
    final meta = BenchMeta(
      backend: backendKind,
      model: model,
      modelDigest: digest,
      serverVersion: serverVersion,
      contextTokens: info?.contextTokens,
      date: DateTime.now(),
      repeat: repeat,
      promptFingerprint: fingerprint(systemPrompt),
      basePromptFingerprint: fingerprint(basePrompt),
      toolsFingerprint: fingerprint(jsonEncode(declarations)),
      scenariosFingerprint:
          fingerprint(jsonEncode(scenarios.map((s) => s.toJson()).toList())),
      toolCount: declarations.length,
      gitCommit: await _gitCommit(),
      gpu: await _run('nvidia-smi',
          ['--query-gpu=name,memory.total', '--format=csv,noheader']),
      tag: tag,
      power: powerStats,
      options: {
        'chemin_rapide_arret_urgence': fastPath,
        'routage_outils': routing,
        if (lexicon != null) 'frontal_lexique': true,
        if (lexicon != null && gate) 'garde_refus_lexique': true,
        'suffixe_systeme': ?systemSuffix,
        if (pivot != null) 'pivot_traduction': env['BENCH_PIVOT'],
        if (env['BENCH_SCENARIOS'] != null) 'scenarios': scenariosDir,
      },
    );

    Directory(outDir).createSync(recursive: true);
    final stamp = meta.date
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp(r'[:T]'), '-');
    final safeModel = model.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final base = '$outDir/${stamp}_$safeModel${tag.isEmpty ? '' : '_$tag'}';
    File('$base.md').writeAsStringSync(renderMarkdown(meta, runs), encoding: utf8);
    File('$base.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(renderJson(meta, runs)),
        encoding: utf8);

    // ── Promotion en « version IA » (sur demande explicite) ───────────────
    if (promoteId != null && promoteId.isNotEmpty) {
      if (filter != null && filter.trim().isNotEmpty) {
        fail('BENCH_PROMOTE exige un passage COMPLET : pas de BENCH_FILTER.');
      }
      if (env['BENCH_SCENARIOS'] != null) {
        fail('BENCH_PROMOTE exige les scénarios du produit : pas de BENCH_SCENARIOS.');
      }
      final evidence = Directory('docs/addis/evidence')..createSync(recursive: true);
      final name = base.split('/').last;
      File('$base.md').copySync('${evidence.path}/$name.md');
      File('$base.json').copySync('${evidence.path}/$name.json');
      final release = renderRelease(meta, runs,
          id: promoteId, reportPath: 'docs/addis/evidence/$name.md');
      File('tool/eval/ai_release.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(release)}\n',
          encoding: utf8);
      // ignore: avoid_print
      print('Version IA « $promoteId » écrite : tool/eval/ai_release.json');
    }

    final h = GroupStats(runs
        .where((r) => BenchValidation.countsInHeadline(r.scenario.validation))
        .toList());
    // ignore: avoid_print
    print('\nForgeron-Bench · $model · ${h.passed}/${h.n} réussis '
        '(${(h.rate * 100).toStringAsFixed(1)} % · IC95 '
        '${(h.ci.low * 100).toStringAsFixed(0)}–${(h.ci.high * 100).toStringAsFixed(0)}) · '
        'p50 ${_sec(h.p50)} · p95 ${_sec(h.p95)} · ${h.meanTokens.toStringAsFixed(0)} tokens/tour'
        '\nRapport : $base.md');

    service.dispose();
  }, timeout: const Timeout(Duration(hours: 3)));
}

String _sec(num? ms) => ms == null ? '—' : '${(ms / 1000).toStringAsFixed(2)} s';

Future<String?> _gitCommit() async {
  final head = await _run('git', ['rev-parse', '--short', 'HEAD']);
  if (head == null) return null;
  final dirty = await _run('git', ['status', '--porcelain']);
  return dirty == null ? head : '$head+modifications';
}

/// Rejoue un scénario : le modèle répond, ses appels d'outils reçoivent un
/// résultat simulé, jusqu'à une réponse sans appel ou `max_turns`.
Future<BenchTrace> _runScenario(
  AiBackend service,
  BenchScenario sc,
  List<Map<String, dynamic>> declarations,
  String systemPrompt, {
  bool fastPath = true,
  ToolRouter? router,
  CommandLexicon? lexicon,
  bool gate = false,
  Map<String, dynamic>? pivot,
}) async {
  // Chemin rapide : l'application déclenche l'arrêt d'urgence SANS passer par
  // le modèle quand le message est, en entier, un ordre d'arrêt (voir
  // `emergency_intent.dart`). Le banc fait de même pour mesurer le produit.
  // Pivot de traduction : le modèle (et les chemins déterministes) reçoivent la
  // traduction française, pas l'énoncé d'origine.
  final user = ((pivot?[sc.id] as Map?)?['traduction'] as String?) ?? sc.user;
  if (fastPath && user != null && isEmergencyStopRequest(user)) {
    return BenchTrace(
      calls: const [BenchCall('emergency_stop', {})],
      finalText: 'Arrêt d\'urgence déclenché.',
      allText: 'Arrêt d\'urgence déclenché.',
      turns: 0,
      notes: const ['chemin_rapide:arret_urgence'],
    );
  }

  // Frontal à lexique : compris sans réserve → exécuté sans le modèle.
  var readOnlyOnly = false;
  if (lexicon != null && user != null && sc.history.isEmpty) {
    final r = lexicon.interpret(user);
    final m = r.match;
    if (m == null && gate && (r.refusal == 'question' || r.refusal == 'negation')) {
      readOnlyOnly = true;
    }
    if (m != null) {
      return BenchTrace(
        calls: [BenchCall(m.tool, m.args)],
        finalText: '(compris par le lexique : ${m.evidence.join(', ')})',
        allText: '(compris par le lexique : ${m.evidence.join(', ')})',
        turns: 0,
        notes: ['frontal_lexique:${m.intent}'],
      );
    }
  }

  // Copie profonde : le compactage de l'agent mute l'historique.
  final contents = <Map<String, dynamic>>[
    for (final c in sc.history)
      (jsonDecode(jsonEncode(c)) as Map).cast<String, dynamic>(),
    if (user != null)
      {
        'role': 'user',
        'parts': [
          {'text': user}
        ]
      },
  ];

  final calls = <BenchCall>[];
  final texts = <String>[];
  final notes = <String>[];
  var tokens = 0;
  var turns = 0;
  var declaredSum = 0;
  final clock = Stopwatch()..start();

  // Outils déclarés pour ce tour : tous, ou ceux que le routeur retient. Les
  // groupes déjà sollicités (historique du scénario + appels faits) restent.
  List<Map<String, dynamic>> declarationsForTurn() {
    if (readOnlyOnly) {
      // Même règle que le produit (command_understanding.dart).
      return declarations.where((d) => isReadOnlyToolName('${d['name']}')).toList();
    }
    if (router == null) return declarations;
    final names = declarations.map((d) => '${d['name']}').toList();
    final used = <String>{
      for (final c in sc.history)
        for (final p in (c['parts'] as List? ?? const []).whereType<Map>())
          if (p['functionCall'] is Map) '${(p['functionCall'] as Map)['name']}',
      for (final c in calls) c.name,
    };
    final recent = <String>{
      for (final e in ToolRouter.groups.entries)
        if (e.value.tools.any(used.contains)) e.key,
    };
    final routing =
        router.route(text: user ?? '', allTools: names, recentGroups: recent);
    return declarations.where((d) => routing.tools.contains('${d['name']}')).toList();
  }

  try {
    while (turns < sc.maxTurns) {
      turns++;
      final turnDeclarations = declarationsForTurn();
      declaredSum += turnDeclarations.length;
      final r = await service.sendMessages(
        contents: contents,
        functionDeclarations: turnDeclarations,
        systemPrompt: systemPrompt,
      );
      tokens += r.totalTokens;
      notes.addAll(r.notes);
      if (r.text.trim().isNotEmpty) texts.add(r.text.trim());

      final fcs = r.parts.where((p) => p.containsKey('functionCall')).toList();
      if (fcs.isEmpty) break;

      contents.add({'role': 'model', 'parts': r.parts});
      final answers = <Map<String, dynamic>>[];
      for (final p in fcs) {
        final fc = (p['functionCall'] as Map).cast<String, dynamic>();
        final name = '${fc['name']}';
        final args = ((fc['args'] as Map?) ?? const {}).cast<String, dynamic>();
        calls.add(BenchCall(name, args));
        answers.add({
          'functionResponse': {
            'name': name,
            'response': {'result': sc.toolResults[name] ?? '{"ok":true}'},
          },
        });
      }
      contents.add({'role': 'user', 'parts': answers});
    }
  } catch (e) {
    return BenchTrace(
      calls: calls,
      finalText: texts.isEmpty ? '' : texts.last,
      allText: texts.join('\n'),
      turns: turns,
      totalTokens: tokens,
      latency: clock.elapsed,
      error: '$e',
      notes: notes,
      declared: turns == 0 ? 0 : (declaredSum / turns).round(),
    );
  }

  return BenchTrace(
    calls: calls,
    finalText: texts.isEmpty ? '' : texts.last,
    allText: texts.join('\n'),
    turns: turns,
    totalTokens: tokens,
    latency: clock.elapsed,
    notes: notes,
    declared: turns == 0 ? 0 : (declaredSum / turns).round(),
  );
}
