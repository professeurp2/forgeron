/// Validation du fichier de données du lexique (`assets/lexicon/lexique.json`).
///
/// **Pourquoi.** Le lexique est de la DONNÉE écrite et relue par des personnes,
/// pas du code qu'un compilateur vérifie. Une virgule de travers, un outil qui
/// n'existe plus, une tolérance de « mots inconnus » mise sur un ordre qui
/// déplace la machine : rien de tout cela ne planterait — la machine ferait
/// juste autre chose que ce qui a été dit. Ce validateur est la porte entre
/// « quelqu'un a modifié le fichier » et « l'application le croit » : au
/// chargement (`lexicon_provider.dart`) et dans la suite de tests.
///
/// Deux sortes de constats :
/// - **erreur** : le fichier n'est pas chargé, l'assistant fonctionne comme s'il
///   n'y avait pas de lexique (jamais l'inverse : pas de lexique à moitié cru) ;
/// - **avertissement** : signalé aux relecteurs, sans bloquer.
///
/// Les invariants de SÉCURITÉ sont des erreurs, pas des conseils :
/// - un ordre qui agit sur la machine ne tolère AUCUN mot inconnu ;
/// - un ordre « lecture seule » ne peut pas viser un outil soumis à confirmation ;
/// - seule l'intention d'arrêt d'urgence peut être déclenchée par un mot
///   d'alarme isolé ;
/// - une langue ne passe à `relu` qu'avec le nom d'une PERSONNE et une date ;
/// - deux mots confondables qui veulent dire autre chose sont refusés.
library;

import 'command_lexicon.dart';

enum LexiconSeverity { error, warning }

/// Un constat de validation, localisé dans le fichier par son chemin
/// (`languages.bm.actions.stop[1]`).
class LexiconIssue {
  const LexiconIssue(this.severity, this.path, this.message);

  final LexiconSeverity severity;
  final String path;
  final String message;

  bool get isError => severity == LexiconSeverity.error;

  @override
  String toString() =>
      '${isError ? 'ERREUR' : 'avertissement'} $path : $message';
}

/// Ce que le validateur doit savoir d'un outil de l'agent pour vérifier qu'une
/// intention l'appelle correctement.
class LexiconToolInfo {
  const LexiconToolInfo({required this.schema, required this.gated});

  /// `inputSchema` de l'outil (JSON Schema simplifié : `properties`, `required`).
  final Map<String, dynamic> schema;

  /// L'outil est soumis à la porte de confirmation (`category != null`).
  final bool gated;
}

/// Résultat d'une validation.
class LexiconValidation {
  const LexiconValidation(this.issues);

  final List<LexiconIssue> issues;

  List<LexiconIssue> get errors =>
      issues.where((i) => i.isError).toList(growable: false);
  List<LexiconIssue> get warnings =>
      issues.where((i) => !i.isError).toList(growable: false);
  bool get ok => errors.isEmpty;

  @override
  String toString() => issues.map((i) => '$i').join('\n');
}

/// Clés de phrases fixes qu'une langue relue peut fournir (`replies`).
///
/// Les phrases de sécurité en tête : ce sont celles qu'on ne peut pas laisser
/// improviser (voir [CommandLexicon.reply]).
const kLexiconReplyKeys = <String>{
  'estop_sent', // Arrêt d'urgence transmis à la machine.
  'estop_failed', // Arrêt d'urgence NON transmis : utiliser le bouton rouge.
  'machine_offline', // La machine n'est pas connectée.
  'not_understood', // Je n'ai pas compris, répétez.
  'confirm_ask', // Confirmez cette action.
  'cancelled', // Action annulée.
  'done', // C'est fait.
  'spindle_on', // La broche est allumée.
  'spindle_off', // La broche est éteinte.
  'program_paused', // Programme en pause.
  'homing_started', // Homing lancé.
  'zero_set', // Zéro pièce posé.
  'move_refused', // Mouvement refusé.
};

const _languageKeys = <String>{
  'name', 'status', 'reviewed_by', 'reviewed_on', 'script', 'sources',
  'notes', 'actions', 'light', 'polite', 'objects', 'urgent', 'alarm', 'fillers',
  'negations', 'conditions', 'directions', 'questions', 'feed', 'units',
  'numbers', 'replies',
};
const _wordListRoles = <String>[
  'light', 'polite', 'urgent', 'alarm', 'fillers', 'negations', 'conditions',
  'directions', 'questions', 'feed',
];
const _wordMapRoles = <String>['actions', 'objects', 'units'];
const _slotNames = <String>{'axis', 'distance', 'feedrate'};
const _statuses = <String>{kLexiconDraft, kLexiconReviewed};
const _maxEntryTokens = 6;

final _langId = RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]+)?$');
final _semver = RegExp(r'^\d+\.\d+\.\d+$');
final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _notAPerson = RegExp(
    r'\b(claude|anthropic|assistant|chatgpt|gpt|gemini|qwen|llama|bot|ia|ai|'
    r'modele|modèle|machine|auto|automatique)\b',
    caseSensitive: false);

/// Vérifie [json] et rend tous les constats (jamais d'exception sur un fichier
/// malformé : un champ du mauvais type devient une erreur localisée).
///
/// [tools] (nom → [LexiconToolInfo]) permet de vérifier que chaque intention
/// appelle un outil qui existe, avec des arguments que son schéma accepte.
/// Sans lui, ces contrôles sont sautés — les tests et le chargement de
/// l'application le fournissent toujours.
LexiconValidation validateLexiconJson(
  Map<String, dynamic> json, {
  Map<String, LexiconToolInfo>? tools,
}) {
  final out = <LexiconIssue>[];
  void error(String path, String msg) =>
      out.add(LexiconIssue(LexiconSeverity.error, path, msg));
  void warn(String path, String msg) =>
      out.add(LexiconIssue(LexiconSeverity.warning, path, msg));

  // ── En-tête ──────────────────────────────────────────────────────────────
  final schema = json['schema'];
  if (schema != kLexiconSchema) {
    error('schema',
        'format $schema non pris en charge (ce moteur lit le format $kLexiconSchema)');
  }
  final version = json['version'];
  if (version is! String || !_semver.hasMatch(version)) {
    error('version',
        'attendu « MAJEUR.MINEUR.CORRECTIF » (ex. 0.2.0), trouvé « $version »');
  }
  for (final k in json.keys) {
    if (!const {'schema', 'version', 'note', 'intents', 'languages'}.contains(k)) {
      warn(k, 'clé inconnue au niveau supérieur (faute de frappe ?)');
    }
  }

  // ── Langues ──────────────────────────────────────────────────────────────
  final languages = json['languages'];
  final actionKeys = <String>{}; // actions définies par au moins une langue
  final objectKeys = <String>{};
  if (languages is! Map || languages.isEmpty) {
    error('languages', 'au moins une langue est attendue');
  } else {
    for (final entry in languages.entries) {
      final lang = '${entry.key}';
      final base = 'languages.$lang';
      if (!_langId.hasMatch(lang)) {
        error(base, 'identifiant de langue invalide (ex. fr, bm, wo, en-GB)');
      }
      final block = entry.value;
      if (block is! Map) {
        error(base, 'un bloc de langue est attendu');
        continue;
      }
      _validateLanguage(
        lang, base, block.cast<String, dynamic>(), error, warn,
        actionKeys, objectKeys,
      );
    }
  }

  // ── Intentions ───────────────────────────────────────────────────────────
  final intents = json['intents'];
  final seenIntentTool = <String, String>{};
  final seenSignatures = <String>{};
  if (intents is! List || intents.isEmpty) {
    error('intents', 'au moins une intention est attendue');
  } else {
    for (var i = 0; i < intents.length; i++) {
      final base = 'intents[$i]';
      final raw = intents[i];
      if (raw is! Map) {
        error(base, 'un objet est attendu');
        continue;
      }
      final it = raw.cast<String, dynamic>();
      final id = it['id'];
      final tool = it['tool'];
      if (id is! String || id.trim().isEmpty) error('$base.id', 'identifiant manquant');
      if (tool is! String || tool.trim().isEmpty) error('$base.tool', 'outil manquant');
      for (final k in it.keys) {
        if (!const {
          'id', 'tool', 'args', 'action', 'object', 'need', 'slots',
          'read_only', 'alarm_alone', 'tolerance', 'note',
        }.contains(k)) {
          warn('$base.$k', 'clé inconnue');
        }
      }

      final actions = it['action'];
      final objects = it['object'];
      if (actions is! List || actions.isEmpty) {
        error('$base.action', 'liste attendue (null = aucun verbe)');
      } else {
        for (final a in actions) {
          if (a != null && (a is! String || !actionKeys.contains(a))) {
            error('$base.action',
                '« $a » n\'est défini dans aucune langue (languages.*.actions)');
          }
        }
      }
      if (objects is! List || objects.isEmpty) {
        error('$base.object', 'liste attendue (null = aucun objet)');
      } else {
        for (final o in objects) {
          if (o != null && (o is! String || !objectKeys.contains(o))) {
            error('$base.object',
                '« $o » n\'est défini dans aucune langue (languages.*.objects)');
          }
        }
      }
      final need = it['need'];
      if (need is List) {
        for (final n in need) {
          if (!objectKeys.contains(n)) {
            error('$base.need', '« $n » n\'est défini dans aucune langue');
          }
        }
      }

      final slots = it['slots'];
      final slotList = <String>[];
      if (slots != null) {
        if (slots is! List) {
          error('$base.slots', 'liste attendue');
        } else {
          for (final s in slots) {
            if (s is! String || !_slotNames.contains(s)) {
              error('$base.slots',
                  '« $s » inconnu (permis : ${_slotNames.join(', ')})');
            } else {
              slotList.add(s);
            }
          }
        }
      }
      final args = it['args'];
      if (args != null && args is! Map) error('$base.args', 'objet attendu');

      final readOnly = it['read_only'] == true;
      final alarmAlone = it['alarm_alone'] == true;
      final tolerance = it['tolerance'];
      if (tolerance != null && (tolerance is! int || tolerance < 0 || tolerance > 2)) {
        error('$base.tolerance', 'entier de 0 à 2 attendu');
      }
      final tol = tolerance is int ? tolerance : 0;

      // Invariants de sécurité.
      if (!readOnly && tol != 0) {
        error('$base.tolerance',
            'un ordre qui agit sur la machine ne tolère AUCUN mot inconnu '
            '(tolérance 0 obligatoire hors lecture seule)');
      }
      if (alarmAlone && tool != 'emergency_stop') {
        error('$base.alarm_alone',
            'seul l\'arrêt d\'urgence (emergency_stop) peut être déclenché par '
            'un mot d\'alarme isolé');
      }
      if (alarmAlone && readOnly) {
        error(base, 'un arrêt d\'urgence n\'est pas une lecture seule');
      }

      // Cohérence d'une même intention répétée (ex. « etat » par deux chemins).
      if (id is String && tool is String) {
        final sig = '$tool|${args is Map ? args.toString() : ''}|${slotList.join(',')}';
        final prev = seenIntentTool[id];
        if (prev != null && prev != sig) {
          error('$base.id',
              'l\'intention « $id » est déclarée deux fois avec des outils ou '
              'des arguments différents');
        }
        seenIntentTool[id] = sig;
        final pathSig = '$id|${actions.toString()}|${objects.toString()}|${need.toString()}';
        if (!seenSignatures.add(pathSig)) {
          warn(base, 'intention en double (même verbe et même objet)');
        }
      }

      // Outil et arguments (si le catalogue est fourni).
      if (tools != null && tool is String) {
        final info = tools[tool];
        if (info == null) {
          error('$base.tool', 'l\'outil « $tool » n\'existe pas dans le catalogue');
        } else {
          if (readOnly && info.gated) {
            error('$base.read_only',
                'l\'outil « $tool » est soumis à confirmation : il ne peut pas '
                'être déclaré en lecture seule');
          }
          final props = (info.schema['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
          final required = ((info.schema['required'] as List?) ?? const []).cast<String>();
          final given = <String>{
            if (args is Map) ...args.keys.map((k) => '$k'),
            ...slotList,
          };
          for (final k in given) {
            if (!props.containsKey(k)) {
              error(base, 'l\'outil « $tool » n\'a pas d\'argument « $k »');
            }
          }
          for (final r in required) {
            if (!given.contains(r)) {
              error(base, 'l\'argument obligatoire « $r » de « $tool » n\'est '
                  'fourni ni par args ni par slots');
            }
          }
          if (args is Map) {
            for (final e in args.entries) {
              final spec = props['${e.key}'];
              final allowed = spec is Map ? spec['enum'] : null;
              if (allowed is List && !allowed.contains(e.value)) {
                error('$base.args.${e.key}',
                    'valeur « ${e.value} » hors de ${allowed.join('/')}');
              }
            }
          }
        }
      }
    }
  }

  // ── Mots confondables (nécessite un fichier structurellement sain) ──────
  if (!out.any((i) => i.isError)) {
    try {
      final engine = CommandLexicon.fromJson(json);
      for (final c in engine.conflicts()) {
        error('languages', 'mots confondables qui veulent dire autre chose : $c');
      }
    } catch (e) {
      error('languages', 'le moteur ne peut pas construire ce lexique : $e');
    }
  }

  return LexiconValidation(out);
}

void _validateLanguage(
  String lang,
  String base,
  Map<String, dynamic> l,
  void Function(String, String) error,
  void Function(String, String) warn,
  Set<String> actionKeys,
  Set<String> objectKeys,
) {
  for (final k in l.keys) {
    if (!_languageKeys.contains(k)) warn('$base.$k', 'clé inconnue');
  }

  // Statut et relecture : la porte entre « brouillon » et « on peut s'y fier ».
  final status = l['status'] ?? kLexiconDraft;
  final by = l['reviewed_by'];
  final on = l['reviewed_on'];
  if (status is! String || !_statuses.contains(status)) {
    error('$base.status', 'attendu : ${_statuses.join(' ou ')}');
  } else if (status == kLexiconReviewed) {
    if (by is! String || by.trim().length < 3) {
      error('$base.reviewed_by',
          'une langue « relu » exige le NOM d\'un relecteur');
    } else if (_notAPerson.hasMatch(by)) {
      error('$base.reviewed_by',
          '« $by » n\'est pas une personne : une langue ne devient « relu » '
          'que lue par un locuteur, jamais par un modèle ou un script');
    }
    if (on is! String || !_isoDate.hasMatch(on) || DateTime.tryParse(on) == null) {
      error('$base.reviewed_on', 'date de relecture attendue (AAAA-MM-JJ)');
    }
  } else {
    if (by != null || on != null) {
      error('$base.status',
          'reviewed_by / reviewed_on renseignés mais le statut est « brouillon » '
          '— passez le statut à « relu » ou videz ces champs');
    }
  }

  // Listes de mots.
  for (final role in _wordListRoles) {
    final v = l[role];
    if (v == null) continue;
    if (v is! List) {
      error('$base.$role', 'liste attendue');
      continue;
    }
    _validateWords(v, '$base.$role', error, warn);
  }
  for (final role in _wordMapRoles) {
    final v = l[role];
    if (v == null) continue;
    if (v is! Map) {
      error('$base.$role', 'objet attendu (sens → liste de mots)');
      continue;
    }
    for (final e in v.entries) {
      if (e.value is! List) {
        error('$base.$role.${e.key}', 'liste attendue');
        continue;
      }
      if (role == 'actions') actionKeys.add('${e.key}');
      if (role == 'objects') objectKeys.add('${e.key}');
      _validateWords(e.value as List, '$base.$role.${e.key}', error, warn);
    }
  }

  // Nombres.
  final n = l['numbers'];
  if (n != null) {
    if (n is! Map) {
      error('$base.numbers', 'objet attendu');
    } else {
      _validateNumbers(n.cast<String, dynamic>(), '$base.numbers', error, warn);
    }
  }

  // Phrases fixes.
  final replies = l['replies'];
  if (replies != null) {
    if (replies is! Map) {
      error('$base.replies', 'objet attendu (clé → phrase)');
    } else {
      for (final e in replies.entries) {
        if (!kLexiconReplyKeys.contains('${e.key}')) {
          error('$base.replies.${e.key}',
              'phrase inconnue (permises : ${kLexiconReplyKeys.join(', ')})');
        }
        if (e.value is! String || (e.value as String).trim().isEmpty) {
          error('$base.replies.${e.key}', 'texte non vide attendu');
        }
      }
      if (status != kLexiconReviewed && replies.isNotEmpty) {
        warn('$base.replies',
            'ces phrases ne seront JAMAIS affichées tant que la langue est '
            'brouillon (l\'application répond dans sa propre langue)');
      }
    }
  }
}

void _validateWords(
  List words,
  String path,
  void Function(String, String) error,
  void Function(String, String) warn,
) {
  final seen = <String>{};
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    final p = '$path[$i]';
    if (w is! String) {
      error(p, 'texte attendu');
      continue;
    }
    if (w.trim().isEmpty) {
      error(p, 'mot vide');
      continue;
    }
    if (w != w.trim()) warn(p, '« $w » : espaces en début ou fin');
    // Le découpage est celui du moteur (apostrophes, tirets, lettres africaines) :
    // ce que le validateur compte est ce que le moteur lira.
    final toks = lexiconWords(w);
    if (toks.length > _maxEntryTokens) {
      error(p, '« $w » : plus de $_maxEntryTokens mots');
    }
    final key = toks.join(' ');
    if (!seen.add(key)) warn(p, '« $w » : doublon (une fois pliées les lettres africaines)');
  }
}

void _validateNumbers(
  Map<String, dynamic> n,
  String base,
  void Function(String, String) error,
  void Function(String, String) warn,
) {
  final style = n['style'];
  if (style != 'multiplier_first' && style != 'multiplier_after') {
    error('$base.style', 'attendu : multiplier_first ou multiplier_after');
  }
  final allWords = <String, String>{}; // mot plié → où il est déclaré

  void claim(String word, String where) {
    final k = foldWord(word);
    final prev = allWords[k];
    if (prev != null && prev != where) {
      error(base, '« $word » est déclaré deux fois ($prev et $where) : un '
          'nombre ne se devine pas');
    }
    allWords[k] = where;
  }

  Map<String, dynamic> table(String key, bool Function(int) valid, String hint) {
    final v = n[key];
    if (v == null) return const {};
    if (v is! Map) {
      error('$base.$key', 'objet attendu (mot → valeur)');
      return const {};
    }
    final out = <String, dynamic>{};
    for (final e in v.entries) {
      final val = e.value;
      if (val is! int || !valid(val)) {
        error('$base.$key.${e.key}', 'valeur $hint attendue, trouvé « $val »');
      }
      claim('${e.key}', key);
      out['${e.key}'] = val;
    }
    return out;
  }

  final units = table('units', (v) => v >= 1 && v <= 19, 'entière de 1 à 19');
  table('tens', (v) => v >= 10 && v <= 90 && v % 10 == 0, 'multiple de 10 (10 à 90)');
  for (final key in ['hundred', 'thousand', 'connectors']) {
    final v = n[key];
    if (v == null) continue;
    if (v is! List) {
      error('$base.$key', 'liste attendue');
      continue;
    }
    for (final w in v) {
      if (w is! String || w.trim().isEmpty) {
        error('$base.$key', 'mot attendu');
      } else {
        claim(w, key);
      }
    }
  }
  final prefix = n['tens_prefix'];
  if (prefix != null) {
    if (prefix is! String || prefix.trim().isEmpty) {
      error('$base.tens_prefix', 'mot attendu');
    } else {
      claim(prefix, 'tens_prefix');
    }
  }
  for (final k in n.keys) {
    if (!const {
      'style', 'units', 'tens', 'hundred', 'thousand', 'connectors',
      'tens_prefix', 'quatre_vingt',
    }.contains(k)) {
      warn('$base.$k', 'clé inconnue');
    }
  }
  // Un chiffre sans mot laisse un trou que personne ne verrait. « 1 » est
  // exclu : en français « un » est aussi l'article, donc volontairement absent.
  if (units.isNotEmpty) {
    final values = units.values.whereType<int>().toSet();
    for (var v = 2; v <= 9; v++) {
      if (!values.contains(v)) {
        warn('$base.units', 'aucun mot pour $v (un trou dans les chiffres)');
      }
    }
  }
}
