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

  /// Mots-clés fréquents d'atelier en bambara (orthographe standard et saisie téléphone).
  static final RegExp _bambaraMarkers = RegExp(
    r'\b(mansin|mashini|daminɛ|damine|dabila|cogoya|joona|sisan|milimɛtɛri|milimeteri|numan|kinibolo|segin|bamanankan|porogaramu)\b',
    caseSensitive: false,
  );

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

  /// Détecte le code ISO 639-1 probable d'un message de l'opérateur.
  /// Retombe sur [fallback] si le message est très court ou purement composé
  /// de G-code / coordonnées numériques.
  static String detectOperatorLanguage(String text, {String fallback = 'fr'}) {
    final cleaned = text.replaceAll(_codeBlockRegex, ' ').trim();
    if (cleaned.isEmpty) return fallback;

    if (_cjkRegex.hasMatch(cleaned)) return 'zh';
    if (_arabicRegex.hasMatch(cleaned)) return 'ar';
    if (_ethiopicRegex.hasMatch(cleaned)) return 'am';
    if (_bambaraMarkers.hasMatch(cleaned)) return 'bm';

    final frMatches = _frenchWords.allMatches(cleaned).length +
        (_frenchAccentsRegex.hasMatch(cleaned) ? 2 : 0);
    final enMatches = _englishWords.allMatches(cleaned).length;

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
}

