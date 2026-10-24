import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/live_state_block.dart';

void main() {
  final now = DateTime(2026, 10, 22, 9, 5, 7);
  const state = {
    'status': 'idle',
    'mPos': [12.0, 0.0, -3.25, 0.0, 0.0],
    'alarmCode': null,
  };

  test('machine en ligne : l\'état, l\'heure de lecture et la mise en garde', () {
    final b = liveStateBlock(state: state, offline: false, now: now);
    expect(b, contains('lu à 09:05:07'));
    expect(b, contains('SEULE lecture à jour'));
    expect(b, contains('PÉRIMÉ'));
    // Le JSON est dedans, intact.
    final json = b.substring(b.indexOf('{'));
    expect(jsonDecode(json)['mPos'], [12.0, 0.0, -3.25, 0.0, 0.0]);
  });

  test('hors ligne : AUCUNE valeur, jamais des zéros présentés comme une position',
      () {
    final b = liveStateBlock(state: state, offline: true, now: now);
    expect(b, contains('HORS LIGNE'));
    expect(b, contains('aucune lecture'));
    expect(b, isNot(contains('mPos')));
    expect(b, isNot(contains('12.0')));
  });

  test('état absent : traité comme hors ligne', () {
    final b = liveStateBlock(state: null, offline: false, now: now);
    expect(b, contains('HORS LIGNE'));
  });

  test('l\'heure est sur deux chiffres', () {
    final b = liveStateBlock(
        state: state, offline: false, now: DateTime(2026, 1, 1, 1, 2, 3));
    expect(b, contains('01:02:03'));
  });
}
