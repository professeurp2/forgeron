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
