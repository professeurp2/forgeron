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

  /// Balisage SSML 1.0 enrichi (pauses respiratoires, prosodie d'ouverture et
  /// d'intonation interrogative finale) pour les moteurs compatibles SAPI/OneCore.
  final String ssmlText;

  /// Segments prosodiques (phrases / clauses) permettant aux moteurs sans SSML
  /// de moduler le ton et de marquer des pauses naturelles entre les idées.
  final List<String> conversationalChunks;

  /// Profil WAXAL / Hugging Face associé s'il s'agit d'une langue africaine.
  final WaxalLanguageProfile? waxalProfile;

  const PreparedVoiceUtterance({
    required this.languageId,
    required this.selectedVoiceLocale,
    required this.usesPhoneticFallback,
    required this.speechRate,
    required this.spokenText,
    this.ssmlText = '',
    this.conversationalChunks = const [],
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
          fallbacks: langId == 'en'
              ? const ['en-US', 'en-GB', 'fr-FR']
              : const ['fr-FR', 'en-US'],
        );

    // Quelle est la langue phonétique du moteur TTS qui va réellement parler ?
    final String engineLang = selectedVoice != null
        ? selectedVoice.split(RegExp(r'[-_]')).first.toLowerCase()
        : (fallbackTag.startsWith('en') ? 'en' : 'fr');

    // Langue sémantique du texte pour l'expansion des unités (ex: "20mm" ->
    // "20 millimeters" en anglais même si availableVoices de WinRT ne listait
    // pas encore la voix SAPI5 anglaise).
    final String contentLang =
        (langId == 'en' || fallbackTag.startsWith('en')) ? 'en' : engineLang;

    // 3. Nettoyage structurel et humanisation (Markdown, blocs G-code, émojis,
    //    unités CNC, pauses respiratoires de présentation)
    var spoken = cleanMarkdownAndCncForSpeech(
      rawText,
      engineLang: contentLang,
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

    final double rate = profile?.recommendedSpeechRate ??
        (langId == 'en' ? 0.48 : 0.49);

    final chunks = splitConversationalChunks(spoken);
    final ssml = buildHumanSsml(
      spoken,
      langId: langId,
      voiceLocale: selectedVoice ?? targetVoiceTag,
      speechRate: rate,
    );

    return PreparedVoiceUtterance(
      languageId: langId,
      selectedVoiceLocale: selectedVoice,
      usesPhoneticFallback: usesFallback,
      speechRate: rate,
      spokenText: spoken,
      ssmlText: ssml,
      conversationalChunks: chunks,
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
  /// (`$H`, `$X`, `20mm`, `mm/min`, `°C`, `5-axis`, blocs de code, chemins de
  /// fichiers) en une présentation orale humaine, chaleureuse et fluide.
  static String cleanMarkdownAndCncForSpeech(
    String text, {
    String engineLang = 'fr',
  }) {
    final isEn = engineLang == 'en';
    var t = text;

    // 1. Blocs de code ```...``` -> annonce naturelle
    t = t.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      isEn ? ' G-code program ready. ' : ' Programme G-code prêt. ',
    );

    // 2. Liens markdown [texte](url) -> garde uniquement le texte
    t = t.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );

    // 3. URLs brutes http(s)://... ou file:///...
    t = t.replaceAll(RegExp(r'(?:https?|file)://\S+'), '');

    // 3.b Chemins de fichiers techniques (ex: scratch/dome_5axis_20mm.nc, C:\...\part.step)
    //     Évite que la voix n'épelle "scratch barre oblique dôme tiret bas..."
    t = t.replaceAllMapped(
      RegExp(
        r'(?:[A-Za-z]:[\\/]|[a-zA-Z0-9_.-]+[\\/])[a-zA-Z0-9_./\\-]+\.(?:nc|gcode|ngc|tap|step|stp|stl)\b',
        caseSensitive: false,
      ),
      (m) {
        final full = m.group(0) ?? '';
        final lower = full.toLowerCase();
        if (lower.endsWith('.step') || lower.endsWith('.stp') || lower.endsWith('.stl')) {
          return isEn ? 'the 3D CAD file' : 'le fichier 3D';
        }
        return isEn ? 'the G-code program' : 'le programme G-code';
      },
    );

    // 3.c Identifiants internes d'outils (snake_case) ou pseudo-appels de fonction éventuellement cités
    t = t.replaceAll(
      RegExp(
        r'(?:Run|Execute|Call)\s+the\s+`?[a-z0-9_]+`?\s+function(?:\s+now)?\.?',
        caseSensitive: false,
      ),
      '',
    );
    t = t.replaceAll(
      RegExp(r'\b[a-z]+_[a-z0-9_]+\s*\([^)]*\)'),
      '',
    );
    t = t
        .replaceAll('generate_5axis_dome', isEn ? '5 axis dome generator' : 'générateur de dôme 5 axes')
        .replaceAll('run_step_pipeline', isEn ? 'CAM pipeline' : 'pipeline FAO')
        .replaceAll('run_program', isEn ? 'program start' : 'lancement du programme')
        .replaceAll('analyze_gcode', isEn ? 'program analysis' : 'analyse du programme')
        .replaceAll('get_diagnostics', isEn ? 'diagnostics check' : 'vérification de diagnostic')
        .replaceAll('get_machine_state', isEn ? 'machine status check' : 'lecture de l\'état machine')
        .replaceAll('get_status', isEn ? 'status check' : 'vérification d\'état')
        .replaceAll('jog_move', isEn ? 'axis movement' : 'déplacement d\'axe');

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

    // 5.b Arrondir les coordonnées décimales à zéros inutiles (ex: Z15.000 -> Z15)
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+)\.00+\b'),
      (m) => m.group(1)!,
    );

    // 6. Unités d'atelier (compactes "20mm" ou espacées "20 mm") pour une
    //    lecture humaine ("20 millimeters" / "20 millimètres" au lieu de "20 m m")
    t = t
        .replaceAllMapped(
          RegExp(r'(\d+(?:[.,]\d+)?)\s*mm/min\b', caseSensitive: false),
          (m) => '${m.group(1)} ${isEn ? 'millimeters per minute' : 'millimètres par minute'}',
        )
        .replaceAll(
          RegExp(r'\bmm/min\b', caseSensitive: false),
          isEn ? 'millimeters per minute' : 'millimètres par minute',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:[.,]\d+)?)\s*tr/min\b', caseSensitive: false),
          (m) => '${m.group(1)} ${isEn ? 'RPM' : 'tours par minute'}',
        )
        .replaceAll(
          RegExp(r'\btr/min\b', caseSensitive: false),
          isEn ? 'RPM' : 'tours par minute',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:[.,]\d+)?)\s*mm\b', caseSensitive: false),
          (m) => '${m.group(1)} ${isEn ? 'millimeters' : 'millimètres'}',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:[.,]\d+)?)\s*cm\b', caseSensitive: false),
          (m) => '${m.group(1)} ${isEn ? 'centimeters' : 'centimètres'}',
        )
        .replaceAll('°C', isEn ? ' degrees Celsius' : ' degrés Celsius')
        .replaceAllMapped(
          RegExp(r'(\d+(?:[.,]\d+)?)\s*°'),
          (m) => '${m.group(1)} ${isEn ? 'degrees' : 'degrés'}',
        )
        .replaceAllMapped(
          RegExp(r'±\s*(\d+(?:[.,]\d+)?)'),
          (m) => '${isEn ? 'plus or minus' : 'plus ou moins'} ${m.group(1)}',
        )
        .replaceAllMapped(
          RegExp(r'\b(\d+)-axis\b', caseSensitive: false),
          (m) => '${m.group(1)} axis',
        )
        .replaceAll(RegExp(r'\b3D\b'), '3 D');

    // 6.b Décimales naturelles selon la langue ("0,2" en français, "0.2" en anglais)
    if (!isEn) {
      t = t.replaceAllMapped(
        RegExp(r'(\d)\.(\d)'),
        (m) => '${m.group(1)},${m.group(2)}',
      );
    } else {
      t = t.replaceAllMapped(
        RegExp(r'(\d),(\d)'),
        (m) => '${m.group(1)}.${m.group(2)}',
      );
    }

    // 7. Structure de présentation orale : titres, puces et retours à la ligne
    //    deviennent de vraies pauses respiratoires (". " ou ", ")
    t = t.replaceAllMapped(
      RegExp(r'(^|\n)\s*#{1,6}\s*([^\n]+)'),
      (m) => '. ${m.group(2)}. ',
    );
    t = t.replaceAll(RegExp(r'(^|\n)\s*(?:[-*•]|\d+[.)])\s+'), '. ');
    // Deux-points après un libellé court en début de phrase -> virgule respiratoire
    t = t.replaceAllMapped(
      RegExp(r'(\.\s+[^.!?\n:]{2,35}):\s+'),
      (m) => '${m.group(1)}, ',
    );
    // Retours à la ligne restants entre deux phrases sans ponctuation finale -> point
    t = t.replaceAllMapped(
      RegExp(r'([^\s.!?,;:])\s*\n+\s*'),
      (m) => '${m.group(1)}. ',
    );

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
        .replaceAllMapped(RegExp(r'\s+([.!?,;:])'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'(?:\.\s*){2,}'), '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\.\s*'), '')
        .trim();

    return t;
  }

  /// Découpe le texte préparé en segments conversationnels naturels (phrases)
  /// afin de rythmer la présentation vocale et d'éviter le ton monotone.
  static List<String> splitConversationalChunks(String spokenText) {
    final trimmed = spokenText.trim();
    if (trimmed.isEmpty) return const [];
    final rawParts = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    for (final part in rawParts) {
      final clean = part.trim();
      if (clean.isEmpty) continue;
      chunks.add(clean);
    }
    return chunks.isEmpty ? [trimmed] : chunks;
  }

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  /// Construit un document SSML 1.0 mettant en scène la réponse comme un
  /// présentateur humain : attaque chaleureuse, pauses respiratoires aux
  /// virgules et entre les points clés, et inflexion posée sur la question finale.
  static String buildHumanSsml(
    String spokenText, {
    required String langId,
    required String voiceLocale,
    required double speechRate,
  }) {
    final chunks = splitConversationalChunks(spokenText);
    if (chunks.isEmpty) return '';

    final xmlLang = voiceLocale.replaceAll('_', '-');
    final buf = StringBuffer(
      '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="$xmlLang">',
    );

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final isFirst = i == 0;
      final isLast = i == chunks.length - 1;
      final isQuestion = chunk.endsWith('?');

      // Prosodie nuancée selon le rôle de la phrase dans la présentation :
      // - Ouverture : chaleureuse et engagée (+3% pitch)
      // - Question finale / demande de confirmation : posée et invitante (+4% pitch, -3% rate)
      // - Corps technique : clair, posé et articulé (+1% pitch, -1% rate)
      final String pitch;
      final String rate;
      if (isQuestion && isLast) {
        pitch = '+4%';
        rate = '-3%';
      } else if (isFirst) {
        pitch = '+3%';
        rate = '0%';
      } else {
        pitch = '+1%';
        rate = '-2%';
      }

      // Insertion de micro-respirations sur les virgules et points-virgules
      final escaped = _escapeXml(chunk).replaceAllMapped(
        RegExp(r'([,;:])\s+'),
        (m) => '${m.group(1)} <break time="140ms"/> ',
      );

      if (i > 0) {
        buf.write(isQuestion ? '<break time="300ms"/>' : '<break time="240ms"/>');
      }
      buf.write('<s><prosody rate="$rate" pitch="$pitch">$escaped</prosody></s>');
    }

    buf.write('</speak>');
    return buf.toString();
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

  /// Normalise et répare la saisie vocale (STT) et les approximations phonétiques
  /// de l'opérateur avant envoi au lexique ou au modèle IA.
  ///
  /// Résout les causes majeures d'hallucination en atelier :
  /// 1. En français : les termes CNC déformés par le modèle acoustique SAPI/Android
  ///    (« j'ai 54 » -> G54, « eau mine » -> homing, « pas le page » -> palpage,
  ///    « aime 3 » -> M3, « proche/brosse » en contexte d'outil -> broche).
  /// 2. En langues locales (bambara, etc.) : les phrases africaines transcrites
  ///    par un moteur SAPI/Android français (« inicié » -> « i ni ce »,
  ///    « josissant » -> « jɔ sisan », « d'amener » -> « daminɛ », etc.).
  static String _replaceWordPattern(String text, String pattern, String replacement) {
    final regex = RegExp('(^|[\\s,;!?])(?:$pattern)([\\s,;!?]|\$)', caseSensitive: false);
    var res = text.replaceAllMapped(regex, (m) => '${m.group(1)}$replacement${m.group(2)}');
    return res.replaceAllMapped(regex, (m) => '${m.group(1)}$replacement${m.group(2)}');
  }

  static String normalizeSttInput(
    String rawText, {
    String? activeLanguageId,
  }) {
    if (rawText.trim().isEmpty) return rawText;
    var t = rawText;

    // ── 1. Répétitions bègues et bruits acoustiques de micro ──────────────
    t = t.replaceAllMapped(
      RegExp(r'\b([A-Za-zÀ-ÿ]{3,})\s+\1\b', caseSensitive: false),
      (m) => m.group(1)!,
    );

    final isEnActive = activeLanguageId == 'en';

    // ── 1.b Réparation phonétique Anglais (et Anglais dicté sur SAPI fr-FR) ──
    // Sur Windows hors ligne, lorsque seul le moteur SAPI fr-FR (MS-1036) est
    // installé, une phrase anglaise comme "Mill a 20mm dome on aluminium" est
    // transcrite phonétiquement avec des mots français ("mille à 20 mm dôme en
    // aluminium", "maille a vingt millimètres d'homme on aluminium", etc.).
    final enDomeVerbMatch = RegExp(
      r"^\s*(?:mill|mille|mil|mail|meal|mild|maille|mets?\s+la|mais\s+la|build|carve|cut)\b",
      caseSensitive: false,
    ).hasMatch(t);
    if (isEnActive || enDomeVerbMatch) {
      // Conversion nombres parlés courants pour le diamètre ("twenty" / "vingt" -> "20")
      var workEn = t
          .replaceAll(RegExp(r'\b(?:twenty|vingt|toi\s*ni|twenti)\b', caseSensitive: false), '20')
          .replaceAll(RegExp(r'\b(?:thirty|trente)\b', caseSensitive: false), '30')
          .replaceAll(RegExp(r'\b(?:ten|dix)\b', caseSensitive: false), '10')
          .replaceAll(RegExp(r'\b(?:fifteen|quinze)\b', caseSensitive: false), '15')
          .replaceAll(RegExp(r'\b(?:twenty[- ]five|vingt[- ]cinq)\b', caseSensitive: false), '25')
          .replaceAll(RegExp(r'\b(?:forty|quarante)\b', caseSensitive: false), '40')
          .replaceAll(RegExp(r'\b(?:fifty|cinquante)\b', caseSensitive: false), '50');

      final domePattern = RegExp(
        r"(?:mill|mille|mil|mail|meal|mild|maille|mets?\s+la|mais\s+la|build|carve|cut|usine|fraise)?\s*(?:a|un|une|le|la|à)?\s*(\d+(?:[.,]\d+)?)\s*(?:mm|millim[èe]tres?|millimeters?|m\s*m)?\s*(?:5[- ]?axis\s+)?(?:d[ôo]me|d['’]homme|tome|down|home|don)\b(?:.*?\b(alumini?um|alu|brass|laiton|wood|bois|steel|acier|plastic|plastique))?",
        caseSensitive: false,
      );
      final dm = domePattern.firstMatch(workEn);
      if (dm != null && (isEnActive || enDomeVerbMatch)) {
        final rawDiam = (dm.group(1) ?? '20').replaceAll(',', '.');
        final rawMat = (dm.group(2) ?? 'aluminium').toLowerCase();
        String mat = 'aluminium';
        if (rawMat.contains('brass') || rawMat.contains('laiton')) {
          mat = 'brass';
        } else if (rawMat.contains('wood') || rawMat.contains('bois')) {
          mat = 'wood';
        } else if (rawMat.contains('steel') || rawMat.contains('acier')) {
          mat = 'steel';
        } else if (rawMat.contains('plastic') || rawMat.contains('plastique')) {
          mat = 'plastic';
        } else if (rawMat == 'aluminum') {
          mat = 'aluminum';
        }
        return 'Mill a ${rawDiam}mm dome on $mat';
      }
    }

    if (isEnActive) {
      // Normalisations STT propres à l'anglais (et anglais capté par SAPI fr-FR)
      t = t.replaceAllMapped(
        RegExp(r'\b(\d+(?:[.,]\d+)?)\s*(?:millimeters?|millimetres?|mm)\b', caseSensitive: false),
        (m) => '${m.group(1)!.replaceAll(',', '.')}mm',
      );
      t = t.replaceAll(
        RegExp(r'\b(?:home|homme|au|haut)\s+(?:all\s+)?(?:axes|axis|access|ax[èe]s?)\b', caseSensitive: false),
        'Home all axes',
      );
      t = t.replaceAll(
        RegExp(r'\b(?:what\s+is\s+the\s+|ouate\s+is\s+de\s+)?machine\s+(?:statut|status|state)\b', caseSensitive: false),
        'What is the machine status',
      );
      t = t.replaceAll(
        RegExp(r'\b(?:turn\s+on|start|allume)\s+(?:the\s+|la\s+|de\s+)?(?:spindle|spin|broche)\b', caseSensitive: false),
        'Turn on the spindle',
      );
      t = t.replaceAll(
        RegExp(r'\b(?:turn\s+off|stop|arr[êe]te)\s+(?:the\s+|la\s+|de\s+)?(?:spindle|spin|broche)\b', caseSensitive: false),
        'Stop the spindle',
      );
      t = t.replaceAll(
        RegExp(r'^\s*(?:confirme|confirm|yes\s+confirm|oui\s+confirme)\s*$', caseSensitive: false),
        'Confirm',
      );
      t = t.replaceAll(
        RegExp(r'\b(?:fluide\s+ainsi|fluide\s+nc|fluid\s+nc)\b', caseSensitive: false),
        'FluidNC',
      );
      t = t.replaceAll(
        RegExp(r"\b(?:g|gee)\s*(?:54|fifty[- ]four)\b", caseSensitive: false),
        'G54',
      );
      t = t.replaceAll(
        RegExp(r"\b(?:g|gee)\s*(?:0|zero)\b", caseSensitive: false),
        'G0',
      );
      t = t.replaceAll(
        RegExp(r"\b(?:g|gee)\s*(?:1|one)\b", caseSensitive: false),
        'G1',
      );
      return t.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // ── 2. Termes CNC et codes G-code / M-code en français ─────────────────
    // WCS G54..G59
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:54|cinquante[- ]quatre)\b", caseSensitive: false),
      'G54',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:55|cinquante[- ]cinq)\b", caseSensitive: false),
      'G55',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:56|cinquante[- ]six)\b", caseSensitive: false),
      'G56',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:57|cinquante[- ]sept)\b", caseSensitive: false),
      'G57',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:58|cinquante[- ]huit)\b", caseSensitive: false),
      'G58',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:59|cinquante[- ]neuf)\b", caseSensitive: false),
      'G59',
    );

    // Déplacements G0, G1, G28, G90, G91
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:0|z[ée]ro|[ée]o)\b", caseSensitive: false),
      'G0',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:1|un)\b", caseSensitive: false),
      'G1',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*28\b", caseSensitive: false),
      'G28',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:90|quatre[- ]vingt[- ]dix)\b", caseSensitive: false),
      'G90',
    );
    t = t.replaceAll(
      RegExp(r"\b(?:j['’]ai|g[ée]|ge|g)\s*(?:91|quatre[- ]vingt[- ]onze)\b", caseSensitive: false),
      'G91',
    );

    // M-codes broche
    t = t.replaceAll(
      RegExp(r'\b(?:aime|m[èe]tre|m)\s*3\b', caseSensitive: false),
      'M3',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:aime|m[èe]tre|m)\s*5\b', caseSensitive: false),
      'M5',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:aime|m[èe]tre|m)\s*6\b', caseSensitive: false),
      'M6',
    );

    // Commandes GRBL / Homing / Palpage
    t = t.replaceAll(
      RegExp(r'\b(?:eau|oh|homme|au|haut)\s*(?:mine|minet|in|ing)\b', caseSensitive: false),
      'homing',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:pas\s+le\s+page|ballet\s+page|pal\s+page)\b', caseSensitive: false),
      'palpage',
    );

    // Broche (confusion acoustique très fréquente avec "proche" ou "brosse")
    t = t.replaceAllMapped(
      RegExp(
        r"(\b(?:la|une|notre|vitesse|rotation|d[ée]marr(?:e|er)|allum(?:e|er)|arr[êe]t(?:e|er)|coup(?:e|er)|stop(?:pe)?)\s+)(?:proche|brosse)\b",
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}broche',
    );
    t = t.replaceAllMapped(
      RegExp(
        r"\b(?:proche|brosse)(\s+(?:[àa]\s+\d+|[ée]teinte|allum[ée]e|en\s+marche|damin[ɛe]))\b",
        caseSensitive: false,
      ),
      (m) => 'broche${m.group(1)}',
    );

    // Composants et repères CNC
    t = t.replaceAll(
      RegExp(r'\b(?:fluide\s+ainsi|fluide\s+nc|fluid\s+nc)\b', caseSensitive: false),
      'FluidNC',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:d[ée]s?\s+h[ée]ros|d[ée]reau)\b', caseSensitive: false),
      'DRO',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:double\s+v\s+c\s+s|double\s+v\s+c\s+est|double\s+v\s+c)\b', caseSensitive: false),
      'WCS',
    );
    t = t.replaceAll(
      RegExp(r'\bz[ée]ro\s+t[âa]che(?:s)?\b', caseSensitive: false),
      'zérotage',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:le\s+sp\s*32|esp\s*32|e\s*s\s*p\s*32)\b', caseSensitive: false),
      'ESP32',
    );

    // Axes
    t = t.replaceAll(
      RegExp(r'\b(?:axe|acc[èe]s)\s+(?:z[èe]de|zed|aide)\b', caseSensitive: false),
      'axe Z',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:axe|acc[èe]s)\s+x\b', caseSensitive: false),
      'axe X',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:axe|acc[èe]s)\s+y\b', caseSensitive: false),
      'axe Y',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:axe|acc[èe]s)\s+a\b', caseSensitive: false),
      'axe A',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:axe|acc[èe]s)\s+c\b', caseSensitive: false),
      'axe C',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:why|white|wide)\s+axis\b', caseSensitive: false),
      'Y axis',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:ex|eggs)\s+axis\b', caseSensitive: false),
      'X axis',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:zed|zee|the\s+z)\s+axis\b', caseSensitive: false),
      'Z axis',
    );
    t = t.replaceAll(
      RegExp(r'\b(?:sea|see)\s+axis\b', caseSensitive: false),
      'C axis',
    );
    t = t.replaceAllMapped(
      RegExp(r'\bhome([xyzac])\b', caseSensitive: false),
      (m) => 'home ${m.group(1)!.toUpperCase()}',
    );
    t = t.replaceAll(
      RegExp(r'\bsaxis\b', caseSensitive: false),
      'axis',
    );
    t = t.replaceAll(
      RegExp(r'\bgot\s+to\s+(?=[xyzac]\s*-?\d)', caseSensitive: false),
      'go to ',
    );

    // Sécurité atelier
    t = t.replaceAll(
      RegExp(r"\b(?:arr[êe]t\s+d['’]\s*urgence|arret\s+urgence)\b", caseSensitive: false),
      "Arrêt d'urgence",
    );
    t = t.replaceAll(
      RegExp(r'\b(?:arr[êe]te\s+tout|stoppe\s+tout|stop\s+tout)\b', caseSensitive: false),
      'Arrête tout',
    );

    // ── 3. Phonétique des langues locales (Bambara...) sur STT Français ───
    final isBm = activeLanguageId == 'bm' ||
        activeLanguageId == null ||
        activeLanguageId == 'auto';
    if (isBm) {
      t = _replaceWordPattern(t, r"inici[ée]|il\s+n['’]y\s+sait|i\s+ni\s+tch[ée]|initi[ée]", 'I ni ce');
      t = _replaceWordPattern(t, r"aw\s+ni\s+baara|en\s+libara|en\s+ni\s+bara|ani\s+baara", 'Aw ni baara');
      t = _replaceWordPattern(t, r"josissant|je\s+six\s+ans|d['’]eau\s+six\s+ans|dj[òo]\s+sisan|jo\s+sisan", 'jɔ sisan');
      t = _replaceWordPattern(t, r"d['’]amener|dans\s+minet|damin[èe]", 'daminɛ');
      t = _replaceWordPattern(t, r"d['’]habilla|d['’]habille\s+l[àa]|dabila", 'dabila');
      t = _replaceWordPattern(t, r"massine", 'mashini');
      t = _replaceWordPattern(t, r"mouna", 'munna');
      t = _replaceWordPattern(t, r"qu['’]aimait\s+saba|k[èe]m[èe]\s+saba|qu['’]aimait\s+ça\s+va|qu['’]aimait\s+s['’]abattre", 'kɛmɛ saba');
      t = _replaceWordPattern(t, r"doux\s+roux|d['’]o[ùu]\s+roux|dourou", 'duuru');
      t = _replaceWordPattern(t, r"t[ée]lia|tel\s+il\s+y\s+a", 'teliya');
      t = _replaceWordPattern(t, r"gn[èe]f[òo]|nier\s+faux", 'ɲɛfɔ');
      t = _replaceWordPattern(t, r"bamanankang", 'bamanankan');
      t = _replaceWordPattern(t, r"qui\s+n['’]y\s+bolo", 'kinibolo');
      t = _replaceWordPattern(t, r"nous\s+man", 'numan');
      t = _replaceWordPattern(t, r"porogramme", 'porogaramu');
      t = _replaceWordPattern(t, r"s[ée]guin", 'segin');
    }

    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
