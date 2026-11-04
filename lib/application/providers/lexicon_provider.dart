import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/command_lexicon.dart';
import '../../core/utils/lexicon_schema.dart';
import '../services/ai_agent_tools.dart';
import 'ai_agent_settings_provider.dart';

/// Emplacement du fichier de données dans les ressources de l'application.
const kLexiconAsset = 'assets/lexicon/lexique.json';

/// Résultat du chargement du lexique : le moteur, ou la raison de son absence.
///
/// **Échec = comme s'il n'y avait pas de lexique.** Un fichier illisible ou qui
/// viole un invariant de sécurité (voir `lexicon_schema.dart`) n'est jamais
/// chargé « en partie » : l'assistant retombe sur le chemin d'avant (modèle
/// seul + chemin rapide de l'arrêt d'urgence), et l'écran des réglages dit
/// pourquoi.
class LexiconLoad {
  const LexiconLoad({
    this.lexicon,
    this.issues = const [],
    this.failure,
    this.glossaries = const {},
  });

  final CommandLexicon? lexicon;

  /// Vocabulaire vérifié par langue, prêt à poser dans le prompt système.
  ///
  /// Le lexique sert à COMPRENDRE l'opérateur ; ce glossaire sert à l'autre
  /// sens — donner au modèle des mots sourcés pour RÉPONDRE, au lieu de le
  /// laisser en forger. C'est ce qui remplace l'interdiction d'écrire en
  /// bambara : des mots dont on sait d'où ils viennent.
  final Map<String, String> glossaries;

  /// Tous les constats de validation (avertissements compris).
  final List<LexiconIssue> issues;

  /// Pourquoi le moteur n'est pas disponible (`null` s'il l'est).
  final String? failure;

  bool get available => lexicon != null;
  List<LexiconIssue> get warnings =>
      issues.where((i) => !i.isError).toList(growable: false);
  List<LexiconIssue> get errors =>
      issues.where((i) => i.isError).toList(growable: false);
}

/// Outils de l'agent tels que le validateur doit les connaître.
Map<String, LexiconToolInfo> lexiconToolInfos() => {
      for (final t in AiToolCatalog.tools)
        t.name: LexiconToolInfo(schema: t.inputSchema, gated: t.category != null),
    };

/// Valide puis construit le moteur depuis le TEXTE du fichier. Séparé du
/// provider pour pouvoir être appelé tel quel par les tests et par
/// `tool/lexicon/lock.dart`.
LexiconLoad loadLexiconFromSource(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      return const LexiconLoad(failure: 'le fichier n\'est pas un objet JSON');
    }
    final json = decoded.cast<String, dynamic>();
    final validation = validateLexiconJson(json, tools: lexiconToolInfos());
    if (!validation.ok) {
      return LexiconLoad(
        issues: validation.issues,
        failure: 'lexique invalide (${validation.errors.length} erreur(s)) : '
            '${validation.errors.first}',
      );
    }
    return LexiconLoad(
      lexicon: CommandLexicon.fromJson(json),
      issues: validation.issues,
      glossaries: buildGlossaries(json),
    );
  } catch (e) {
    return LexiconLoad(failure: 'lexique illisible : $e');
  }
}

/// Libellé français de chaque rôle du lexique, pour que le glossaire se lise
/// comme un dictionnaire plutôt que comme une structure de données.
const _roleLabels = <String, String>{
  'stop': 'arrêter',
  'start': 'démarrer, allumer',
  'pause': 'mettre en pause',
  'show': 'montrer, dire',
  'home': "prise d'origine",
  'move': 'déplacer, aller',
  'machine': 'la machine',
  'etat': "l'état",
  'all': 'tout',
  'urgent': 'tout de suite',
  'alarm': 'danger, au secours',
  'questions': 'mots interrogatifs',
  'feed': 'vitesse',
  'directions': 'directions',
  'negations': 'négations',
};

/// Construit, par langue, un glossaire des mots VÉRIFIÉS.
///
/// N'inclut que les langues dont le lexique porte des sources : un mot sans
/// provenance n'a rien à faire dans un prompt qui sert à produire du texte
/// pour un opérateur. Le statut de relecture est annoncé tel quel — le
/// modèle doit savoir qu'il travaille sur un brouillon.
Map<String, String> buildGlossaries(Map<String, dynamic> json) {
  final out = <String, String>{};
  final langs = (json['languages'] as Map?)?.cast<String, dynamic>() ?? {};

  for (final code in langs.keys) {
    final l = (langs[code] as Map).cast<String, dynamic>();
    if (code == 'fr' || code == 'en') continue; // langue source, inutile
    if ((l['sources'] as List?)?.isEmpty ?? true) continue;

    final lignes = <String>[];
    void ajoute(String role, Object? mots) {
      if (mots is! List || mots.isEmpty) return;
      final libelle = _roleLabels[role] ?? role;
      lignes.add('$libelle : ${mots.join(', ')}');
    }

    final actions = (l['actions'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final r in actions.keys) {
      ajoute(r, actions[r]);
    }
    final objets = (l['objects'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final r in objets.keys) {
      ajoute(r, objets[r]);
    }
    for (final r in ['urgent', 'alarm', 'directions', 'negations', 'feed']) {
      ajoute(r, l[r]);
    }

    final nombres = (l['numbers'] as Map?)?.cast<String, dynamic>();
    final unites = (nombres?['units'] as Map?)?.cast<String, dynamic>();
    if (unites != null && unites.isNotEmpty) {
      lignes.add('nombres : '
          '${unites.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    }
    if (lignes.isEmpty) continue;

    final statut = '${l['status'] ?? kLexiconDraft}';
    final relu = l['reviewed_by'] == null
        ? 'non relu par un locuteur'
        : 'relu par ${l['reviewed_by']}';
    out[code] = '=== MOTS ${('${l['name'] ?? code}').toUpperCase()} '
        'VÉRIFIÉS ($statut, $relu) ===\n'
        'Sers-toi de ces mots-là quand tu réponds dans cette langue. '
        "N'en invente pas d'autres : si une idée te manque, dis-la en "
        'français plutôt que de forger un mot.\n'
        '${lignes.join('\n')}';
  }
  return out;
}

/// Source du texte du lexique : la ressource embarquée. Les tests la remplacent
/// par un fichier du disque ou par un texte de leur cru.
final lexiconSourceProvider = Provider<Future<String> Function()>(
    (ref) => () => rootBundle.loadString(kLexiconAsset));

/// Le lexique chargé et validé, une seule fois par exécution.
final lexiconLoadProvider = FutureProvider<LexiconLoad>((ref) async {
  try {
    final load = loadLexiconFromSource(await ref.read(lexiconSourceProvider)());
    if (!load.available) debugPrint('Lexique indisponible : ${load.failure}');
    return load;
  } catch (e) {
    debugPrint('Lexique indisponible : $e');
    return LexiconLoad(failure: 'lexique introuvable : $e');
  }
});

/// Le lexique est chargé ET l'opérateur ne l'a pas coupé : l'assistant peut
/// comprendre des commandes simples sans modèle (donc agent IA désactivé, hors
/// ligne ou sans clé).
final lexiconUsableProvider = Provider<bool>((ref) {
  final on = ref.watch(aiAgentSettingsProvider.select((s) => s.lexiconEnabled));
  final available =
      ref.watch(lexiconLoadProvider).valueOrNull?.available ?? false;
  return on && available;
});
