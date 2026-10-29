import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/speech_error_message.dart';

void main() {
  test('chaque cause a son message, et le code brut reste visible', () {
    final permission = speechErrorMessage('error_permission');
    expect(permission, contains('refusé'));
    expect(permission, endsWith('(code : error_permission)'));

    for (final c in ['error_network', 'error_server', 'error_network_timeout']) {
      expect(speechErrorMessage(c), contains('Internet'), reason: c);
    }
    expect(speechErrorMessage('error_no_match'), contains('Rien de clair'));
    expect(speechErrorMessage('error_language_unavailable'), contains('langue'));
  });

  test('un code inconnu ne se fait pas passer pour un micro absent', () {
    final m = speechErrorMessage('error_unknown (42)');
    expect(m, isNot(contains('micro')));
    expect(m, contains('error_unknown (42)'));
  });

  test('échec de démarrage : Windows et Android disent où regarder', () {
    expect(speechInitFailedMessage(windows: true), contains('Confidentialité'));
    expect(speechInitFailedMessage(windows: false), contains('dictée'));
    expect(speechInitFailedMessage(windows: true),
        isNot(contains('Aucun micro détecté')));
  });
}
