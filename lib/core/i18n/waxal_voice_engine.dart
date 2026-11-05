import 'language_detector.dart';
import '../utils/voice_locale.dart';

/// Profil vocal d'une langue africaine dans le catalogue **Google WAXAL**
/// (`https://huggingface.co/datasets/google/WaxalNLP`, licence **CC-BY-4.0**)
/// et les corpus partenaires (**RobotsMali / MALIBA-AI** pour le bambara).
class WaxalLanguageProfile {
  /// Code ISO 639-1 utilisé dans Forgeron (`sw`, `ha`, `yo`, `ig`, `ln`, `bm`…).
  final String appLangId;

  /// Code ISO 639-3 de la configuration sur Hugging Face (`google/WaxalNLP`).
  final String iso639_3;

  /// Nom de la langue.
  final String name;

  /// Identifiant du dataset Hugging Face de référence (licence CC-BY-4.0).
  final String huggingFaceDataset;

  /// Indique si la langue fait partie du corpus officiel `google/WaxalNLP`.
  final bool inGoogleWaxal;

  /// Indique si des enregistrements ASR (reconnaissance vocale) sont disponibles.
  final bool hasAsrSplit;

  /// Indique si des enregistrements TTS studio (synthèse vocale) sont disponibles.
  final bool hasTtsSplit;

  /// Base phonétique de repli (`fr-FR` ou `en-US`) lorsque l'OS (Windows SAPI
  /// ou Android TTS) ne possède aucune voix native installée pour cette langue.
  final String phoneticFallbackTag;

  /// Débit de parole recommandé (plus posé pour les langues à tons ou peu dotées).
  final double recommendedSpeechRate;

  const WaxalLanguageProfile({
    required this.appLangId,
    required this.iso639_3,
    required this.name,
    this.huggingFaceDataset = 'google/WaxalNLP',
    this.inGoogleWaxal = true,
    this.hasAsrSplit = true,
    this.hasTtsSplit = true,
    this.phoneticFallbackTag = 'fr-FR',
    this.recommendedSpeechRate = 0.46,
  });
}

/// Résultat prêt à être envoyé à `FlutterTts` après résolution de la voix
/// et adaptation phonétique du texte.
class PreparedVoiceUtterance {
  /// Code langue détecté ou résolu (`bm`, `fr`, `en`, `sw`, `yo`, etc.).
  final String languageId;

  /// Locale sélectionnée parmi les voix installées sur l'appareil (`fr-FR`, `sw-KE`…).
  final String? selectedVoiceLocale;

  /// `true` si l'appareil n'avait pas de voix native pour [languageId] et
  /// utilise une voix de repli (`fr-FR` ou `en-US`) avec transcription phonétique.
  final bool usesPhoneticFallback;

  /// Débit de lecture optimal pour `FlutterTts.setSpeechRate`.
  final double speechRate;

  /// Texte nettoyé et adapté phonétiquement pour une lecture vocale fluide.
  final String spokenText;

  /// Profil WAXAL / Hugging Face associé s'il s'agit d'une langue africaine.
  final WaxalLanguageProfile? waxalProfile;

  const PreparedVoiceUtterance({
    required this.languageId,
    required this.selectedVoiceLocale,
    required this.usesPhoneticFallback,
    required this.speechRate,
    required this.spokenText,
    this.waxalProfile,
  });
}

/// Moteur d'intégration **WAXAL (`google/WaxalNLP`)** et de normalisation
/// phonétique multilingue pour la synthèse (TTS) et la dictée vocale (STT).
///
/// Résout deux problèmes majeurs constatés en atelier :
/// 1. Sur Windows (SAPI) et Android, les voix natives pour le bambara (`bm`),
///    le wolof (`wo`), le haoussa (`ha`), le yoruba (`yo`) ou le lingala (`ln`)
///    sont presque toujours absentes : `FlutterTts` retombe sur une voix
///    française ou anglaise qui épelle ou ignore les lettres africaines
///    (`ɛ`, `ɔ`, `ɲ`, `ŋ`, `ɓ`, `ɗ`, `ƙ`, `ẹ`, `ọ`, `ṣ`) et prononce à
///    contresens les graphèmes (`c` lu `/s/` au lieu de `/t͡ʃ/`, `j` lu `/ʒ/`
///    au lieu de `/d͡ʒ/`, `u` lu `/y/` au lieu de `/u/`, `-e` final muet).
/// 2. Les réponses de l'agent contiennent du markdown, des blocs G-code, des
///    symboles CNC (`$H`, `$X`, `G54`) et des émojis que le synthétiseur lit
///    mot à mot s'ils ne sont pas préparés.
class WaxalVoiceEngine {
  WaxalVoiceEngine._();

  /// Catalogue des langues africaines reliant Forgeron au corpus open-source
  /// **Google WAXAL** (`google/WaxalNLP`, CC-BY-4.0) et aux corpus partenaires.
  static const Map<String, WaxalLanguageProfile> kProfiles = {
    // ── Langues couvertes directement par Google WAXAL (google/WaxalNLP, CC-BY-4.0) ──
    'sw': WaxalLanguageProfile(
      appLangId: 'sw',
      iso639_3: 'swa',
      name: 'Kiswahili (Swahili)',
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.47,
    ),
    'ha': WaxalLanguageProfile(
      appLangId: 'ha',
      iso639_3: 'hau',
      name: 'Hausa',
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.45,
    ),
    'yo': WaxalLanguageProfile(
      appLangId: 'yo',
      iso639_3: 'yor',
      name: 'Yorùbá',
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.45,
    ),
    'ig': WaxalLanguageProfile(
      appLangId: 'ig',
      iso639_3: 'ibo',
      name: 'Igbo',
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.45,
    ),
    'ln': WaxalLanguageProfile(
      appLangId: 'ln',
      iso639_3: 'lin',
      name: 'Lingála',
      hasTtsSplit: false,
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.46,
    ),
    'sn': WaxalLanguageProfile(
      appLangId: 'sn',
      iso639_3: 'sna',
      name: 'chiShona',
      hasTtsSplit: false,
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.46,
    ),
    'mg': WaxalLanguageProfile(
      appLangId: 'mg',
      iso639_3: 'mlg',
      name: 'Malagasy',
      hasTtsSplit: false,
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.46,
    ),
    'ff': WaxalLanguageProfile(
      appLangId: 'ff',
      iso639_3: 'ful',
      name: 'Fulfulde / Pulaar (Peul)',
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.45,
    ),
    'ak': WaxalLanguageProfile(
      appLangId: 'ak',
      iso639_3: 'aka',
      name: 'Akan / Twi',
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.46,
    ),
    'ee': WaxalLanguageProfile(
      appLangId: 'ee',
      iso639_3: 'ewe',
      name: 'Eʋegbe (Éwé)',
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.46,
    ),
    'lg': WaxalLanguageProfile(
      appLangId: 'lg',
      iso639_3: 'lug',
      name: 'Luganda',
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.46,
    ),

    // ── Bambara & langues d'atelier associées (RobotsMali / MALIBA-AI + WAXAL ecosystem) ──
    'bm': WaxalLanguageProfile(
      appLangId: 'bm',
      iso639_3: 'bam',
      name: 'Bamanankan (Bambara)',
      huggingFaceDataset: 'RobotsMali/bam-asr-early',
      inGoogleWaxal: false,
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.44,
    ),
    'wo': WaxalLanguageProfile(
      appLangId: 'wo',
      iso639_3: 'wol',
      name: 'Wolof',
      huggingFaceDataset: 'galsenai/wolof-tts',
      inGoogleWaxal: false,
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.45,
    ),
    'am': WaxalLanguageProfile(
      appLangId: 'am',
      iso639_3: 'amh',
      name: 'አማርኛ (Amharique)',
      inGoogleWaxal: false,
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.46,
    ),
    'zu': WaxalLanguageProfile(
      appLangId: 'zu',
      iso639_3: 'zul',
      name: 'isiZulu',
      inGoogleWaxal: false,
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.46,
    ),
    'so': WaxalLanguageProfile(
      appLangId: 'so',
      iso639_3: 'som',
      name: 'Soomaali',
      inGoogleWaxal: false,
      phoneticFallbackTag: 'en-US',
      recommendedSpeechRate: 0.46,
    ),
    'rw': WaxalLanguageProfile(
      appLangId: 'rw',
      iso639_3: 'kin',
      name: 'Kinyarwanda',
      inGoogleWaxal: false,
      phoneticFallbackTag: 'fr-FR',
      recommendedSpeechRate: 0.46,
    ),
  };

  /// Mots français d'atelier (emprunts courants en bambara, wolof et lingala
  /// selon la règle du parler d'atelier) : ils ne doivent PAS subir la
  /// transformation graphème→phonème bambara (`u`→`ou`, `c`→`tch`, `-e`→`-é`)
  /// afin que la voix française les prononce naturellement.
  static final Set<String> _frenchAtelierWords = {
    'machine',
    'machines',
    'broche',
    'broches',
    'programme',
    'programmes',
    'homing',
    'jog',
    'origine',
    'origines',
    'palpage',
    'avance',
    'arrosage',
    'fichier',
    'fichiers',
    'outil',
    'outils',
    'axe',
    'axes',
    'alarme',
    'alarmes',
    'offset',
    'offsets',
    'vitesse',
    'pause',
    'urgence',
    'arrêt',
    'arret',
    'départ',
    'depart',
    'cycle',
    'course',
    'courses',
    'fin',
    'capteur',
    'capteurs',
    'sonde',
    'relais',
    'alimentation',
    'tension',
    'carte',
    'degré',
    'degrés',
    'millimètre',
    'millimètres',
    'minute',
    'seconde',
    'secondes',
    'code',
    'bloc',
    'ligne',
    'lignes',
    'état',
    'etat',
    'position',
    'zéro',
    'zero',
    'pièce',
    'piece',
    'brut',
    'fraise',
    'usinage',
    'finition',
    'ébauche',
    'ebauche',
    'commande',
    'commandes',
    'sécurité',
    'securite',
    'attention',
    'danger',
    'erreur',
    'ok',
    'oui',
    'non',
    'merci',
    'bonjour',
    'pour',
    'dans',
    'avec',
    'sans',
    'sur',
    'sous',
    'est',
    'sont',
    'pas',
    'plus',
    'moins',
  };

  /// Dictionnaire phonétique des mots et expressions bambara fréquents en
  /// atelier pour garantir une prononciation exacte sur un moteur TTS français.
  static const Map<String, String> _bambaraExactPhonetic = {
    'ce': 'tché',
    'cɛ': 'tchè',
    'bɛ': 'bè',
    'tɛ': 'tè',
    'kɛ': 'kè',
    'kɛra': 'kèra',
    'ye': 'yé',
    'se': 'ssé',
    'ne': 'né',
    'de': 'dé',
    'pe': 'pé',
    'fe': 'fé',
    'fɛ': 'fè',
    'ɲɛ': 'gnè',
    'ɲɛfɔ': 'gnèfò',
    'ɲɛfɛ': 'gnèfè',
    'kɔfɛ': 'kòfè',
    'jɔ': 'djò',
    'jɔra': 'djòra',
    'joona': 'djôna',
    'jira': 'djira',
    'jigin': 'djiguin',
    'segin': 'sséguin',
    'daminɛ': 'daminè',
    'dabila': 'dabila',
    'dɔɔnin': 'dônin',
    'cogoya': 'tchogoya',
    'mashini': 'machini',
    'mansin': 'mansin',
    'porogaramu': 'porogaramou',
    'milimɛtɛri': 'milimètèri',
    'teliya': 'téliya',
    'kelen': 'kélén',
    'fila': 'fila',
    'saba': 'ssaba',
    'naani': 'nâni',
    'duuru': 'dourou',
    'wooro': 'wôro',
    'wolonwula': 'wolon-woula',
    'seegin': 'sséguin',
    'kɔnɔntɔn': 'kònòntòn',
    'mugan': 'mougan',
    'kɛmɛ': 'kèmè',
    'waa': 'wâ',
    'sisan': 'ssissan',
    'sɔgɔma': 'ssògòma',
    'tile': 'tilé',
    'wula': 'woula',
    'mun': 'moun',
    'munna': 'mounna',
    'kuma': 'kouma',
    'nɔgɔman': 'nògòman',
    'numan': 'nouman',
    'kinin': 'kinin',
    'yɛlɛn': 'yèlèn',
    'yɔrɔ': 'yòrò',
    'bamanankan': 'bamanankan',
    'aw': 'aou',
    'anw': 'an-ou',
  };

  /// Prépare un message complet pour `FlutterTts` :
  /// 1. Détecte la langue réelle du texte (ex. réponse en bambara même si le
  ///    sélecteur est en mode `auto`).
  /// 2. Cherche une voix native installée sur l'appareil.
  /// 3. Si aucune voix native n'existe pour cette langue, sélectionne la voix
  ///    de repli (`fr-FR` ou `en-US`) et applique la transcription phonétique
  ///    adaptée pour éviter toute lecture hachée ou erronée.
  static PreparedVoiceUtterance prepareForTts(
    String rawText, {
    required String preferredLanguageId,
    required Iterable<String> availableVoices,
  }) {
    // 1. Détection de la langue réelle du texte à prononcer
    final fallbackId =
        (preferredLanguageId.isEmpty || preferredLanguageId == 'auto')
            ? 'fr'
            : preferredLanguageId;
    final detectedId = LanguageDetector.detectOperatorLanguage(
      rawText,
      fallback: fallbackId,
    );
    final langId = (preferredLanguageId != 'auto' &&
            preferredLanguageId.isNotEmpty &&
            detectedId == fallbackId)
        ? preferredLanguageId
        : detectedId;

    final profile = kProfiles[langId];
    final targetVoiceTag = _defaultBcp47For(langId);

    // 2. Cherche d'abord une voix NATIVE pour la langue SANS fallback
    final nativeVoice = bestVoiceLocale(
      targetVoiceTag,
      availableVoices,
      fallbacks: const [],
    );

    final bool usesFallback = nativeVoice == null;
    final String fallbackTag = profile?.phoneticFallbackTag ??
        (langId == 'en' ? 'en-US' : 'fr-FR');

    final String? selectedVoice = nativeVoice ??
        bestVoiceLocale(
          fallbackTag,
          availableVoices,
          fallbacks: const ['fr-FR', 'en-US'],
        );

    // Quelle est la langue phonétique du moteur TTS qui va réellement parler ?
    final String engineLang = selectedVoice != null
        ? selectedVoice.split(RegExp(r'[-_]')).first.toLowerCase()
        : (fallbackTag.startsWith('en') ? 'en' : 'fr');

    // 3. Nettoyage structurel (Markdown, blocs G-code, émojis, unités CNC)
    var spoken = cleanMarkdownAndCncForSpeech(
      rawText,
      engineLang: engineLang,
    );

    // 4. Adaptation phonétique si la langue est lue par une voix de repli
    //    (ou si la langue contient des caractères IPA africains)
    if (spoken.isNotEmpty) {
      if (langId == 'bm' && (usesFallback || engineLang == 'fr')) {
        spoken = transcribeBambaraForFrenchTts(spoken);
      } else if (langId == 'wo' && (usesFallback || engineLang == 'fr')) {
        spoken = transcribeWolofForFrenchTts(spoken);
      } else if (usesFallback && profile != null) {
        spoken = transcribeAfricanLatinForTts(
          spoken,
          engineLang: engineLang,
        );
      } else if (_hasAfricanIpaChars(spoken)) {
        // Même dans un texte français/mixte, si des lettres ɛ, ɔ, ɲ, ŋ
        // apparaissent, on les convertit pour que le TTS ne les épelle pas.
        spoken = transcribeBambaraForFrenchTts(spoken);
      }
    }

    final double rate = profile?.recommendedSpeechRate ?? 0.50;

    return PreparedVoiceUtterance(
      languageId: langId,
      selectedVoiceLocale: selectedVoice,
      usesPhoneticFallback: usesFallback,
      speechRate: rate,
      spokenText: spoken,
      waxalProfile: profile,
    );
  }

  static final RegExp _africanIpaRegex =
      RegExp(r'[ɛƐɔƆɲƝŋŊɓƁɗƊƙƘƴƳẹẸọỌṣṢ]');

  static bool _hasAfricanIpaChars(String s) => _africanIpaRegex.hasMatch(s);

  static String _defaultBcp47For(String langId) {
    switch (langId) {
      case 'fr':
        return 'fr-FR';
      case 'en':
        return 'en-US';
      case 'bm':
        return 'bm-ML';
      case 'ar':
        return 'ar-MA';
      case 'sw':
        return 'sw-KE';
      case 'af':
        return 'af-ZA';
      case 'am':
        return 'am-ET';
      case 'ha':
        return 'ha-NG';
      case 'yo':
        return 'yo-NG';
      case 'ig':
        return 'ig-NG';
      case 'zu':
        return 'zu-ZA';
      case 'so':
        return 'so-SO';
      case 'rw':
        return 'rw-RW';
      case 'sn':
        return 'sn-ZW';
      case 'ln':
        return 'ln-CD';
      case 'wo':
        return 'wo-SN';
      case 'mg':
        return 'mg-MG';
      default:
        return 'fr-FR';
    }
  }

  /// Nettoie le markdown, les URL, les émojis et traduit les abréviations CNC
  /// (`$H`, `$X`, `mm/min`, `°C`, blocs de code) en texte oral fluide.
  static String cleanMarkdownAndCncForSpeech(
    String text, {
    String engineLang = 'fr',
  }) {
    final isEn = engineLang == 'en';
    var t = text;

    // 1. Blocs de code ```...``` -> annonce courte
    t = t.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      isEn ? ' G-code program. ' : ' Programme G-code. ',
    );

    // 2. Liens markdown [texte](url) -> garde uniquement le texte
    t = t.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );

    // 3. URLs brutes http(s)://... ou file:///...
    t = t.replaceAll(RegExp(r'(?:https?|file)://\S+'), '');

    // 4. Formules LaTeX éventuelles
    t = t
        .replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m.group(1) ?? '')
        .replaceAll(r'\times', isEn ? ' times ' : ' fois ')
        .replaceAll(r'\circ', '°');

    // 5. Commandes GRBL/FluidNC ($H, $X) avant suppression des symboles
    t = t.replaceAllMapped(
      RegExp(r'\$([A-Za-z0-9]+)'),
      (m) => isEn ? 'command ${m.group(1)}' : 'commande ${m.group(1)}',
    );

    // 6. Unités d'atelier courantes pour éviter "m m barre oblique min"
    t = t
        .replaceAll(
          RegExp(r'\bmm/min\b'),
          isEn ? 'millimeters per minute' : 'millimètres par minute',
        )
        .replaceAll(
          RegExp(r'\btr/min\b'),
          isEn ? 'RPM' : 'tours par minute',
        )
        .replaceAll('°C', isEn ? ' degrees Celsius' : ' degrés Celsius');

    // 7. Puces de listes en début de ligne -> pause de phrase
    t = t.replaceAll(RegExp(r'(^|\n)\s*(?:[-*•]|\d+[.)])\s+'), '. ');

    // 8. Suppression des émojis et pictogrammes (évite "symbole d'avertissement")
    t = t.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}]',
        unicode: true,
      ),
      ' ',
    );

    // 9. Suppression des marqueurs markdown restants (*, _, `, #, >)
    t = t.replaceAll(RegExp(r'[*_`#~>|]'), ' ');

    // 10. Normalisation des espaces et ponctuations doubles
    t = t
        .replaceAll(RegExp(r'\s*\.\s*\.\s*'), '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\.\s*'), '')
        .trim();

    return t;
  }

  /// Transcrit un texte en **bambara (`bm`)** (pur ou mêlé de mots d'atelier
  /// français) en orthographe phonétique lisible par une voix française (`fr-FR`).
  ///
  /// Exemples :
  /// - `"I ni ce! Mashini jɔ sisan."` → `"I ni tché! machini djò ssissan."`
  /// - `"X taa milimɛtɛri duuru la, teliya kɛmɛ saba."`
  ///   → `"X tâ milimètèri dourou la, téliya kèmè ssaba."`
  /// - `"A ɲɛfɔ n ye"` → `"A gnèfò n yé"`
  static String transcribeBambaraForFrenchTts(String text) {
    // Pré-traitement d'expressions figées courantes
    var work = text;
    work = work.replaceAllMapped(
      RegExp(r'\b([iI]|aw|Aw|anw|Anw)\s+ni\s+ce\b'),
      (m) => '${m.group(1)} ni tché',
    );

    // Découpage en jetons (mots vs ponctuation/espaces)
    final tokenRegex = RegExp(
      r"[A-Za-zÀ-ÖØ-öø-ÿɛƐɔƆɲƝŋŊ']+|[^A-Za-zÀ-ÖØ-öø-ÿɛƐɔƆɲƝŋŊ']+",
    );

    final buf = StringBuffer();
    for (final match in tokenRegex.allMatches(work)) {
      final token = match.group(0)!;
      if (!_isWordToken(token)) {
        buf.write(token);
        continue;
      }
      buf.write(_transcribeBambaraWord(token));
    }
    return buf.toString();
  }

  static bool _isWordToken(String s) =>
      RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿɛƐɔƆɲƝŋŊ']+").hasMatch(s);

  static String _transcribeBambaraWord(String word) {
    final lower = word.toLowerCase();

    // 1. Si c'est un code G-code / acronyme court majuscule (G54, X, Y, Z, ESP32, GPIO)
    if (word.toUpperCase() == word && word.length <= 6 && !_hasAfricanIpaChars(word)) {
      return word;
    }

    // 2. Si c'est un mot français d'atelier connu (broche, homing, machine, programme…)
    if (_frenchAtelierWords.contains(lower)) {
      return word;
    }

    // 3. Si le mot figure dans le dictionnaire phonétique bambara exact
    final exact = _bambaraExactPhonetic[lower];
    if (exact != null) {
      return _preserveCapitalization(word, exact);
    }

    // 4. Règles phonétiques générales Bambara → Français
    var w = lower;

    // 4.a Voyelles longues bambara (avant les remplacements simples)
    w = w
        .replaceAll('ɛɛ', 'è')
        .replaceAll('ɔɔ', 'ô')
        .replaceAll('aa', 'â')
        .replaceAll('oo', 'ô')
        .replaceAll('ee', 'é')
        .replaceAll('ii', 'î')
        .replaceAll('uu', 'ou');

    // 4.b Lettres IPA africaines (ɛ, ɔ, ɲ, ŋ)
    w = w
        .replaceAll('ɛ', 'è')
        .replaceAll('ɔ', 'ò')
        .replaceAll('ɲ', 'gn')
        .replaceAll('ŋ', 'ng');

    // 4.c Consonnes propres à l'orthographe bambara :
    // - 'sh' (emprunts ex. mashini) -> 'ch' en français
    w = w.replaceAll('sh', 'ch');
    // - 'c' (non suivi de 'h') se prononce toujours 'tch' (/t͡ʃ/) en bambara
    w = w.replaceAllMapped(RegExp(r'c(?!h)'), (_) => 'tch');
    // - 'j' (non précédé de 'd') se prononce toujours 'dj' (/d͡ʒ/) en bambara
    w = w.replaceAllMapped(RegExp(r'(?<!d)j'), (_) => 'dj');
    // - 'g' devant e, i, è, é, î reste dur (/ɡ/) en bambara -> 'gu' en français
    w = w.replaceAllMapped(
      RegExp(r'g(?=[eièéêî])'),
      (_) => 'gu',
    );
    // - 's' entre deux voyelles reste sourd (/s/) en bambara -> 'ss' en français
    w = w.replaceAllMapped(
      RegExp(r'(?<=[aeiouèéêòôâî])s(?=[aeiouèéêòôâî])'),
      (_) => 'ss',
    );

    // 4.d Voyelle 'u' -> 'ou' (/u/), sauf si déjà 'ou' ou après 'g' devant e/i ('gu')
    w = w.replaceAllMapped(
      RegExp(r'(?<![oO])u(?![eèéêiî])'),
      (_) => 'ou',
    );
    // Et 'gu' suivi d'une consonne ou en fin de mot (ex: 'gun', 'dugu') -> 'gou'
    w = w.replaceAllMapped(
      RegExp(r'gu(?=[bcdfghjklmnpqrstvwxz]|$)'),
      (_) => 'gou',
    );

    // 4.e En bambara, le '-e' final se prononce toujours '/e/' ('-é'), jamais muet
    if (w.length > 1 && w.endsWith('e')) {
      w = '${w.substring(0, w.length - 1)}é';
    }

    return _preserveCapitalization(word, w);
  }

  /// Transcrit un texte en **wolof (`wo`)** pour une voix française.
  static String transcribeWolofForFrenchTts(String text) {
    var w = text
        .replaceAll('ñ', 'gn')
        .replaceAll('Ñ', 'Gn')
        .replaceAll('ŋ', 'ng')
        .replaceAll('Ŋ', 'Ng')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ó', 'ô')
        .replaceAll('é', 'é');
    return transcribeBambaraForFrenchTts(w);
  }

  /// Normalise les caractères spéciaux des langues africaines (Haoussa `ɓ ɗ ƙ`,
  /// Yoruba `ẹ ọ ṣ`, Igbo `ị ụ ṅ`, Éwé `ɖ ƒ ʋ`, Lingala `ɛ ɔ`) lorsqu'elles
  /// sont lues par une voix de repli anglaise ou française.
  static String transcribeAfricanLatinForTts(
    String text, {
    String engineLang = 'en',
  }) {
    final isFr = engineLang == 'fr';
    var w = text
        // Haoussa / Peul
        .replaceAll(RegExp(r'[ɓƁ]'), 'b')
        .replaceAll(RegExp(r'[ɗƊɖƉ]'), 'd')
        .replaceAll(RegExp(r'[ƙƘ]'), 'k')
        .replaceAll(RegExp(r'[ƴƳ]'), 'y')
        // Yoruba / Igbo
        .replaceAll(RegExp(r'[ṣṢ]'), isFr ? 'ch' : 'sh')
        .replaceAll(RegExp(r'[ẹẸɛƐ]'), isFr ? 'è' : 'eh')
        .replaceAll(RegExp(r'[ọỌɔƆ]'), isFr ? 'ò' : 'o')
        .replaceAll(RegExp(r'[ịỊ]'), 'i')
        .replaceAll(RegExp(r'[ụỤ]'), isFr ? 'ou' : 'u')
        .replaceAll(RegExp(r'[ṅṄŋŊ]'), 'ng')
        .replaceAll(RegExp(r'[ɲƝ]'), isFr ? 'gn' : 'ny')
        // Éwé
        .replaceAll(RegExp(r'[ƒƑ]'), 'f')
        .replaceAll(RegExp(r'[ʋƲ]'), 'v');

    // Suppression des diacritiques tonaux combinants (U+0300..U+0304) qui
    // bloquent certains moteurs SAPI sur les voyelles yoruba/igbo
    w = w.replaceAll(RegExp(r'[\u0300-\u0304\u0323]'), '');
    return w;
  }

  static String _preserveCapitalization(String original, String transformed) {
    if (original.isEmpty || transformed.isEmpty) return transformed;
    final firstOrig = original[0];
    if (firstOrig.toUpperCase() == firstOrig &&
        firstOrig.toLowerCase() != firstOrig) {
      return transformed[0].toUpperCase() + transformed.substring(1);
    }
    return transformed;
  }
}
