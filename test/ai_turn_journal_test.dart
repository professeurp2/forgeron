import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/ai_turn_journal.dart';

void main() {
  late Directory dir;
  late AiTurnJournal journal;

  AiTurnRecord rec({
    AiTurnOutcome outcome = AiTurnOutcome.ok,
    int latencyMs = 1000,
    int tokens = 7000,
    List<String> tools = const [],
    List<String> notes = const [],
    DateTime? time,
  }) =>
      AiTurnRecord(
        time: time ?? DateTime.utc(2026, 10, 22, 12),
        backend: 'local',
        model: 'forgeron-qwen',
        outcome: outcome,
        latencyMs: latencyMs,
        tokens: tokens,
        tools: tools,
        notes: notes,
        declaredTools: 38,
        release: 'abc123',
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ai_journal_');
    journal = AiTurnJournal(dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('une ligne JSON par tour, relisible', () async {
    await journal.record(rec(tools: ['get_machine_state'], notes: ['langue:nouvelle_tentative']));
    await journal.record(rec(outcome: AiTurnOutcome.empty));
    final lines = await journal.file.readAsLines();
    expect(lines, hasLength(2));
    expect(jsonDecode(lines.first)['tools'], ['get_machine_state']);

    final all = await journal.readAll();
    expect(all, hasLength(2));
    expect(all.first.notes, ['langue:nouvelle_tentative']);
    expect(all.last.outcome, AiTurnOutcome.empty);
  });

  test('le journal ne contient AUCUN contenu de conversation', () {
    final json = rec(tools: ['jog_axis']).toJson();
    expect(json.keys, isNot(contains('text')));
    expect(json.keys, isNot(contains('args')));
    expect(json.keys, isNot(contains('content')));
    expect(jsonEncode(json), isNot(contains('distance')),
        reason: 'ni arguments d\'outils, ni valeurs');
  });

  test('rotation : le fichier courant passe en .1, les anciens sont bornés',
      () async {
    final small = AiTurnJournal(dir.path, maxBytes: 200, keep: 3);
    for (var i = 0; i < 30; i++) {
      await small.record(rec(latencyMs: i));
    }
    final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();
    expect(names, ['ai_journal.jsonl', 'ai_journal.jsonl.1', 'ai_journal.jsonl.2']);
    final all = await small.readAll();
    expect(all.last.latencyMs, 29, reason: 'le plus récent est en dernier');
    expect(all.length, lessThan(30), reason: 'les plus anciens sont tombés');
  });

  test('une ligne corrompue est ignorée, jamais fatale', () async {
    await journal.record(rec());
    await journal.file.writeAsString('pas du json\n{"ts": 1}\n', mode: FileMode.append);
    await journal.record(rec(outcome: AiTurnOutcome.error));
    final all = await journal.readAll();
    expect(all, hasLength(2));
  });

  test('un dossier impossible n\'empêche pas l\'agent de répondre', () async {
    final broken = AiTurnJournal('${dir.path}${Platform.pathSeparator}absent${Platform.pathSeparator}x');
    await broken.record(rec()); // ne lève pas
    expect(await broken.readAll(), isEmpty);
  });

  group('résumé', () {
    test('compte les issues, les outils et les garde-fous', () {
      final s = AiJournalSummary.of([
        rec(tools: ['get_machine_state'], latencyMs: 1000),
        rec(tools: ['get_machine_state', 'home'], latencyMs: 3000, notes: ['appel_en_texte:recupere']),
        rec(outcome: AiTurnOutcome.empty),
        rec(outcome: AiTurnOutcome.error),
        rec(outcome: AiTurnOutcome.cancelled),
      ]);
      expect(s.turns, 5);
      expect(s.count(AiTurnOutcome.ok), 2);
      expect(s.count(AiTurnOutcome.empty), 1);
      expect(s.toolCalls['get_machine_state'], 2);
      expect(s.guards['appel_en_texte:recupere'], 1);
      // 2 réussis sur 4 non annulés
      expect(s.successRate, 0.5);
    });

    test('la latence ne compte que les tours réussis', () {
      final s = AiJournalSummary.of([
        rec(latencyMs: 1000),
        rec(latencyMs: 2000),
        rec(latencyMs: 60000, outcome: AiTurnOutcome.error),
      ]);
      expect(s.latencyP50Ms, 1000);
      expect(s.latencyP95Ms, 2000);
    });

    test('un journal vide ne plante pas', () {
      final s = AiJournalSummary.of(const []);
      expect(s.turns, 0);
      expect(s.latencyP50Ms, isNull);
      expect(s.successRate, 0);
      expect(s.meanTokens, 0);
    });
  });
}
