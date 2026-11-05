/// Détecteur déterministe de langue et d'anti-dérive linguistique pour l'IA locale.
///
/// En mode local (`forgeron-qwen` / `qwen2.5:7b` sous Ollama), les résultats
/// d'outils (`role: 'tool'`) contiennent des clés JSON techniques en anglais
/// (`status`, `error`, `nc_path`, `bounding_box`), ce qui provoque fréquemment
/// une bascule du modèle vers l'anglais alors que l'opérateur a posé sa
/// question en français (voir `scratch/test_lang.py`).
///
/// Ce module fournit :
/// 1. Une détection déterministe de la langue du message de l'opérateur (pour
///    ne pas laisser le mode `auto` deviner sur le JSON d'un outil).
/// 2. Une détection fiable de la dérive vers l'anglais (`isEnglishDrift`) hors
///    blocs de G-code et termes techniques CNC légitimes.
class LanguageDetector {
  LanguageDetector._();

  static final RegExp _cjkRegex = RegExp(r'[　-〿㐀-䶿一-鿿＀-￯]');
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _ethiopicRegex = RegExp(r'[\u1200-\u137F]');
  static final RegExp _frenchAccentsRegex = RegExp(r'[éèêëàâùûçœîïô]', caseSensitive: false);
  static final RegExp _codeBlockRegex = RegExp(r'```[\s\S]*?```');

  /// Mots-témoins des langues africaines proposées par l'application.
  ///
  /// Choisis pour ne pas exister en français ni en anglais : salutations,
  /// politesse, « machine », « maintenant », « langue », verbes d'atelier
  /// courants. Pas de mot de deux lettres — ils se recoupent d'une langue à
  /// l'autre (« ni », « na », « ya ») et avec le français. Un seul détecteur
  /// pour toute l'application : avant, le prompt en avait deux qui ne
  /// s'accordaient pas, et aucun ne connaissait le wolof ni le haoussa — leurs
  /// opérateurs recevaient l'ordre « réponds en français » (banc
  /// `tool/eval/conversation_langues_test.dart`, 5 nov. 2026).
  static const Map<String, Set<String>> _africanWords = {
    'bm': {
      'mansin', 'mashini', 'daminɛ', 'damine', 'dabila', 'cogoya', 'joona',
      'sisan', 'milimɛtɛri', 'milimeteri', 'numan', 'kinibolo', 'segin',
      'bamanankan', 'porogaramu', 'bɛ', 'kɛ', 'tɛ', 'yɛlɛma', 'barika',
      'joli', 'munna', 'aw', 'kana', 'ɲɛ', 'fɛ',
    },
    'sw': {
      'habari', 'tafadhali', 'asante', 'mashine', 'hali', 'sasa', 'unaweza',
      'kunisaidia', 'nini', 'washa', 'zima', 'lugha', 'programu',
      'badilisha', 'ikoje', 'hivi', 'ninaweza', 'kwa', 'sana', 'kiswahili',
      'nataka', 'tafadhal', 'ondoa', 'anza', 'simama',
    },
    'wo': {
      'naka', 'nga', 'ngir', 'dafa', 'mënn', 'mën', 'léegi', 'leegi', 'waaw',
      'deedeet', 'jërëjëf', 'jerejef', 'dama', 'bëgg', 'begg', 'masin',
      'wolof', 'nanga', 'mel', 'def', 'lan', 'sama', 'tàmbali', 'tambali',
    },
    'ha': {
      'sannu', 'yaya', 'yanzu', 'injin', 'iya', 'wannan', 'kunna', 'kashe',
      'nagode', 'hausa', 'yanayin', 'harshen', 'ina', 'kana', 'allah',
      'zan', 'mana', 'canza',
    },
    'yo': {
      'bawo', 'jọwọ', 'jowo', 'ẹrọ', 'nisisiyi', 'ṣe', 'kaabo', 'yoruba',
      'yorùbá', 'fẹ', 'tàn', 'pàá', 'ìlú', 'èdè', 'yipada',
    },
    'ig': {
      'kedu', 'biko', 'ndewo', 'igwe', 'daalụ', 'daalu', 'ugbu', 'igbo',
      'achọrọ', 'chọrọ', 'gbanwee', 'mụnye', 'gbanyụọ',
    },
    'zu': {
      'sawubona', 'ngicela', 'umshini', 'manje', 'ngiyabonga', 'yebo',
      'vula', 'cisha', 'isizulu', 'ulimi', 'shintsha', 'kanjani', 'unjani',
    },
    'so': {
      'fadlan', 'mashiinka', 'hadda', 'mahadsanid', 'warran', 'sidee',
      'soomaali', 'luqadda', 'bedel', 'shid', 'dami', 'iska',
    },
    'rw': {
      'muraho', 'mwaramutse', 'murakoze', 'imashini', 'ubu', 'nonaha',
      'mbabarira', 'ndashaka', 'kinyarwanda', 'ururimi', 'hindura',
      'fungura', 'zimya',
    },
    'sn': {
      'mhoro', 'mhoroi', 'ndapota', 'ndatenda', 'muchina', 'zvino', 'ndiri',
      'chishona', 'mutauro', 'chinja', 'batidza', 'dzima',
    },
    'ln': {
      'mbote', 'nalingi', 'sikoyo', 'matondi', 'masini', 'lisusu', 'olingi',
      'lingala', 'lokota', 'bongola', 'pelisa', 'boma', 'ndenge',
    },
    'mg': {
      'manao', 'ahoana', 'misaotra', 'azafady', 'milina', 'ankehitriny',
      'malagasy', 'fiteny', 'ovay', 'alefaso', 'vonoy', 'aho', 'tiako',
    },
    'af': {
      'asseblief', 'dankie', 'masjien', 'goeie', 'jy', 'ek', 'nou', 'afrikaans',
      'taal', 'verander', 'skakel', 'hoe', 'wat',
    },
  };

  /// Lettres propres à une orthographe : un mot qui en porte compte pour elle.
  static final Map<String, RegExp> _africanLetters = {
    'bm': RegExp('[ɛɔɲŋƐƆƝŊ]'),
    'yo': RegExp('[ẹọṣẸỌṢ]'),
    'ig': RegExp('[ịụỊỤ]'),
    'wo': RegExp('[ëñË]'),
  };

  static final RegExp _tokenSplit = RegExp(r"[^\p{L}\p{M}]+", unicode: true);

  /// Score de chaque langue africaine sur ce texte (mots-témoins + lettres).
  static Map<String, int> _africanScores(String text) {
    final tokens = text
        .toLowerCase()
        .split(_tokenSplit)
        .where((t) => t.isNotEmpty)
        .toList();
    final scores = <String, int>{};
    for (final e in _africanWords.entries) {
      var n = tokens.where(e.value.contains).length;
      final letters = _africanLetters[e.key];
      if (letters != null) {
        n += tokens
            .where((t) => !e.value.contains(t) && letters.hasMatch(t))
            .length;
      }
      if (n > 0) scores[e.key] = n;
    }
    // « i ni ce » / « aw ni ce » : la salutation bambara, faite de mots trop
    // courts pour figurer seuls dans la liste.
    if (RegExp(r'\b(i|aw) ni (ce|sogoma|tile|wula|su)\b')
        .hasMatch(text.toLowerCase())) {
      scores['bm'] = (scores['bm'] ?? 0) + 2;
    }
    return scores;
  }

  /// Mots-outils et verbes fréquents en français.
  static final RegExp _frenchWords = RegExp(
    r"\b(je|tu|il|nous|vous|le|la|les|un|une|des|du|de|dans|pour|avec|sur|sans|est|sont|fait|faire|charge|charger|prépare|preparer|génère|generer|fichier|pièce|piece|broche|outil|alarme|erreur|pourquoi|comment|qu'est|quel|quelle|déplace|deplace|arrête|arrete|démarrer|demarrer|usinage|finition|ébauche|ebauche|origine|palpage|vitesse|avance|merci|bonjour|salut|peux|veux|vérifie|verifie|montre|ouvre)\b",
    caseSensitive: false,
  );

  /// Mots-outils et structures typiques de l'anglais.
  static final RegExp _englishWords = RegExp(
    r'\b(the|and|with|from|this|that|what|where|when|while|attempting|encountered|please|check|unable|successfully|however|because|would|could|should|have|has|had|been|were|was|there|their|about|after|before|between|through|during|without|within|machine|spindle|toolpath|loading|generated|error|failed|file|make|sure)\b',
    caseSensitive: false,
  );

  /// Expressions anglaises caractéristiques d'une dérive post-outil d'un LLM local.
  static final RegExp _englishDriftPhrases = RegExp(
    r'(\bI encountered\b|\bwhile attempting\b|\bI have\b|\bI am\b|\bI cannot\b|\bI can\b|\bHere is\b|\bHere are\b|\bThe machine\b|\bThe file\b|\bPlease check\b|\bPlease make sure\b|\bUnable to\b|\bIt seems\b|\bLet me\b|\bSuccessfully\b|\bAn error occurred\b|\bThere is\b|\bThere was\b|\bYou can\b|\bTo resolve this\b)',
    caseSensitive: false,
  );

  /// Détecte le code ISO 639-1 probable d'un message de l'opérateur, parmi
  /// les langues de l'application (plus `zh`, pour signaler du chinois).
  /// Retombe sur [fallback] si le message est très court ou purement composé
  /// de G-code / coordonnées numériques.
  static String detectOperatorLanguage(String text, {String fallback = 'fr'}) {
    final cleaned = text.replaceAll(_codeBlockRegex, ' ').trim();
    if (cleaned.isEmpty) return fallback;

    if (_cjkRegex.hasMatch(cleaned)) return 'zh';
    if (_arabicRegex.hasMatch(cleaned)) return 'ar';
    if (_ethiopicRegex.hasMatch(cleaned)) return 'am';

    final frWords = _frenchWords.allMatches(cleaned).length;
    final enMatches = _englishWords.allMatches(cleaned).length;

    // Langues africaines : deux mots-témoins suffisent ; un seul aussi, tant
    // que la phrase ne porte pas plus d'un mot-outil français ou anglais.
    // C'est le parler d'atelier : « Broche daminɛ », « Washa spindle ».
    final african = _africanScores(cleaned);
    if (african.isNotEmpty) {
      final best = african.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final latin = frWords + enMatches;
      if ((best.value >= 2 && best.value * 2 >= latin) || latin <= 1) {
        return best.key;
      }
    }

    final frMatches =
        frWords + (_frenchAccentsRegex.hasMatch(cleaned) ? 2 : 0);

    if (frMatches == 0 && enMatches == 0) {
      return fallback;
    }
    if (frMatches >= enMatches) {
      return 'fr';
    }
    return 'en';
  }

  /// Vrai si [replyText] est manifestement rédigé en anglais alors que la
  /// langue attendue [expectedLangCode] n'est pas l'anglais (ex. `'fr'`).
  static bool isEnglishDrift(
    String replyText, {
    required String expectedLangCode,
  }) {
    if (expectedLangCode == 'en') return false;

    // Retire les blocs de code (G-code, JSON) pour ne juger que la prose.
    final prose = replyText.replaceAll(_codeBlockRegex, ' ').trim();
    if (prose.length < 15) return false;

    // 1. Présence d'une tournure anglaise typique de début/corps de réponse LLM
    if (_englishDriftPhrases.hasMatch(prose)) {
      final frCount = _frenchWords.allMatches(prose).length;
      final enCount = _englishWords.allMatches(prose).length;
      if (enCount > frCount) return true;
    }

    // 2. Ratio de mots-outils anglais vs français sur une réponse d'au moins 6 mots
    final enCount = _englishWords.allMatches(prose).length;
    final frCount = _frenchWords.allMatches(prose).length +
        (_frenchAccentsRegex.allMatches(prose).length > 2 ? 2 : 0);

    if (enCount >= 4 && enCount >= (frCount * 2 + 1)) {
      return true;
    }
    return false;
  }

  // ── Dérive hors de la langue cible ─────────────────────────────────────────
  //
  // Banc de conversation, 5 nov. 2026 : une réponse en arabe repassait au
  // français à mi-chemin (« Position de la pièce… Système de Coordonnées
  // Actif… »), une réponse en bambara finissait en « Pourrais-tu reformuler ta
  // demande en français ? ». Le garde-fou ne connaissait que le chinois et
  // « de l'anglais au lieu du français ».

  /// Mots grammaticaux qui ne sont QUE français — ni « la », « le », « de »,
  /// « ne », « ta », « tu », « si » : ce sont aussi des mots bambara, wolof,
  /// haoussa, swahili ou yoruba.
  static const Set<String> _frOnlyWords = {
    'les', 'une', 'des', 'est', 'sont', 'pour', 'dans', 'avec', 'vous',
    'nous', 'pas', 'cette', 'qui', 'que', 'sur', 'aux', 'du', 'et', 'il',
    'je', 'un', 'au', 'votre', 'vos', 'notre', 'mais', 'afin', 'mieux',
    'plus', 'très', 'peux', 'pouvez', 'voulez', 'avez', 'être', 'cela',
    'comme', 'aussi', 'bien', 'alors', 'encore', 'pourrais', 'pourriez',
    'souhaitez', 'actuellement', 'maintenant', 'comprends', 'question',
    'demande', 'reformuler', 'préciser', 'merci', 'désolé', 'aucune',
    'aucun', 'été', 'ont', 'sera',
  };

  /// Mots grammaticaux qui ne sont QU'anglais (pas « to » : « to » est le
  /// « d'accord » haoussa).
  static const Set<String> _enOnlyWords = {
    'the', 'is', 'are', 'and', 'you', 'your', 'with', 'this', 'that', 'of',
    'will', 'can', 'have', 'has', 'it', 'for', 'here', 'please', 'would',
    'could', 'should', 'been', 'there', 'which',
  };

  /// Libellés cités, code en ligne : la règle demande de citer les boutons
  /// tels qu'affichés, souvent en français — ce n'est pas une dérive.
  static final RegExp _quoted = RegExp(r'«[^»]*»|“[^”]*”|"[^"]*"|`[^`]*`');

  static final RegExp _latinWord = RegExp(r'^[a-zà-öø-ÿœ]{2,}$');

  /// Vrai si [reply] a quitté la langue cible [targetId] (code de
  /// l'application) pour du français ou de l'anglais. Le français cible est
  /// laissé à [isEnglishDrift]. Seuils volontairement hauts : une fausse
  /// alerte coûte une génération de plus, pas davantage, mais une langue
  /// peu dotée mêle légitimement des mots d'atelier français.
  static bool driftsFromLanguage(String reply, String targetId) {
    if (targetId == 'fr') return false;
    final prose =
        reply.replaceAll(_codeBlockRegex, ' ').replaceAll(_quoted, ' ');
    if (prose.trim().length < 30) return false;

    // Écritures non latines : la part de mots latins suffit. On écarte les
    // sigles et ce qui porte des chiffres (WCS, G54, OFFLINE, X10…).
    if (targetId == 'ar' || targetId == 'am') {
      final script = targetId == 'ar' ? _arabicRegex : _ethiopicRegex;
      final tokens =
          prose.split(_tokenSplit).where((t) => t.isNotEmpty).toList();
      final native = tokens.where(script.hasMatch).length;
      final latin = tokens
          .where((t) => t != t.toUpperCase() && _latinWord.hasMatch(t.toLowerCase()))
          .length;
      return latin >= 8 && latin * 3 >= native;
    }

    // Écritures latines : phrase par phrase, pour qu'une fin de réponse en
    // français ne soit pas noyée par un début dans la bonne langue.
    var foreign = 0;
    var total = 0;
    for (final sentence in prose.split(RegExp(r'[.!?\n:;]+'))) {
      final tokens = sentence
          .toLowerCase()
          .split(_tokenSplit)
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.length < 3) continue;
      total++;
      final fr = tokens.where(_frOnlyWords.contains).length;
      final en =
          targetId == 'en' ? 0 : tokens.where(_enOnlyWords.contains).length;
      if (fr >= 3 || en >= 3) foreign++;
    }
    return foreign >= 2 || (foreign == 1 && total <= 2);
  }
}

