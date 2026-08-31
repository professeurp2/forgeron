import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue de l'application : interface ET agent IA.
///
/// Gemini est nativement multilingue : il n'y a aucun paramètre d'API pour
/// ça, tout se joue dans l'instruction système. Cette classe porte donc à la
/// fois le libellé affiché, la consigne envoyée au modèle et l'étiquette
/// BCP-47 utilisée pour la dictée et la synthèse vocale.
class AppLanguage {
  /// Identifiant persisté (`auto`, `fr`, `sw`...).
  final String id;

  /// Libellé du sélecteur, écrit dans la langue elle-même.
  final String label;

  /// Nom de la langue tel qu'annoncé à Gemini. `null` = mode automatique.
  final String? promptName;

  /// Étiquette BCP-47 souhaitée pour le micro et la voix. Vide en mode auto :
  /// on prend alors la locale du système.
  final String voiceTag;

  /// Langue peu dotée : les petits modèles y sont sensiblement plus faibles,
  /// et la dictée/synthèse est souvent absente de l'appareil. Sert à afficher
  /// un avertissement honnête plutôt qu'à bloquer le choix.
  final bool lowResource;

  const AppLanguage(
    this.id,
    this.label,
    this.promptName,
    this.voiceTag, {
    this.lowResource = false,
  });

  bool get isAuto => promptName == null;

  /// Locale Flutter correspondante. `null` en automatique : MaterialApp
  /// retombe alors sur celle du système.
  Locale? get locale => isAuto ? null : Locale(id);

  /// Bloc ajouté au prompt système. Les invariants sont volontairement
  /// identiques dans les deux modes : ce sont des consignes de sécurité, pas
  /// de style — un nom d'axe ou un code d'alarme traduit rend un message
  /// d'erreur inexploitable en atelier.
  String get promptDirective {
    final head = isAuto
        ? 'Réponds TOUJOURS dans la langue du dernier message de '
            "l'opérateur. S'il change de langue en cours de conversation, "
            'change avec lui. Si la langue est indécidable (message très '
            'court, G-code seul), réponds en français.'
        : 'Réponds SYSTÉMATIQUEMENT en $promptName, quelle que soit la '
            "langue dans laquelle l'opérateur écrit — y compris pour les "
            "avertissements de sécurité et les confirmations d'action.";

    return '=== LANGUE DE RÉPONSE ===\n'
        '$head\n'
        'Ne traduis JAMAIS : le G-code et ses mots-clés (G0, G1, M3, S1000, '
        'G43.4...), les noms d\'axes (X, Y, Z, A, C), les WCS (G54..G59), les '
        'codes d\'alarme et d\'erreur GRBL/FluidNC, les noms de fichiers, ni '
        'les noms des outils que tu appelles. Garde les unités telles quelles '
        '(mm, mm/min, °).\n'
        'Dans le G-code lui-même, le séparateur décimal reste TOUJOURS le '
        'point (X14.25) ; dans ta prose, utilise le séparateur usuel de la '
        'langue employée.\n'
        "L'interface de Forgeron est en français : quand tu renvoies "
        "l'opérateur vers un écran ou un bouton, cite son libellé français "
        'exact, puis traduis-le entre parenthèses si tu réponds dans une '
        'autre langue.\n'
        "Si un terme technique CNC n'a pas d'équivalent courant dans la "
        'langue de réponse, garde le terme français ou anglais et explique-le '
        'une fois entre parenthèses plutôt que de forger une traduction que '
        "l'opérateur ne reconnaîtra pas.";
  }
}

/// Langues proposées : automatique, français, anglais, puis les langues
/// africaines les plus parlées. L'ordre est celui du sélecteur.
const kAppLanguages = <AppLanguage>[
  AppLanguage('auto', 'Automatique (langue de l\'opérateur)', null, ''),
  AppLanguage('fr', 'Français', 'français', 'fr-FR'),
  AppLanguage('en', 'English', 'anglais', 'en-US'),
  AppLanguage('ar', 'العربية (arabe)', 'arabe', 'ar-MA'),
  AppLanguage('sw', 'Kiswahili (swahili)', 'swahili', 'sw-KE'),
  AppLanguage('af', 'Afrikaans', 'afrikaans', 'af-ZA'),
  AppLanguage('am', 'አማርኛ (amharique)', 'amharique', 'am-ET',
      lowResource: true),
  AppLanguage('ha', 'Hausa', 'haoussa', 'ha-NG', lowResource: true),
  AppLanguage('yo', 'Yorùbá', 'yoruba', 'yo-NG', lowResource: true),
  AppLanguage('ig', 'Igbo', 'igbo', 'ig-NG', lowResource: true),
  AppLanguage('zu', 'isiZulu (zoulou)', 'zoulou', 'zu-ZA', lowResource: true),
  AppLanguage('so', 'Soomaali (somali)', 'somali', 'so-SO', lowResource: true),
  AppLanguage('rw', 'Kinyarwanda', 'kinyarwanda', 'rw-RW', lowResource: true),
  AppLanguage('sn', 'chiShona (shona)', 'shona', 'sn-ZW', lowResource: true),
  AppLanguage('ln', 'Lingála (lingala)', 'lingala', 'ln-CD', lowResource: true),
  AppLanguage('wo', 'Wolof', 'wolof', 'wo-SN', lowResource: true),
  AppLanguage('mg', 'Malagasy (malgache)', 'malgache', 'mg-MG',
      lowResource: true),
];

/// Locales déclarées à MaterialApp. La première sert de repli quand la
/// locale du système ne correspond à rien : c'est le français.
final List<Locale> kSupportedLocales = <Locale>[
  for (final l in kAppLanguages)
    if (l.locale != null) l.locale!,
];

AppLanguage appLanguageById(String? id) => kAppLanguages.firstWhere(
      (l) => l.id == id,
      orElse: () => kAppLanguages.first,
    );

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  static const _key = 'ai_agent_language';

  AppLanguageNotifier() : super(kAppLanguages.first) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = appLanguageById(prefs.getString(_key));
    } catch (_) {}
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.id);
    } catch (_) {}
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>(
        (ref) => AppLanguageNotifier());
