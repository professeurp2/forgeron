import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/services/local_translator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('checkTranslation', () {
    const fr = 'Déplace Z de -5 mm, puis lance la broche à 1000 tr/min.';

    test('accepte une traduction qui garde tous les nombres', () {
      expect(
        LocalTranslator.checkTranslation(
            fr, 'Sogeza Z kwa -5 mm, kisha washa broche kwa 1000 tr/min.'),
        isNull,
      );
    });

    test('rejette un signe inversé (Gemma 3 4B, 7 nov. 2026)', () {
      expect(
        LocalTranslator.checkTranslation(
            fr, 'Sogeza Z kwa 5 mm, kisha washa broche kwa 1000 tr/min.'),
        'nombres',
      );
    });

    test('rejette un nombre perdu ou ajouté', () {
      expect(LocalTranslator.checkTranslation(fr, 'Sogeza Z kwa -5 mm.'),
          'nombres');
      expect(
        LocalTranslator.checkTranslation(
            fr, 'Sogeza Z kwa -5 mm mara 2, washa broche kwa 1000 tr/min.'),
        'nombres',
      );
    });

    test('virgule et point décimaux sont le même nombre', () {
      expect(
        LocalTranslator.checkTranslation(
            'Avance de 2,5 mm.', 'Songa mbele 2.5 mm.'),
        isNull,
      );
    });

    test('rejette vide, chinois, cadre recopié', () {
      expect(LocalTranslator.checkTranslation(fr, '  '), 'vide');
      expect(LocalTranslator.checkTranslation('Bonjour', '你好'), 'cjk');
      expect(LocalTranslator.checkTranslation('Bonjour', '<<< Habari >>>'),
          'cadre_recopie');
    });

    test('rejette un marqueur de code perdu', () {
      expect(
        LocalTranslator.checkTranslation(
            'Voici le programme : [[CODE1]]', 'Hii ndiyo programu.'),
        'nombres', // le « 1 » du marqueur manque aussi
      );
      expect(
        LocalTranslator.checkTranslation(
            'Voici [[CODE1]] et 1 fichier.', 'Hii ni CODE1 na faili 1 [[CODE]].'),
        'code',
      );
    });
  });

  test('le G-code ne passe pas par le traducteur et revient intact', () {
    const text = 'Programme :\n```gcode\nG0 X10 Y-3\nM3 S1000\n```\nVérifie.';
    final masked = LocalTranslator.maskCode(text);
    expect(masked.text, isNot(contains('G0')));
    expect(masked.text, contains('[[CODE1]]'));
    expect(masked.restore('Programu:\n[[CODE1]]\nKagua.'),
        'Programu:\n```gcode\nG0 X10 Y-3\nM3 S1000\n```\nKagua.');
  });

  group('translate', () {
    LocalTranslator withReply(String content,
        {int status = 200, void Function(Map<String, dynamic>)? onBody}) {
      return LocalTranslator(
        baseUrl: 'http://pc:11434',
        model: 'gemma3:12b',
        clientFactory: () => MockClient((req) async {
          expect(req.url.toString(), 'http://pc:11434/api/chat');
          onBody?.call(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'message': {'role': 'assistant', 'content': content}
            })),
            status,
          );
        }),
      );
    }

    test('envoie le texte masqué, sans outils, et libère la carte', () async {
      late Map<String, dynamic> body;
      final t = withReply('Programu: [[CODE1]] Kagua.', onBody: (b) => body = b);
      final r = await t.translate(
          'Programme : ```\nG0 X10\n``` Vérifie.', 'swahili');
      expect(r.text, 'Programu: ```\nG0 X10\n``` Kagua.');
      expect(body['model'], 'gemma3:12b');
      expect(body['keep_alive'], 0);
      expect(body.containsKey('tools'), isFalse);
      final prompt = (body['messages'] as List).single['content'] as String;
      expect(prompt, contains('swahili'));
      expect(prompt, isNot(contains('G0 X10')));
    });

    test('traduction qui change un nombre : rejetée, pas de texte', () async {
      final r = await withReply('Sogeza Z kwa 500 mm.')
          .translate('Déplace Z de -500 mm.', 'swahili');
      expect(r.text, isNull);
      expect(r.rejection, 'nombres');
    });

    test('cadre <<< >>> recopié autour de la traduction : retiré', () async {
      final r = await withReply('<<<\nMashine iko tayari.\n>>>')
          .translate('La machine est prête.', 'swahili');
      expect(r.text, 'Mashine iko tayari.');
      final partial = await withReply('<\nWeka glasi.')
          .translate('Mets tes lunettes.', 'swahili');
      expect(partial.text, 'Weka glasi.');
    });

    test('modèle absent du serveur : rejet http_404', () async {
      final r = await withReply('', status: 404).translate('Bonjour.', 'haoussa');
      expect(r.text, isNull);
      expect(r.rejection, 'http_404');
    });
  });

  test('langues couvertes : swahili seulement (haoussa retiré au banc)', () {
    final t = LocalTranslator(baseUrl: 'http://pc:11434', model: 'gemma3:12b');
    expect(t.covers('sw'), isTrue);
    expect(t.covers('ha'), isFalse);
    expect(t.covers('wo'), isFalse);
    expect(t.covers('bm'), isFalse);
  });
}
