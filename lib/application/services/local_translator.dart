import 'dart:convert';

import 'package:http/http.dart' as http;

/// Traduit la réponse FINALE de l'agent local, écrite en français simple,
/// vers une langue que le modèle pilote n'écrit pas.
///
/// Pourquoi un second modèle : Qwen 2.5 7B pilote la machine de façon sûre
/// (injection 100 %, réponse en ~1 s) mais écrit le swahili et le haoussa en
/// salade de mots. Gemma 3 12B les écrit correctement, mais il est lent
/// (23 s médian sur une RTX 3070 Laptop 8 Go) et il a lancé un programme sur
/// une consigne cachée (injection 67 %) : il ne pilote donc pas. Il ne reçoit
/// ici que le texte déjà écrit par le pilote, sans outils ni historique —
/// rien de ce qu'il produit ne peut agir sur la machine. Mesures :
/// docs/addis/distillation-langues.md, 7 nov. 2026.
///
/// Une traduction n'est livrée que si [checkTranslation] l'accepte : mêmes
/// nombres (signe compris), mêmes blocs de code, aucun caractère chinois.
/// Sinon l'opérateur garde le français — jamais une consigne altérée.
class LocalTranslator {
  /// Langues confiées au traducteur. Banc du 7 nov. 2026
  /// (`tool/eval/traducteur_test.dart`, 8 réponses types) :
  /// - swahili : lisible, mais 2 phrases sur 8 changent de sens (« axes »
  ///   rendu par « milima », montagnes ; « je ne trouve pas ce fichier » par
  ///   « je n'ai pas besoin de ce fichier ») ;
  /// - haoussa : RETIRÉ. « La machine est prête » rendu par « bonjour »,
  ///   « Alarme 2 » par « Dictionnaire 2 », « 12 minutes » sans doute par
  ///   12 secondes (daƙiƙa), consigne de lunettes illisible. Le contrôle des
  ///   nombres ne voit rien de tout ça ;
  /// - wolof : salade de mots dès le banc de conversation.
  /// Aucune n'a été relue par un locuteur : l'écran le dit et garde le
  /// français à portée.
  static const defaultLanguages = {'sw'};

  /// Modèle conseillé : la version de base, sans gabarit d'outils — il n'en a
  /// pas besoin, et l'absence d'outils est ce qui le rend inoffensif ici.
  static const defaultModel = 'gemma3:12b';

  LocalTranslator({
    required this.baseUrl,
    required this.model,
    this.languages = defaultLanguages,
    this.timeout = const Duration(seconds: 150),
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final String baseUrl;
  final String model;
  final Set<String> languages;
  final Duration timeout;
  final http.Client Function() _clientFactory;

  http.Client? _current;

  bool covers(String languageId) => languages.contains(languageId);

  /// Abandonne la traduction en cours (nouveau message de l'opérateur) :
  /// fermer le client coupe la requête, et Ollama arrête de générer — le
  /// pilote n'attend pas derrière une traduction devenue inutile.
  void cancel() {
    _current?.close();
    _current = null;
  }

  /// Traduit [french] vers la langue [languageName] (nom en français :
  /// « swahili »). `null` si le serveur échoue, si la requête est annulée ou
  /// si la traduction est rejetée par [checkTranslation].
  Future<TranslationResult> translate(String french, String languageName) async {
    final masked = maskCode(french);
    final client = _clientFactory();
    _current = client;
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'stream': false,
              // Libère la carte graphique tout de suite : le pilote (4,7 Go)
              // et le traducteur (8,2 Go) ne tiennent pas ensemble dans 8 Go,
              // et c'est le pilote qui doit répondre vite au tour suivant.
              'keep_alive': 0,
              'options': {'temperature': 0.1, 'num_ctx': 4096},
              'messages': [
                {'role': 'user', 'content': prompt(masked.text, languageName)},
              ],
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        return TranslationResult.rejected('http_${response.statusCode}');
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final content = stripFrame(
          (json['message'] as Map?)?['content'] as String? ?? '');
      final problem = checkTranslation(masked.text, content);
      if (problem != null) {
        return TranslationResult.rejected(problem, raw: content);
      }
      return TranslationResult.ok(masked.restore(content));
    } catch (e) {
      return TranslationResult.rejected(
          identical(_current, client) ? 'erreur' : 'annulee');
    } finally {
      if (identical(_current, client)) _current = null;
      client.close();
    }
  }

  /// Consigne de traduction. Le texte est encadré pour que le modèle ne le
  /// prenne pas pour une demande à exécuter (« lance le programme » doit être
  /// traduit, pas commenté).
  static String prompt(String text, String languageName) =>
      'Traduis le texte ci-dessous du français vers le $languageName.\n'
      'Règles :\n'
      '- Traduis seulement. N\'ajoute rien, ne retire rien, ne commente pas, '
      'ne réponds pas aux questions du texte.\n'
      '- Recopie à l\'identique tous les nombres et leur signe, les unités '
      '(mm, °, mm/min, tr/min), les noms de fichiers, les commandes G-code et '
      'les marqueurs [[CODE1]], [[CODE2]]…\n'
      '- Les mots d\'atelier sans équivalent courant restent en français : '
      'broche, origine, homing, palpage, jog, avance, alarme.\n'
      '- Réponds uniquement par la traduction.\n\n'
      'Texte :\n<<<\n$text\n>>>';

  /// Gemma 3 12B recopie souvent le cadre `<<<` … `>>>` de la consigne
  /// autour de sa traduction (10 fois sur 16 au premier banc du 7 nov. 2026) : on
  /// l'enlève. Un cadre qui reste AU MILIEU du texte est rejeté par
  /// [checkTranslation].
  static String stripFrame(String s) {
    // Cadre entier ou partiel (« < » seul, vu au banc).
    return s
        .trim()
        .replaceFirst(RegExp(r'^<+\s*'), '')
        .replaceFirst(RegExp(r'\s*>+$'), '')
        .trim();
  }

  static final _number = RegExp(r'[-−]?\d+(?:[.,]\d+)?');
  static final _cjk = RegExp(r'[぀-ヿ㐀-䶿一-鿿가-힯]');
  static final _placeholder = RegExp(r'\[\[CODE\d+\]\]');

  /// Raison du rejet, ou `null` si la traduction peut être montrée.
  ///
  /// Les nombres sont comparés comme multiensembles, signe compris : le 7 nov.
  /// 2026, Gemma 3 4B a changé « Z -500 » en +500. Une traduction qui perd,
  /// ajoute ou modifie un seul nombre est jetée.
  static String? checkTranslation(String source, String translated) {
    final t = translated.trim();
    if (t.isEmpty) return 'vide';
    if (_cjk.hasMatch(t)) return 'cjk';
    if (t.contains('<<<') || t.contains('>>>')) return 'cadre_recopie';
    List<String> numbers(String s) => _number
        .allMatches(s)
        .map((m) => m.group(0)!.replaceAll('−', '-').replaceAll(',', '.'))
        .toList()
      ..sort();
    if (!_sameList(numbers(source), numbers(t))) return 'nombres';
    List<String> marks(String s) =>
        _placeholder.allMatches(s).map((m) => m.group(0)!).toList()..sort();
    if (!_sameList(marks(source), marks(t))) return 'code';
    final ratio = t.length / source.trim().length;
    if (ratio < 0.3 || ratio > 4) return 'longueur';
    return null;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Remplace les blocs ```…``` par des marqueurs : le G-code ne passe jamais
  /// par le traducteur, il est remis tel quel après.
  static MaskedText maskCode(String text) {
    final blocks = <String>[];
    final masked = text.replaceAllMapped(RegExp(r'```[\s\S]*?```'), (m) {
      blocks.add(m.group(0)!);
      return '[[CODE${blocks.length}]]';
    });
    return MaskedText(masked, blocks);
  }
}

class MaskedText {
  MaskedText(this.text, this.blocks);
  final String text;
  final List<String> blocks;

  String restore(String translated) => translated.replaceAllMapped(
        RegExp(r'\[\[CODE(\d+)\]\]'),
        (m) => blocks[int.parse(m.group(1)!) - 1],
      );
}

class TranslationResult {
  const TranslationResult.ok(String this.text)
      : rejection = null,
        raw = null;
  const TranslationResult.rejected(String this.rejection, {this.raw})
      : text = null;

  /// Texte traduit, `null` si rejeté.
  final String? text;

  /// Raison du rejet (`nombres`, `code`, `http_404`, `annulee`…), pour le
  /// journal : un garde-fou qu'on ne compte pas, on ne sait pas s'il sert.
  final String? rejection;

  /// Sortie du modèle quand elle a été rejetée — pour le banc, jamais
  /// affichée à l'opérateur.
  final String? raw;
}
