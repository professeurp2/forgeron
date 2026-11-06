// Corpus de distillation : un « professeur » répond à la place du modèle
// local, dans le VRAI agent, et chaque appel devient un exemple
// d'entraînement pour le modèle local (« l'élève »).
//
//   flutter test tool/distill/generer_corpus_test.dart --reporter expanded
//
// Pourquoi dans l'agent réel et pas avec un prompt recopié : l'élève doit
// apprendre sur EXACTEMENT ce qu'il recevra dans l'application — prompt
// système construit pour le modèle local (directive de langue, glossaire,
// ancre de fin), outils déclarés par les spécialistes, historique compacté au
// budget du modèle local, résultats d'outils réels (machine simulée). Seule la
// réponse vient du professeur.
//
// Variables :
//   DISTILL_TEACHER   ollama:<modèle> (défaut ollama:gemma3n)
//                     ou gemini:<modèle> — voir le garde ci-dessous.
//   DISTILL_STUDENT   modèle local servi par Ollama (défaut forgeron-qwen) :
//                     fixe le prompt et le budget d'historique de l'élève.
//   DISTILL_URL       serveur Ollama (défaut http://localhost:11434).
//   DISTILL_LANGS     codes séparés par des virgules (défaut : les 15 langues
//                     africaines de l'application).
//   DISTILL_SEEDS     ids de graines séparés par des virgules (défaut : toutes).
//   DISTILL_LIMIT     nombre maximal de conversations (essai rapide).
//
// Professeur Gemini : les conditions additionnelles de l'API Gemini
// (version du 23 mars 2026, « Use Restrictions ») interdisent d'utiliser le
// service pour développer des modèles qui lui font concurrence, et d'en
// répliquer les données ou les modèles. Distiller Gemini dans Qwen peut
// tomber sous ces clauses : c'est une décision du porteur du projet, pas de
// l'outil. Le professeur Gemini ne s'ouvre donc qu'avec
// DISTILL_CGU_GEMINI=decision-du-porteur, en plus de GEMINI_API_KEY.
// Voir docs/addis/distillation-langues.md.
//
// Sorties (dossier distill_data/, ignoré par git — données NON relues) :
//   corpus_<date>.jsonl   exemples acceptés (format messages + tools)
//   rejets_<date>.jsonl   exemples rejetés, avec la raison
//   graines_<langue>_<professeur>.json   traductions des graines (cache)
//   rapport_<date>.md     synthèse par langue et par raison de rejet
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:forgeron/core/i18n/language_detector.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_machine_repository.dart';

const _africaines = [
  'bm', 'ar', 'sw', 'af', 'am', 'ha', 'yo', 'ig', //
  'zu', 'so', 'rw', 'sn', 'ln', 'wo', 'mg',
];

/// Un appel au modèle, transformé en exemple d'entraînement.
class _Exemple {
  _Exemple(this.messages, this.tools, this.response, this.systemPrompt);
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> tools;
  final AiApiResponse response;
  final String? systemPrompt;
}

/// Se présente comme le modèle local (même identifiant, même budget
/// d'historique) pour que l'agent construise le prompt de l'élève, puis fait
/// répondre le professeur.
class _Capture implements AiBackend, WritesLanguages {
  _Capture(this.teacher, this.modelId, this.budget);
  final AiBackend teacher;
  final String modelId;
  final int budget;
  final List<_Exemple> exemples = [];

  // Le corpus apprend à l'élève à écrire la langue cible : le prompt doit la
  // demander. Le modèle entraîné ne déclarera ces langues
  // (`LocalAiAgentService.writtenLanguages`) qu'après mesure au banc ; d'ici
  // là, le modèle local actuel reçoit la consigne « français simple ».
  @override
  bool writesLanguage(String languageId) => true;

  @override
  String get model => modelId;
  @override
  int get historyBudgetChars => budget;
  @override
  bool get usesCellular => false;
  @override
  Future<bool> isReachable() => teacher.isReachable();
  @override
  String get unreachableMessage => teacher.unreachableMessage;
  @override
  void dispose() {}

  void _garde(List<Map<String, dynamic>> contents,
      List<Map<String, dynamic>> decl, String? prompt, AiApiResponse r) {
    exemples.add(_Exemple(
      LocalAiAgentService.toOpenAiMessages(contents, prompt,
          supportsImages: false),
      LocalAiAgentService.toOpenAiTools(decl),
      r,
      prompt,
    ));
  }

  @override
  Future<AiApiResponse> sendMessages(
      {required List<Map<String, dynamic>> contents,
      required List<Map<String, dynamic>> functionDeclarations,
      String? systemPrompt}) async {
    final r = await teacher.sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt);
    _garde(contents, functionDeclarations, systemPrompt, r);
    return r;
  }

  @override
  Future<AiApiResponse> streamMessages(
      {required List<Map<String, dynamic>> contents,
      required List<Map<String, dynamic>> functionDeclarations,
      String? systemPrompt,
      void Function(String partialText)? onDelta,
      bool Function()? shouldCancel}) async {
    final r = await teacher.sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt);
    onDelta?.call(r.text);
    _garde(contents, functionDeclarations, systemPrompt, r);
    return r;
  }
}

/// Réponse du professeur → message assistant au format OpenAI (celui que
/// l'élève apprend à produire).
Map<String, dynamic> _cible(AiApiResponse r) {
  final calls = [
    for (final p in r.parts)
      if (p['functionCall'] is Map)
        {
          'type': 'function',
          'function': {
            'name': (p['functionCall'] as Map)['name'],
            'arguments': (p['functionCall'] as Map)['args'] ?? {},
          }
        }
  ];
  return {
    'role': 'assistant',
    'content': r.text,
    if (calls.isNotEmpty) 'tool_calls': calls,
  };
}

/// Nombre collé à une unité ou à un axe (« 12 mm », « X0 », « 8000 tr/min ») :
/// une donnée machine. Si elle n'apparaît nulle part dans ce que le
/// professeur a reçu, il l'a inventée.
final _donneeMachine = RegExp(
    r'(?:\b[XYZAC]\s*[:=]?\s*(-?\d+(?:[.,]\d+)?))|'
    r'(?:(-?\d+(?:[.,]\d+)?)\s*(?:mm\b|°|tr/min|rpm\b|mm/min|%))',
    caseSensitive: false);

/// Lettres africaines propres à certaines orthographes. Une réponse en
/// haoussa qui contient « ɛ » ou « ɔ » recopie le glossaire bambara (essai du
/// 5 nov. : « Mashal kɛn. », « Homing ɣa ɣan kɛ kɛ… »).
const _lettresSpeciales = 'ɛɔɲŋɣɓɗƙƴ';
const _lettresPermises = <String, String>{
  'bm': 'ɛɔɲŋ',
  'ln': 'ɛɔ',
  'wo': 'ŋ',
  'ha': 'ɓɗƙƴ',
};

String? _lettresEtrangeres(String text, String langue) {
  final permises = _lettresPermises[langue] ?? '';
  for (final ch in text.toLowerCase().split('')) {
    if (_lettresSpeciales.contains(ch) && !permises.contains(ch)) return ch;
  }
  return null;
}

/// Même phrase répétée 3 fois ou plus.
bool _boucle(String t) {
  final counts = <String, int>{};
  for (final p in t.split(RegExp(r'[.!?\n]+'))) {
    final k = p.trim().toLowerCase();
    if (k.length > 12) counts[k] = (counts[k] ?? 0) + 1;
  }
  return counts.values.any((c) => c >= 3) ||
      LocalAiAgentService.findRepetitionLoop(t) != null;
}

/// Raisons de rejet d'un exemple (vide = accepté).
List<String> _rejets(_Exemple e, String langue) {
  final r = e.response;
  final text = r.text;
  final hasCall = r.parts.any((p) => p['functionCall'] is Map);
  final out = <String>[];
  if (text.trim().isEmpty && !hasCall) out.add('vide');
  if (text.isEmpty) return out;
  if (LocalAiAgentService.containsCjk(text)) out.add('cjk');
  // Restes de gabarit (essai du 5 nov. : « Ni saa ya makini? /think »).
  if (RegExp(r'/think|/no_think|</?think>|<\|im_').hasMatch(text)) {
    out.add('balise');
  }
  if (_boucle(text)) out.add('boucle');
  if (LocalAiAgentService.driftedFromTarget(r, systemPrompt: e.systemPrompt)) {
    out.add('langue_derive');
  }
  // Réponse dans une AUTRE langue africaine que celle demandée.
  final cible =
      LocalAiAgentService.targetLanguageFromPrompt(e.systemPrompt) ?? langue;
  final etrangere = _lettresEtrangeres(text, cible);
  if (etrangere != null) out.add('lettres_etrangeres:$etrangere');
  final vue = LanguageDetector.detectOperatorLanguage(text, fallback: '');
  if (vue.isNotEmpty && vue != cible && _africaines.contains(vue)) {
    out.add('autre_langue:$vue');
  }
  final contexte = [
    e.systemPrompt ?? '',
    for (final m in e.messages) jsonEncode(m),
  ].join('\n');
  for (final m in _donneeMachine.allMatches(text)) {
    final n = (m.group(1) ?? m.group(2))!;
    final variantes = {n, n.replaceAll(',', '.'), n.replaceAll('.', ',')};
    if (!variantes.any(contexte.contains)) {
      out.add('donnee_inventee:${m.group(0)!.trim()}');
      break;
    }
  }
  return out;
}

Future<AiBackend> _professeur(String spec, String url) async {
  final i = spec.indexOf(':');
  final kind = i < 0 ? spec : spec.substring(0, i);
  final name = i < 0 ? '' : spec.substring(i + 1);
  final env = Platform.environment;
  switch (kind) {
    case 'gemini':
      // Variable d'environnement, sinon fichier hors du dépôt
      // (%USERPROFILE%\.forgeron\GEMINI_API_KEY). La clé n'est jamais
      // affichée ni écrite ailleurs.
      var key = (env['GEMINI_API_KEY'] ?? '').trim();
      if (key.isEmpty) {
        final f = File('${env['USERPROFILE'] ?? env['HOME'] ?? ''}'
            '${Platform.pathSeparator}.forgeron'
            '${Platform.pathSeparator}GEMINI_API_KEY');
        if (f.existsSync()) key = _cleDuFichier(f.readAsStringSync());
      }
      if (key.isEmpty) {
        throw StateError('Clé Gemini absente (GEMINI_API_KEY ou '
            '%USERPROFILE%\\.forgeron\\GEMINI_API_KEY).');
      }
      if (env['DISTILL_CGU_GEMINI'] != 'decision-du-porteur') {
        throw StateError('Professeur Gemini fermé : voir le garde en tête de '
            'fichier et docs/addis/distillation-langues.md.');
      }
      return AiAgentService(
          apiKey: key,
          model: name.isEmpty ? 'gemini-flash-lite-latest' : name);
    case 'ollama':
      final model = name.isEmpty ? 'gemma3n' : name;
      return LocalAiAgentService(
          baseUrl: url,
          model: model,
          info: await LocalAiAgentService.probe(url, model));
    default:
      throw ArgumentError('DISTILL_TEACHER inconnu : $spec');
  }
}

/// Traduit les graines françaises dans [langue] avec le professeur. Cache sur
/// disque : une traduction coûte un appel, on ne la refait pas.
Future<Map<String, String>> _traduire(AiBackend prof, String profId,
    String langue, List<Map<String, dynamic>> graines) async {
  final cache = File('distill_data/graines_${langue}_'
      '${profId.replaceAll(RegExp(r'[^\w.-]'), '_')}.json');
  final out = cache.existsSync()
      ? (jsonDecode(cache.readAsStringSync()) as Map).cast<String, String>()
      : <String, String>{};
  if (langue == 'fr') {
    return {for (final g in graines) g['id'] as String: g['fr'] as String};
  }
  final nom = appLanguageById(langue).promptName;
  final manquantes = graines.where((g) => !out.containsKey(g['id'])).toList();
  if (manquantes.isNotEmpty) {
    // Un seul appel par langue (quota Gemini : 500 requêtes par jour).
    final liste = {for (final g in manquantes) g['id'] as String: g['fr']};
    final r = await prof.sendMessages(contents: [
      {
        'role': 'user',
        'parts': [
          {
            'text': 'Traduis en $nom chacune de ces phrases, dites par un '
                'opérateur devant une machine CNC. Écris comme on le dit à '
                "l'oral. Réponds UNIQUEMENT par un objet JSON qui garde les "
                'mêmes clés, avec la traduction pour valeur :\n'
                '${jsonEncode(liste)}'
          }
        ]
      }
    ], functionDeclarations: const [], systemPrompt: 'Tu es traducteur.');
    final brut = r.text;
    final a = brut.indexOf('{'), b = brut.lastIndexOf('}');
    if (a >= 0 && b > a) {
      try {
        final j = jsonDecode(brut.substring(a, b + 1)) as Map;
        for (final e in j.entries) {
          final t = '${e.value}'.trim().split('\n').first.trim();
          if (liste.containsKey(e.key) &&
              t.isNotEmpty &&
              !LocalAiAgentService.containsCjk(t)) {
            out['${e.key}'] = t;
          }
        }
      } on FormatException {
        // Réponse non JSON : graines sautées pour cette langue.
      }
    }
  }
  cache.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // ce générateur parle à de vrais serveurs

  final env = Platform.environment;
  final url = env['DISTILL_URL'] ?? 'http://localhost:11434';
  final teacherSpec = env['DISTILL_TEACHER'] ?? 'ollama:gemma3n';
  final student = env['DISTILL_STUDENT'] ?? 'forgeron-qwen';
  final langues = (env['DISTILL_LANGS']?.split(',') ?? _africaines)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final seedFilter = env['DISTILL_SEEDS']?.split(',').toSet();
  final limit = int.tryParse(env['DISTILL_LIMIT'] ?? '');

  test('génère le corpus de distillation', () async {
    try {
      final tags = await http
          .get(Uri.parse('$url/api/tags'))
          .timeout(const Duration(seconds: 3));
      if (tags.statusCode != 200 || !tags.body.contains('"$student')) {
        markTestSkipped('Ollama ne sert pas l\'élève « $student » sur $url.');
        return;
      }
    } catch (_) {
      markTestSkipped('Aucun serveur Ollama sur $url.');
      return;
    }
    final prof = await _professeur(teacherSpec, url);
    final eleve = LocalAiAgentService(
        baseUrl: url,
        model: student,
        info: await LocalAiAgentService.probe(url, student));

    final graines = ((jsonDecode(
                File('tool/distill/graines_fr.json').readAsStringSync())
            as Map)['graines'] as List)
        .cast<Map<String, dynamic>>()
        .where((g) => seedFilter == null || seedFilter.contains(g['id']))
        .toList();

    Directory('distill_data').createSync(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(':', '-');
    final corpus = File('distill_data/corpus_$stamp.jsonl')
        .openWrite(encoding: utf8);
    final rejets = File('distill_data/rejets_$stamp.jsonl')
        .openWrite(encoding: utf8);
    final parLangue = <String, List<int>>{}; // [acceptés, rejetés, sans modèle]
    final raisons = <String, int>{};
    var conversations = 0;
    var quotaEpuise = false;

    // Reprise : un couple (langue, graine) déjà traité par ce professeur
    // n'est pas refait. Une erreur du professeur (quota…) ne compte pas : on
    // la refait au prochain lancement. Le quota gratuit de Gemini (500
    // requêtes par jour pour Flash Lite) impose plusieurs lancements.
    final dejaFaits = <String>{};
    for (final f in Directory('distill_data').listSync().whereType<File>()) {
      final nom = f.uri.pathSegments.last;
      if (!nom.endsWith('.jsonl') ||
          !(nom.startsWith('corpus_') || nom.startsWith('rejets_'))) {
        continue;
      }
      for (final l in f.readAsLinesSync()) {
        if (l.trim().isEmpty) continue;
        final j = jsonDecode(l) as Map<String, dynamic>;
        final motifs = (j['rejet'] as List?)?.cast<String>() ?? const [];
        if (j['professeur'] == teacherSpec &&
            !motifs.any((m) => m.startsWith('erreur'))) {
          dejaFaits.add('${j['langue']}-${j['graine']}');
        }
      }
    }
    final pause = Duration(
        milliseconds: int.tryParse(env['DISTILL_PAUSE_MS'] ?? '') ??
            (teacherSpec.startsWith('gemini') ? 4000 : 0));

    await AppLocalizations.delegate.load(const Locale('fr'));

    outer:
    for (final langue in langues) {
      final traductions = await _traduire(prof, teacherSpec, langue, graines);
      final compte = parLangue.putIfAbsent(langue, () => [0, 0, 0]);
      for (final g in graines) {
        if (limit != null && conversations >= limit) break outer;
        final id = g['id'] as String;
        final phrase = traductions[id];
        if (phrase == null || dejaFaits.contains('$langue-$id')) continue;
        if (conversations > 0) await Future<void>.delayed(pause);
        conversations++;

        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        final c = ProviderContainer(overrides: [
          machineRepositoryProvider.overrideWithValue(FakeMachineRepository()),
          lexiconSourceProvider.overrideWithValue(
              () async => File('assets/lexicon/lexique.json').readAsString()),
        ]);
        await c.read(lexiconLoadProvider.future);
        final cap = _Capture(prof, c.read(aiModelProvider).active.id,
            eleve.historyBudgetChars);
        final ctl = c.read(aiAgentControllerProvider.notifier);
        // ignore: invalid_use_of_visible_for_testing_member
        ctl.debugUseBackend(cap);

        String? erreur;
        try {
          await ctl.sendUserMessage(phrase).timeout(const Duration(minutes: 5));
          // Une carte de confirmation : on la refuse. Le corpus ne doit pas
          // apprendre à l'élève qu'une action a eu lieu.
          if (c.read(aiAgentControllerProvider).pendingConfirmation != null) {
            await ctl.rejectPendingAction();
          }
        } catch (e) {
          erreur = '$e';
        }
        // Une erreur du professeur (quota, modèle sans outils…) lève avant
        // que l'appel soit gardé : elle doit quand même se voir au rapport.
        final erreurAffichee = c.read(aiAgentControllerProvider).error;
        if (erreur != null || erreurAffichee != null) {
          raisons['erreur_professeur'] = (raisons['erreur_professeur'] ?? 0) + 1;
        } else if (cap.exemples.isEmpty) {
          compte[2]++;
        }
        // Une question de lecture à laquelle le professeur répond sans lire la
        // machine : la réponse ne peut venir que de son imagination.
        final outil = g['outil'] as String?;
        final outilAbsent = outil != null &&
            !cap.exemples.any((e) => e.response.parts.any((p) =>
                p['functionCall'] is Map &&
                (p['functionCall'] as Map)['name'] == outil));
        for (final (n, e) in cap.exemples.indexed) {
          final motifs = [
            ..._rejets(e, langue),
            if (outilAbsent) 'outil_attendu_absent:$outil',
            if (erreur != null) 'erreur:$erreur',
          ];
          final ligne = jsonEncode({
            'id': '$langue-$id-$n',
            'langue': langue,
            'graine': id,
            'categorie': g['categorie'],
            'graine_fr': g['fr'],
            'graine_traduite': phrase,
            'professeur': teacherSpec,
            'eleve': student,
            'relu': false,
            if (motifs.isNotEmpty) 'rejet': motifs,
            'messages': [...e.messages, _cible(e.response)],
            'tools': e.tools,
          });
          if (motifs.isEmpty) {
            corpus.writeln(ligne);
            compte[0]++;
          } else {
            rejets.writeln(ligne);
            compte[1]++;
            for (final m in motifs) {
              final k = m.split(':').first;
              raisons[k] = (raisons[k] ?? 0) + 1;
            }
          }
        }
        final st = c.read(aiAgentControllerProvider);
        final dernier = st.messages.isEmpty ? '' : st.messages.last.text;
        // ignore: avoid_print
        print('$langue ${id.padRight(16)} ${cap.exemples.length} appel(s)'
            '${erreur == null ? '' : ' ERREUR $erreur'}'
            '${st.error == null ? '' : ' · erreur affichée : ${st.error}'}'
            ' · « ${dernier.length > 70 ? dernier.substring(0, 70) : dernier} »');
        c.dispose();
        // Quota épuisé : continuer ne produirait que des erreurs.
        if (RegExp(r'429|quota|RESOURCE_EXHAUSTED', caseSensitive: false)
            .hasMatch('${erreur ?? ''} ${erreurAffichee ?? ''}')) {
          quotaEpuise = true;
          break outer;
        }
      }
    }
    await corpus.close();
    await rejets.close();

    final md = StringBuffer()
      ..writeln('# Corpus de distillation — $stamp')
      ..writeln()
      ..writeln('- Professeur : `$teacherSpec` · élève : `$student`')
      ..writeln('- Conversations : $conversations · graines : '
          '${graines.length} · langues : ${langues.join(', ')}')
      ..writeln('- Données NON relues par des locuteurs : à relire avant '
          'tout entraînement destiné à l\'atelier.')
      ..writeln()
      ..writeln('| Langue | Acceptés | Rejetés | Sans modèle (lexique) |')
      ..writeln('|---|---|---|---|');
    for (final e in parLangue.entries) {
      md.writeln('| ${e.key} | ${e.value[0]} | ${e.value[1]} | ${e.value[2]} |');
    }
    md
      ..writeln()
      ..writeln('| Raison de rejet | Nombre |')
      ..writeln('|---|---|');
    for (final e in (raisons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))) {
      md.writeln('| ${e.key} | ${e.value} |');
    }
    if (quotaEpuise) {
      md
        ..writeln()
        ..writeln('**Arrêt : quota du professeur épuisé.** Relancer plus tard '
            ': les couples déjà faits sont sautés.');
    }
    File('distill_data/rapport_$stamp.md').writeAsStringSync(md.toString());
    // ignore: avoid_print
    print(md);
  }, timeout: const Timeout(Duration(hours: 12)));
}

/// Clé collée à la main dans le fichier : tolère BOM, `GEMINI_API_KEY=`,
/// guillemets et lignes vides ou commentées. Garde la première ligne utile.
String _cleDuFichier(String brut) {
  for (var l in brut.replaceAll('﻿', '').split(RegExp(r'[\r\n]+'))) {
    l = l.trim();
    if (l.isEmpty || l.startsWith('#')) continue;
    final eq = l.indexOf('=');
    if (eq >= 0) l = l.substring(eq + 1).trim();
    return l.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
  }
  return '';
}
