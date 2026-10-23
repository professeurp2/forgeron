import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/storage/prefs_guard.dart';

/// Le 21 octobre 2026, un arrêt brutal du PC a laissé `shared_preferences.json`
/// à sa taille normale (81 229 octets), rempli de zéros : réglages, discussions
/// et macros perdus d'un coup. Ces tests rejouent exactement ce cas.
void main() {
  late Directory dir;
  late PrefsFileGuard guard;
  var now = DateTime.now();

  List<int> prefs([Map<String, Object> extra = const {}]) => utf8.encode(jsonEncode({
        'flutter.esp_ip': '192.168.88.1',
        'flutter.ai_local_url': 'http://localhost:11434',
        ...extra,
      }));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('prefs_guard_');
    now = DateTime.now();
    guard = PrefsFileGuard(dir.path, clock: () => now);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last).toList()
        ..sort();

  group('inspect', () {
    test('reconnaît chaque état', () {
      expect(PrefsFileGuard.inspect(prefs()), PrefsFileState.valid);
      expect(PrefsFileGuard.inspect(const []), PrefsFileState.empty);
      expect(PrefsFileGuard.inspect(utf8.encode('  \n ')), PrefsFileState.empty);
      expect(PrefsFileGuard.inspect(List.filled(81229, 0)), PrefsFileState.zeroed,
          reason: 'le cas du 21 octobre : taille normale, contenu nul');
      expect(PrefsFileGuard.inspect(utf8.encode('{"a": ')), PrefsFileState.invalid);
      expect(PrefsFileGuard.inspect(utf8.encode('[1,2,3]')), PrefsFileState.invalid,
          reason: 'du JSON, mais pas un objet');
      expect(PrefsFileGuard.inspect(const [0xff, 0xfe, 0x00]), PrefsFileState.invalid);
    });
  });

  group('restoreIfNeeded', () {
    test('fichier sain : rien ne bouge', () async {
      await guard.main.writeAsBytes(prefs());
      final r = await guard.restoreIfNeeded();
      expect(r.action, PrefsGuardAction.none);
      expect(names(), ['shared_preferences.json']);
    });

    test('fichier absent : laissé absent, même s\'il existe des copies', () async {
      await guard.backup.writeAsBytes(prefs());
      final r = await guard.restoreIfNeeded();
      expect(r.action, PrefsGuardAction.leftMissing);
      expect(await guard.main.exists(), isFalse,
          reason: 'une suppression voulue ne doit pas être défaite');
    });

    test('rempli de zéros + copie saine : restauré, et la preuve est gardée',
        () async {
      final good = prefs({'flutter.macros': '[1,2]'});
      await guard.main.writeAsBytes(good);
      expect(await guard.backupIfValid(), isTrue);

      // L'arrêt brutal.
      await guard.main.writeAsBytes(List.filled(good.length, 0));

      final r = await guard.restoreIfNeeded();
      expect(r.action, PrefsGuardAction.restored);
      expect(r.state, PrefsFileState.zeroed);
      expect(r.restoredFrom, 'shared_preferences.json.bak');
      expect(r.keys, 3);
      expect(await guard.main.readAsBytes(), good);
      expect(names().where((n) => n.contains('.corrupt-')), hasLength(1),
          reason: 'le fichier fautif est conservé pour analyse');
    });

    test('JSON tronqué + copie saine : restauré', () async {
      await guard.main.writeAsBytes(prefs());
      await guard.backupIfValid();
      await guard.main.writeAsString('{"flutter.esp_ip": "192.16');
      final r = await guard.restoreIfNeeded();
      expect(r.action, PrefsGuardAction.restored);
      expect(r.state, PrefsFileState.invalid);
    });

    test('fichier vide + copie saine : restauré', () async {
      await guard.main.writeAsBytes(prefs());
      await guard.backupIfValid();
      await guard.main.writeAsBytes(const []);
      expect((await guard.restoreIfNeeded()).action, PrefsGuardAction.restored);
    });

    test('copie récente abîmée aussi : repli sur la copie du jour', () async {
      final daily = prefs({'flutter.theme': 'dark'});
      await guard.dailyBackup.writeAsBytes(daily);
      await guard.backup.writeAsBytes(List.filled(50, 0));
      await guard.main.writeAsBytes(List.filled(50, 0));
      final r = await guard.restoreIfNeeded();
      expect(r.action, PrefsGuardAction.restored);
      expect(r.restoredFrom, 'shared_preferences.json.daily.bak');
      expect(await guard.main.readAsBytes(), daily);
    });

    test('corrompu et aucune copie : écarté, pour un démarrage propre', () async {
      await guard.main.writeAsBytes(List.filled(100, 0));
      final r = await guard.restoreIfNeeded();
      expect(r.action, PrefsGuardAction.setAside);
      expect(await guard.main.exists(), isFalse);
      expect(names().where((n) => n.contains('.corrupt-')), hasLength(1));
    });

    test('ne garde que les trois dernières preuves', () async {
      for (var i = 0; i < 5; i++) {
        now = DateTime(2026, 10, 22, 10, i);
        await guard.main.writeAsBytes(List.filled(100 + i, 0));
        await guard.restoreIfNeeded();
      }
      expect(names().where((n) => n.contains('.corrupt-')), hasLength(3));
    });
  });

  group('backupIfValid', () {
    test('copie un fichier sain, sans laisser de fichier temporaire', () async {
      await guard.main.writeAsBytes(prefs());
      expect(await guard.backupIfValid(), isTrue);
      expect(await guard.backup.readAsBytes(), prefs());
      expect(await guard.dailyBackup.readAsBytes(), prefs());
      expect(names().where((n) => n.endsWith('.tmp')), isEmpty);
    });

    test('un fichier corrompu n\'écrase JAMAIS une bonne copie', () async {
      await guard.main.writeAsBytes(prefs());
      await guard.backupIfValid();
      await guard.main.writeAsBytes(List.filled(200, 0));
      expect(await guard.backupIfValid(), isFalse);
      expect(await guard.backup.readAsBytes(), prefs());
    });

    test('un objet vide non plus', () async {
      await guard.main.writeAsBytes(prefs());
      await guard.backupIfValid();
      await guard.main.writeAsString('{}');
      expect(await guard.backupIfValid(), isFalse);
      expect(await guard.backup.readAsBytes(), prefs());
    });

    test('pas de fichier : rien à copier', () async {
      expect(await guard.backupIfValid(), isFalse);
    });

    test('la copie « du jour » ne change pas dans la journée, puis se renouvelle',
        () async {
      await guard.main.writeAsBytes(prefs());
      await guard.backupIfValid();
      final first = await guard.dailyBackup.readAsBytes();

      // Même jour : la copie récente suit, pas celle du jour.
      final changed = prefs({'flutter.x': '1'});
      await guard.main.writeAsBytes(changed);
      await guard.backupIfValid();
      expect(await guard.backup.readAsBytes(), changed);
      expect(await guard.dailyBackup.readAsBytes(), first);

      // Le lendemain : renouvelée. On vieillit la copie du jour de 24 h.
      await guard.dailyBackup
          .setLastModified(DateTime.now().subtract(const Duration(days: 1)));
      now = DateTime.now();
      await guard.backupIfValid();
      expect(await guard.dailyBackup.readAsBytes(), changed);
    });
  });

  test('de bout en bout : sauvegarde, coupure brutale, restauration', () async {
    final good = prefs({'flutter.ai_conversation_1': List.filled(2000, 'x').join()});
    await guard.main.writeAsBytes(good);
    await guard.backupIfValid();

    await guard.main.writeAsBytes(List.filled(good.length, 0)); // 21 octobre
    expect(await guard.restoreIfNeeded(), isA<PrefsGuardReport>().having((r) => r.action, 'action', PrefsGuardAction.restored));

    // Redémarrage suivant : le fichier est sain, plus rien à faire.
    expect((await guard.restoreIfNeeded()).action, PrefsGuardAction.none);
    expect(await guard.main.readAsBytes(), good);
  });
}
