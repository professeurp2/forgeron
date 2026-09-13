import 'package:flutter/painting.dart';

/// Fragment d'une réponse de l'agent : prose, ou bloc de code délimité par
/// des ``` (le G-code est renvoyé sous cette forme, cf. prompt système).
class ChatBlock {
  final bool isCode;

  /// Langage annoncé après les ``` (`gcode`, `nc`…), en minuscules. Vide si
  /// l'agent n'en a pas précisé.
  final String lang;

  final String text;

  const ChatBlock(this.text, {this.isCode = false, this.lang = ''});
}

/// Langages qui désignent un programme machine → l'UI propose l'enregistrement
/// dans l'espace de travail.
const _gcodeLangs = {'gcode', 'g-code', 'nc', 'ngc', 'tap', 'cnc'};

final _fence = RegExp(r'```([a-zA-Z0-9_+#-]*)[ \t]*\r?\n?([\s\S]*?)```');
final _gcodeShape = RegExp(r'^\s*(G\d|M\d|N\d|T\d)', multiLine: true);

/// Découpe une réponse en blocs de prose et blocs de code.
///
/// Gère le cas d'un bloc encore **ouvert** : pendant le streaming, la clôture
/// n'est pas encore arrivée, et il faut quand même afficher le code en
/// monospace au lieu de le laisser en texte brut le temps de la génération.
List<ChatBlock> parseChatBlocks(String text) {
  final blocks = <ChatBlock>[];
  var last = 0;

  for (final m in _fence.allMatches(text)) {
    final prose = text.substring(last, m.start);
    if (prose.trim().isNotEmpty) blocks.add(ChatBlock(prose));
    blocks.add(ChatBlock(m[2] ?? '',
        isCode: true, lang: (m[1] ?? '').toLowerCase()));
    last = m.end;
  }

  if (last < text.length) {
    final rest = text.substring(last);
    final open = rest.indexOf('```');
    if (open < 0) {
      if (rest.trim().isNotEmpty) blocks.add(ChatBlock(rest));
    } else {
      final before = rest.substring(0, open);
      if (before.trim().isNotEmpty) blocks.add(ChatBlock(before));
      // Bloc non refermé : la 1re ligne porte le langage, le reste est du code.
      var body = rest.substring(open + 3);
      final nl = body.indexOf('\n');
      final lang = nl >= 0 ? body.substring(0, nl).trim() : '';
      body = nl >= 0 ? body.substring(nl + 1) : '';
      blocks.add(ChatBlock(body, isCode: true, lang: lang.toLowerCase()));
    }
  }

  if (blocks.isEmpty) blocks.add(ChatBlock(text));
  return blocks;
}

/// `true` si le bloc contient un programme machine : soit le langage l'annonce,
/// soit — à défaut d'annonce — le contenu en a la forme (G0, M3, N10, T1…).
bool looksLikeGcode(ChatBlock block) {
  if (_gcodeLangs.contains(block.lang)) return true;
  if (block.lang.isNotEmpty) return false;
  return _gcodeShape.hasMatch(block.text);
}

/// Rendu léger du markdown de l'assistant : **gras**, `code`, titres `#`,
/// puces, et nettoyage LaTeX (`$...$`, `\text{}`) → texte lisible. Sans
/// dépendance externe.
///
/// Partagé par l'écran mobile et la console desktop : les deux affichaient la
/// même prose, et une seule des deux savait la mettre en forme.
List<InlineSpan> chatProseSpans(
  String text, {
  TextStyle? codeStyle,
}) {
  var t = text
      .replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m[1] ?? '')
      .replaceAll(r'\times', ' × ')
      .replaceAll(r'\circ', '°')
      .replaceAll(r'\,', ' ')
      .replaceAll(r'$', '');

  // Puces en début de ligne (« * » ou « - » suivi d'un espace).
  t = t.replaceAllMapped(
      RegExp(r'(^|\n)[ \t]*[*-][ \t]+'), (m) => '${m[1]}  • ');

  // Titres markdown : l'agent en produit dans ses récapitulatifs. On garde le
  // texte, en gras, plutôt que de laisser les dièses à l'écran.
  final headings = <String>{};
  t = t.replaceAllMapped(RegExp(r'(^|\n)#{1,6}[ \t]+([^\n]+)'), (m) {
    headings.add(m[2]!);
    return '${m[1]}${m[2]}';
  });

  // `code` inline et **gras** partagent le même découpage : on scanne une
  // seule fois pour ne pas avoir à recomposer les fragments deux fois.
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|`([^`\n]+)`', dotAll: true);
  var last = 0;
  for (final m in pattern.allMatches(t)) {
    if (m.start > last) {
      _addPlain(spans, t.substring(last, m.start), headings);
    }
    if (m[1] != null) {
      spans.add(TextSpan(
          text: m[1], style: const TextStyle(fontWeight: FontWeight.bold)));
    } else {
      spans.add(TextSpan(text: m[2], style: codeStyle));
    }
    last = m.end;
  }
  if (last < t.length) _addPlain(spans, t.substring(last), headings);

  if (spans.isEmpty) spans.add(TextSpan(text: t));
  return spans;
}

/// Ajoute du texte simple, en mettant en gras les lignes qui étaient des
/// titres markdown avant nettoyage.
void _addPlain(List<InlineSpan> spans, String chunk, Set<String> headings) {
  if (chunk.isEmpty) return;
  if (headings.isEmpty) {
    spans.add(TextSpan(text: chunk));
    return;
  }
  for (final line in chunk.split('\n')) {
    final isHeading = headings.contains(line.trim());
    spans.add(TextSpan(
      text: line,
      style: isHeading ? const TextStyle(fontWeight: FontWeight.bold) : null,
    ));
    spans.add(const TextSpan(text: '\n'));
  }
  // Le découpage ci-dessus ajoute un saut de trop en fin de fragment.
  spans.removeLast();
}
