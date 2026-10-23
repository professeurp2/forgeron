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
  const LexiconLoad({this.lexicon, this.issues = const [], this.failure});

  final CommandLexicon? lexicon;

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
    );
  } catch (e) {
    return LexiconLoad(failure: 'lexique illisible : $e');
  }
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
