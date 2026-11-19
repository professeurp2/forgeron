// Banc de conversation multilingue — le VRAI agent, pas une copie du prompt.
//
//   flutter test tool/eval/conversation_langues_test.dart --reporter expanded
//
// Contrairement à Forgeron-Bench (qui force « Réponds en français. » dans sa
// queue de prompt et ne mesure que les appels d'outils), ce banc pilote
// `AiAgentController` lui-même : directive de langue, glossaire, ancre de fin,
// routage multi-agents (spécialistes), lexique fermé, cartes de confirmation.
// Seul le modèle est branché à la main : le vrai `LocalAiAgentService`
// (Ollama), enveloppé pour enregistrer ce qu'il reçoit à chaque appel.
//
// Variables : CONV_MODEL (défaut forgeron-qwen), CONV_URL (défaut
// http://localhost:11434), CONV_FILTER (id de conversation, sous-chaîne),
// CONV_WRITES (langues que le modèle mesuré est déclaré écrire, séparées
// par des virgules ; défaut : LocalAiAgentService.defaultWrittenLanguages,
// les autres reçoivent « français simple »). Pour mesurer ce qu'un modèle
// écrit en bambara, il faut le lui demander : CONV_WRITES=fr,en,ar,bm,sw…
// Rapport : eval_reports/conversations_langues_<date>.md (+ .json).
//
// Se saute seul quand aucun serveur ne répond.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/ai_agent_provider.dart';
import 'package:forgeron/application/providers/ai_model_provider.dart';
import 'package:forgeron/application/providers/di_providers.dart';
import 'package:forgeron/application/providers/lexicon_provider.dart';
import 'package:forgeron/application/services/ai_agent_service.dart';
import 'package:forgeron/application/services/local_ai_agent_service.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:forgeron/core/i18n/app_language.dart';
import 'package:forgeron/core/i18n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/fake_machine_repository.dart';

/// Un appel au modèle, tel que le contrôleur l'a fait.
class _Call {
  _Call(this.declared, this.promptTail, this.text, this.toolCalls, this.ms);
  final List<String> declared;
  final String promptTail;
  final String text;
  final List<String> toolCalls;
  final int ms;
}

/// Le vrai service local, enregistré. Se présente sous l'identifiant du modèle
/// actif de l'application, pour que `_ensureService` le réutilise tel quel.
class _Recorder implements AiBackend, WritesLanguages {
  _Recorder(this.inner, this.modelId);
  final LocalAiAgentService inner;
  final String modelId;
  final List<_Call> calls = [];

  // Le banc mesure le prompt que reçoit VRAIMENT le modèle local.
  @override
  bool writesLanguage(String languageId) => inner.writesLanguage(languageId);

  @override
  String get model => modelId;
  @override
  int get historyBudgetChars => inner.historyBudgetChars;
  @override
  bool get usesCellular => false;
  @override
  Future<bool> isReachable() => inner.isReachable();
  @override
  String get unreachableMessage => inner.unreachableMessage;
  @override
  void dispose() {}

  void _record(List<Map<String, dynamic>> decl, String? prompt,
      AiApiResponse r, int ms) {
    final p = prompt ?? '';
    calls.add(_Call(
      [for (final d in decl) '${d['name']}'],
      p.length > 3500 ? p.substring(p.length - 3500) : p,
      r.text,
      [
        for (final part in r.parts)
          if (part['functionCall'] is Map)
            '${(part['functionCall'] as Map)['name']}'
                '(${jsonEncode((part['functionCall'] as Map)['args'] ?? {})})'
      ],
      ms,
    ));
  }

  @override
  Future<AiApiResponse> sendMessages(
      {required List<Map<String, dynamic>> contents,
      required List<Map<String, dynamic>> functionDeclarations,
      String? systemPrompt}) async {
    final sw = Stopwatch()..start();
    final r = await inner.sendMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt);
    _record(functionDeclarations, systemPrompt, r, sw.elapsedMilliseconds);
    return r;
  }

  @override
  Future<AiApiResponse> streamMessages(
      {required List<Map<String, dynamic>> contents,
      required List<Map<String, dynamic>> functionDeclarations,
      String? systemPrompt,
      void Function(String partialText)? onDelta,
      bool Function()? shouldCancel}) async {
    final sw = Stopwatch()..start();
    final r = await inner.streamMessages(
        contents: contents,
        functionDeclarations: functionDeclarations,
        systemPrompt: systemPrompt,
        onDelta: onDelta,
        shouldCancel: shouldCancel);
    _record(functionDeclarations, systemPrompt, r, sw.elapsedMilliseconds);
    return r;
  }
}

/// Une conversation : langue réglée dans l'app, puis les messages de
/// l'opérateur, dans l'ordre.
class _Conv {
  const _Conv(this.id, this.appLang, this.expectLang, this.turns,
      {this.expectSwitchTo});
  final String id;
  final String appLang;

  /// Langue attendue de la réponse (code), pour l'heuristique.
  final String expectLang;
  final List<String> turns;

  /// Si l'un des messages demande de changer la langue de l'interface.
  final String? expectSwitchTo;
}

const _convs = <_Conv>[
  _Conv('fr-auto', 'auto', 'fr', [
    'Bonjour, qu\'est-ce que tu sais faire pour moi ?',
    'Quel est l\'état de la machine ?',
    'Allume la broche à 8000 tours',
  ]),
  _Conv('en-auto', 'auto', 'en', [
    'Hi, what can you help me with?',
    'What is the machine state right now?',
    'Home all axes please',
  ]),
  _Conv('bm-force', 'bm', 'bm', [
    'I ni ce. I bɛ se ka mun kɛ n ye?',
    'Mansin cogoya ka di sisan?',
    'Broche daminɛ',
    'Homing kɛ',
  ]),
  _Conv('bm-auto', 'auto', 'bm', [
    'I ni ce. I bɛ se ka mun kɛ n ye?',
    'Mansin cogoya ka di sisan?',
  ]),
  _Conv('sw-auto', 'auto', 'sw', [
    'Habari, unaweza kunisaidia nini?',
    'Hali ya mashine ikoje sasa hivi?',
    'Washa spindle tafadhali',
  ]),
  _Conv('wo-auto', 'auto', 'wo', [
    'Salaam aleekum, lan nga mënn a def ngir man?',
    'Naka la masin bi mel léegi?',
  ]),
  _Conv('ar-auto', 'auto', 'ar', [
    'مرحبا، ماذا يمكنك أن تفعل لي؟',
    'ما هي حالة الآلة الآن؟',
  ]),
  _Conv('ha-auto', 'auto', 'ha', [
    'Sannu, me za ka iya yi mini?',
    'Yaya yanayin injin yanzu?',
  ]),
  _Conv('switch-fr-en', 'auto', 'fr', ['Passe l\'interface de l\'application en anglais'],
      expectSwitchTo: 'en'),
  _Conv('switch-fr-bm', 'fr', 'fr', ['Mets l\'application en bambara'],
      expectSwitchTo: 'bm'),
  _Conv('switch-bm-bm', 'auto', 'bm', ['Application kan yɛlɛma ka kɛ bamanankan ye'],
      expectSwitchTo: 'bm'),
  _Conv('switch-sw-sw', 'auto', 'sw', ['Badilisha lugha ya programu iwe Kiswahili'],
      expectSwitchTo: 'sw'),
  _Conv('switch-en-fr', 'en', 'en', ['Switch the app interface to French please'],
      expectSwitchTo: 'fr'),
];

// ── Heuristique de langue de la réponse ─────────────────────────────────────
// Volontairement simple et déclarée comme telle dans le rapport : elle sert à
// trier, la lecture des transcriptions fait foi.
final _markers = <String, RegExp>{
  'fr': RegExp(
      r"\b(je|tu|vous|le|la|les|une|des|est|pour|avec|dans|machine|broche|bonjour|peux|voici|votre|sont|pas)\b"),
  'en': RegExp(
      r"\b(the|is|are|you|your|can|with|this|that|machine|spindle|hello|please|here|have)\b"),
  'bm': RegExp(
      r"\b(i|ni|ce|bɛ|ka|ye|ko|n|a|don|kɛ|mansin|sisan|ani|tɛ|be|ba|walima|fɛ|la)\b|[ɛɔɲŋ]"),
  'sw': RegExp(
      r"\b(habari|na|ya|wa|kwa|ni|hali|mashine|kuna|unaweza|tafadhali|sasa|hii|katika|kama|ninaweza)\b"),
  'wo': RegExp(
      r"\b(nga|naka|dafa|ngir|ak|ci|bi|mën|def|jërëjëf|masin|léegi|waaw|deedeet|man)\b"),
  'ha': RegExp(
      r"\b(da|ka|na|ne|ce|zan|iya|yanzu|injin|sannu|me|wannan|don|ina|kuma|yana)\b"),
};

String _guessLang(String t) {
  final s = t.toLowerCase();
  if (s.trim().isEmpty) return '∅';
  if (RegExp(r'[一-鿿]').hasMatch(s)) return 'zh!';
  final ar = RegExp(r'[؀-ۿ]').allMatches(s).length;
  if (ar > s.length * 0.3) return 'ar';
  final scores = {
    for (final e in _markers.entries) e.key: e.value.allMatches(s).length
  };
  final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return best.value == 0 ? '?' : best.key;
}

/// Une même phrase répétée 3 fois ou plus : boucle de génération.
bool _looping(String t) {
  final parts = t
      .split(RegExp(r'[.!?\n]+'))
      .map((p) => p.trim().toLowerCase())
      .where((p) => p.length > 12)
      .toList();
  final counts = <String, int>{};
  for (final p in parts) {
    counts[p] = (counts[p] ?? 0) + 1;
  }
  return counts.values.any((c) => c >= 3);
}

String _quote(String t) =>
    t.trim().isEmpty ? '_(vide)_' : t.trim().split('\n').map((l) => '> $l').join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Le binding de test coupe le réseau (toute requête HTTP répond 400) :
  // ce banc parle à un vrai serveur.
  HttpOverrides.global = null;

  final env = Platform.environment;
  final model = env['CONV_MODEL'] ?? 'forgeron-qwen';
  final url = env['CONV_URL'] ?? 'http://localhost:11434';
  final filter = env['CONV_FILTER'];
  final writes = env['CONV_WRITES']
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet() ??
      LocalAiAgentService.defaultWrittenLanguages;

  test('conversations multilingues (agent réel, modèle local)', () async {
    try {
      final tags = await http
          .get(Uri.parse('$url/api/tags'))
          .timeout(const Duration(seconds: 3));
      if (tags.statusCode != 200 || !tags.body.contains('"$model')) {
        markTestSkipped('Aucun serveur ne sert « $model » sur $url.');
        return;
      }
    } catch (_) {
      markTestSkipped('Aucun serveur ne répond sur $url.');
      return;
    }
    final info = await LocalAiAgentService.probe(url, model);

    final md = StringBuffer()
      ..writeln('# Conversations multilingues — agent réel')
      ..writeln()
      ..writeln('- Date : ${DateTime.now().toIso8601String().substring(0, 16)}')
      ..writeln('- Modèle : `$model` (Ollama, $url)')
      ..writeln('- Langues que le modèle est déclaré écrire : '
          '${(writes.toList()..sort()).join(', ')}')
      ..writeln('- Chemin : `AiAgentController` réel (prompt, routage '
          'spécialistes, lexique, cartes de confirmation) ; machine simulée '
          '(FakeMachineRepository, hors ligne) ; actions confirmées '
          'automatiquement pour voir la réponse qui suit ; dictionnaire '
          "d'interface chargé selon la langue de l'app (auto = téléphone "
          'en français).')
      ..writeln('- Langue « devinée » = heuristique par mots-marqueurs, '
          'indicative seulement : la transcription fait foi.')
      ..writeln();
    final summary = <List<String>>[];
    final jsonOut = <Map<String, dynamic>>[];

    for (final conv in _convs) {
      if (filter != null && !conv.id.contains(filter)) continue;

      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final repo = FakeMachineRepository();
      final container = ProviderContainer(overrides: [
        machineRepositoryProvider.overrideWithValue(repo),
        lexiconSourceProvider.overrideWithValue(
            () async => File('assets/lexicon/lexique.json').readAsString()),
      ]);
      await container.read(lexiconLoadProvider.future);
      await container
          .read(appLanguageProvider.notifier)
          .select(appLanguageById(conv.appLang));

      final rec = _Recorder(
          LocalAiAgentService(
              baseUrl: url, model: model, info: info, writtenLanguages: writes),
          container.read(aiModelProvider).active.id);
      final ctl = container.read(aiAgentControllerProvider.notifier);
      // ignore: invalid_use_of_visible_for_testing_member
      ctl.debugUseBackend(rec);

      md
        ..writeln('## ${conv.id}')
        ..writeln()
        ..writeln('Langue de l\'app : **${conv.appLang}** · réponse attendue : '
            '**${conv.expectLang}**'
            '${conv.expectSwitchTo == null ? '' : ' · bascule attendue → **${conv.expectSwitchTo}**'}')
        ..writeln();

      final turnsJson = <Map<String, dynamic>>[];
      for (final msg in conv.turns) {
        // Comme Flutter : le dictionnaire d'interface suit la langue de l'app
        // (« auto » = téléphone réglé en français).
        final uiLang = container.read(appLanguageProvider);
        await AppLocalizations.delegate
            .load(Locale(uiLang.isAuto ? 'fr' : uiLang.id));
        final before = container.read(aiAgentControllerProvider).messages.length;
        final callsBefore = rec.calls.length;
        final sw = Stopwatch()..start();
        String? card;
        try {
          await ctl
              .sendUserMessage(msg)
              .timeout(const Duration(minutes: 4));
          final pending =
              container.read(aiAgentControllerProvider).pendingConfirmation;
          if (pending != null) {
            card = '${pending.toolName}(${jsonEncode(pending.input)})'
                '${pending.lexicon != null ? ' [lexique]' : ' [modèle]'}';
            await ctl.confirmPendingAction().timeout(const Duration(minutes: 4));
          }
        } catch (e) {
          card = '${card ?? ''} ERREUR: $e';
        }
        final st = container.read(aiAgentControllerProvider);
        final newMsgs = st.messages.skip(before).toList();
        final replies = newMsgs
            .where((m) => m.role == 'assistant')
            .map((m) => m.text)
            .where((t) => t.trim().isNotEmpty)
            .toList();
        final reply = replies.join('\n\n');
        final toolMsgs = newMsgs
            .where((m) => m.role == 'tool')
            .map((m) => m.toolName ?? m.text)
            .toList();
        final calls = rec.calls.skip(callsBefore).toList();
        final modelTools = [for (final c in calls) ...c.toolCalls];
        final guessed = _guessLang(reply);
        final loop = _looping(reply);
        final lang = container.read(appLanguageProvider).id;

        final flags = <String>[
          if (guessed != conv.expectLang) 'langue≠${conv.expectLang}',
          if (guessed == 'zh!') 'CJK',
          if (loop) 'boucle',
          if (reply.trim().isEmpty) 'muet',
          if (st.error != null) 'erreur',
        ];

        md
          ..writeln('**Opérateur :** $msg')
          ..writeln()
          ..writeln('- Appels modèle : ${calls.length} '
              '(${calls.map((c) => '${(c.ms / 1000).toStringAsFixed(1)} s').join(', ')}) '
              '· outils déclarés : ${calls.isEmpty ? '—' : calls.map((c) => c.declared.length).join('/')}')
          ..writeln('- Outils demandés par le modèle : '
              '${modelTools.isEmpty ? '—' : modelTools.map((t) => '`$t`').join(', ')}')
          ..writeln('- Carte de confirmation : ${card == null ? '—' : '`$card`'}')
          ..writeln('- Messages outil : ${toolMsgs.isEmpty ? '—' : toolMsgs.join(', ')}')
          ..writeln('- Langue de l\'app après le tour : `$lang`')
          ..writeln('- Langue devinée de la réponse : **$guessed**'
              '${flags.isEmpty ? ' ✅' : ' ⚠️ ${flags.join(', ')}'}')
          ..writeln('- Durée totale : ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} s')
          ..writeln()
          ..writeln('**Agent :**')
          ..writeln()
          ..writeln(_quote(reply))
          ..writeln();
        if (st.error != null) md.writeln('Erreur affichée : `${st.error}`\n');

        summary.add([
          conv.id,
          msg.length > 40 ? '${msg.substring(0, 40)}…' : msg,
          conv.expectLang,
          guessed,
          modelTools.isEmpty ? (card ?? '—') : modelTools.join(' '),
          lang,
          flags.isEmpty ? 'ok' : flags.join(', '),
        ]);
        turnsJson.add({
          'user': msg,
          'reply': reply,
          'guessed': guessed,
          'flags': flags,
          'card': card,
          'model_tools': modelTools,
          'app_lang_after': lang,
          'calls': [
            for (final c in calls)
              {
                'declared': c.declared,
                'tools': c.toolCalls,
                'text': c.text,
                'ms': c.ms,
                'prompt_tail': c.promptTail,
              }
          ],
        });
        // ignore: avoid_print
        print('${conv.id.padRight(14)} ${guessed.padRight(4)} '
            '${flags.isEmpty ? 'ok' : flags.join(',')}  « ${msg.length > 30 ? msg.substring(0, 30) : msg} »');
      }
      if (conv.expectSwitchTo != null) {
        final got = container.read(appLanguageProvider).id;
        md.writeln(got == conv.expectSwitchTo
            ? '**Bascule d\'interface : ✅ `$got`**\n'
            : '**Bascule d\'interface : ❌ attendu `${conv.expectSwitchTo}`, obtenu `$got`**\n');
      }
      // Fin de prompt réellement envoyée au dernier appel (directive, ancre).
      if (rec.calls.isNotEmpty) {
        md
          ..writeln('<details><summary>Fin du prompt système au dernier appel</summary>')
          ..writeln()
          ..writeln('```')
          ..writeln(rec.calls.last.promptTail)
          ..writeln('```')
          ..writeln()
          ..writeln('</details>')
          ..writeln();
      }
      jsonOut.add({
        'id': conv.id,
        'app_lang': conv.appLang,
        'expect': conv.expectLang,
        'switch_to': conv.expectSwitchTo,
        'turns': turnsJson,
      });
      container.dispose();
    }

    final table = StringBuffer()
      ..writeln('## Synthèse')
      ..writeln()
      ..writeln('| Conversation | Message | Attendu | Deviné | Outil | Langue app | Signal |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final r in summary) {
      table.writeln('| ${r.map((c) => c.replaceAll('|', '\\|')).join(' | ')} |');
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(':', '-');
    Directory('eval_reports').createSync(recursive: true);
    final out = 'eval_reports/conversations_langues_$stamp';
    final text = md.toString();
    final cut = text.indexOf('## ');
    File('$out.md').writeAsStringSync(
        '${text.substring(0, cut)}${table.toString()}\n${text.substring(cut)}');
    File('$out.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(jsonOut));
    // ignore: avoid_print
    print('Rapport : $out.md');
  }, timeout: const Timeout(Duration(minutes: 90)));
}
