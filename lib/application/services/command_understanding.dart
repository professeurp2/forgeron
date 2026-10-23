import 'dart:convert';

import '../../core/i18n/app_localizations.dart';
import '../../core/utils/command_lexicon.dart';
import '../providers/ai_agent_settings_provider.dart'
    show AiActionCategory, AiAutonomyLevel;

/// Porte d'entrée de l'assistant : ce qu'on fait d'un message AVANT tout
/// modèle de langage.
///
/// Le lexique fermé ([CommandLexicon]) lit le message ; ce fichier décide quoi
/// en faire. Les deux sont séparés exprès : le lexique est une donnée relue par
/// des locuteurs, la politique ci-dessous est du code relu par des ingénieurs,
/// et aucun des deux ne doit pouvoir changer l'autre en silence.
///
/// ## La politique (voir `docs/lexique-gouvernance.md`)
///
/// | Message compris… | Décision |
/// |---|---|
/// | arrêt d'urgence, appariement strict | **exécuté tout de suite**, quelle que soit la confiance dans la langue : se tromper en arrêtant coûte une pièce, se tromper en n'arrêtant pas coûte pire |
/// | lecture de l'état, appariement strict | exécutée tout de suite (ne déplace rien) |
/// | tout ce qui agit (mouvement, broche, origine…) | **confirmation** si la langue est « brouillon », si l'appariement est souple, ou si l'opérateur a réglé cette catégorie sur « confirmer » (défaut) ; exécuté directement seulement si les trois feux sont verts |
/// | appariement **souple** (faute de frappe, dictée), quoi que ce soit | toujours une suggestion à confirmer, arrêt d'urgence compris |
/// | refus pour **question** ou **négation** | le modèle n'a plus que les outils de lecture pour ce tour |
/// | tout autre refus | le modèle prend la suite, comme avant |
///
/// Le lexique ne rend jamais une coordonnée de son cru : il recopie les nombres
/// que l'opérateur a écrits ou dits, ou il refuse.
sealed class CommandDecision {
  const CommandDecision();
}

/// Pourquoi une action est exécutée sans confirmation.
enum RunReason {
  /// Arrêt d'urgence compris sans réserve.
  emergencyStop,

  /// Lecture seule : ne déplace rien, n'allume rien.
  readOnly,

  /// Langue relue, appariement strict, catégorie réglée sur « exécuter ».
  trustedAutonomy,
}

/// Pourquoi une action attend le geste de l'opérateur.
enum ConfirmReason {
  /// Un mot vient d'une langue au statut « brouillon » (pas de relecteur nommé).
  draftLanguage,

  /// Appariement souple : une suggestion, pas une lecture sûre.
  suggestion,

  /// Réglage de l'opérateur (Paramètres > Agent IA > permissions).
  autonomy,

  /// Outil sans catégorie de permission : par prudence, on demande.
  uncategorized,
}

/// Exécuter maintenant, sans le modèle.
class RunNow extends CommandDecision {
  const RunNow(this.match, this.reason);
  final LexiconMatch match;
  final RunReason reason;
}

/// Montrer la carte de confirmation ; rien ne part sans le geste de l'opérateur.
class AskConfirmation extends CommandDecision {
  const AskConfirmation(this.match, this.reasons);
  final LexiconMatch match;
  final Set<ConfirmReason> reasons;
}

/// Pas d'action déduite, mais le refus dit que le message n'est PAS un ordre
/// (question, négation) : le modèle ne reçoit que les outils de lecture.
class RestrictToReading extends CommandDecision {
  const RestrictToReading(this.refusal);
  final String refusal;
}

/// Rien à faire ici : le modèle (ou le message d'aide, sans modèle) prend la
/// suite. [refusal] est la raison du lexique, pour le journal et l'aide.
class DeferToModel extends CommandDecision {
  const DeferToModel(this.refusal);
  final String refusal;
}

/// Raisons de refus qui disent « ceci n'est pas un ordre ».
///
/// Mesuré (étude des langues locales, §4) : un modèle qui lit mal une langue
/// « se raccroche au mot connu » et lance le homing pour « c'est quoi le homing
/// ? » ou allume la broche pour « ne démarre pas la broche ». Priver le modèle
/// des outils qui agissent, pour ces tours-là seulement, supprime ces gestes
/// sans toucher aux autres.
bool isSignalRefusal(String refusal) =>
    refusal == 'question' || refusal == 'negation';

/// Préfixes des outils de LECTURE : ce qui reste au modèle quand le lexique a
/// reconnu une question ou une négation. Même règle que Forgeron-Bench
/// (`BENCH_GATE=1`), qui l'importe d'ici pour mesurer le produit lui-même.
const kReadOnlyToolPrefixes = ['get_', 'list_', 'read_', 'analyze_', 'preview_'];

bool isReadOnlyToolName(String name) =>
    kReadOnlyToolPrefixes.any(name.startsWith);

class CommandUnderstanding {
  CommandUnderstanding(
    this.lexicon, {
    required this.categoryOf,
    required this.levelFor,
    this.softMaxWords = 6,
  });

  final CommandLexicon lexicon;

  /// Catégorie de permission d'un outil (`null` = pas de porte).
  final AiActionCategory? Function(String tool) categoryOf;

  /// Niveau d'autonomie réglé par l'opérateur pour une catégorie.
  final AiAutonomyLevel Function(AiActionCategory category) levelFor;

  /// Au-delà, on ne tente pas l'appariement souple : une longue phrase pleine
  /// de mots inconnus n'est pas une faute de frappe.
  final int softMaxWords;

  /// Raisons de refus pour lesquelles l'appariement souple a une chance : le
  /// message ressemble à une commande abîmée, pas à autre chose.
  static const _softRetryable = {'mots_inconnus', 'aucune_intention'};

  CommandDecision decide(String text) {
    final strict = lexicon.interpret(text);
    final match = strict.match;
    if (match != null) return _route(match);

    final refusal = strict.refusal ?? 'aucune_intention';
    if (isSignalRefusal(refusal)) return RestrictToReading(refusal);

    if (_softRetryable.contains(refusal) &&
        text.trim().split(RegExp(r'\s+')).length <= softMaxWords) {
      final soft = lexicon.interpret(text, relaxed: true).match;
      if (soft != null) return _route(soft);
    }
    return DeferToModel(refusal);
  }

  CommandDecision _route(LexiconMatch m) {
    // Une suggestion se confirme TOUJOURS — l'arrêt d'urgence compris : le
    // chemin immédiat est réservé à ce que le lexique a lu sans réserve.
    if (m.relaxed) {
      return AskConfirmation(m, {
        ConfirmReason.suggestion,
        if (!m.trusted) ConfirmReason.draftLanguage,
      });
    }
    if (m.tool == 'emergency_stop') return RunNow(m, RunReason.emergencyStop);
    if (m.readOnly) return RunNow(m, RunReason.readOnly);

    final reasons = <ConfirmReason>{};
    if (!m.trusted) reasons.add(ConfirmReason.draftLanguage);
    final category = categoryOf(m.tool);
    if (category == null) {
      reasons.add(ConfirmReason.uncategorized);
    } else if (levelFor(category) == AiAutonomyLevel.requireConfirmation) {
      reasons.add(ConfirmReason.autonomy);
    }
    if (reasons.isEmpty) return RunNow(m, RunReason.trustedAutonomy);
    return AskConfirmation(m, reasons);
  }
}

// ── Ce que l'opérateur lit ─────────────────────────────────────────────────

/// Libellé de la langue pour l'opérateur (« bambara », « français »…). Les codes
/// inconnus s'affichent tels quels.
String lexiconLanguageLabel(String code) {
  switch (code) {
    case 'fr':
      return tr('français');
    case 'en':
      return tr('anglais');
    case 'bm':
      return tr('bambara');
    case 'wo':
      return tr('wolof');
    case 'sw':
      return tr('swahili');
    case 'ar':
      return tr('arabe');
    case 'ha':
      return tr('haoussa');
    case 'am':
      return tr('amharique');
    default:
      return code;
  }
}

/// Phrase qui dit POURQUOI on demande, en une ligne — sans jargon.
String confirmReasonText(Set<ConfirmReason> reasons, List<String> languages) {
  final parts = <String>[];
  if (reasons.contains(ConfirmReason.suggestion)) {
    parts.add(tr('J\'ai compris à peu près : vérifie avant de confirmer.'));
  }
  if (reasons.contains(ConfirmReason.draftLanguage)) {
    final names = languages.map(lexiconLanguageLabel).join(' / ');
    parts.add(tr(
        'Ces mots ({}) n\'ont pas encore été relus par un locuteur : je demande avant d\'agir.',
        [names.isEmpty ? '—' : names]));
  }
  if (parts.isEmpty) parts.add(tr('Confirmation requise par tes réglages.'));
  return parts.join(' ');
}

/// Résumé lisible de `get_machine_state` — uniquement des valeurs que le
/// contrôleur a rapportées ; hors ligne, AUCUNE position (jamais de zéros
/// présentés comme une lecture).
String describeMachineState(Map<String, dynamic> s) {
  final status = '${s['status'] ?? 'offline'}';
  if (status == 'offline') {
    return tr('Machine hors ligne : aucune lecture disponible.');
  }
  String n(num v) {
    final t = v.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    return t == '-0' ? '0' : t;
  }

  String pos(Object? raw) {
    final list = (raw as List?)?.whereType<num>().toList() ?? const <num>[];
    if (list.length < 3) return '—';
    const names = ['X', 'Y', 'Z', 'A', 'C'];
    return [
      for (var i = 0; i < list.length && i < names.length; i++)
        '${names[i]} ${n(list[i])}${i >= 3 ? '°' : ''}',
    ].join(' · ');
  }

  final label = switch (status) {
    'idle' => tr('au repos (Idle)'),
    'run' => tr('en cycle (Run)'),
    'hold' => tr('en pause (Hold)'),
    'alarm' => tr('ALARME'),
    'home' => tr('homing en cours'),
    'check' => tr('mode vérification (Check)'),
    'door' => tr('porte ouverte (Door)'),
    'sleep' => tr('en veille (Sleep)'),
    _ => status,
  };
  final lines = <String>[
    tr('État : {}', [label]),
    tr('Position pièce : {}', [pos(s['wPos'])]),
    tr('Position machine : {}', [pos(s['mPos'])]),
  ];
  final wcs = s['activeWCS'];
  final tool = s['activeToolNum'];
  if (wcs != null) lines.add(tr('Origine active : {} · outil T{}', [wcs, tool ?? 0]));
  final feed = s['feedrate'];
  final rpm = s['spindleSpeed'];
  if (feed is num || rpm is num) {
    lines.add(tr('Avance {} mm/min · broche {} tr/min',
        [feed is num ? n(feed) : '—', rpm is num ? n(rpm) : '—']));
  }
  final ov = s['overrides'];
  if (ov is List && ov.length >= 3) {
    lines.add(tr('Réglages en direct : avance {} % · rapide {} % · broche {} %',
        [ov[0], ov[1], ov[2]]));
  }
  final alarm = s['alarmCode'];
  if (alarm != null) lines.add(tr('Alarme {} en cours.', [alarm]));
  return lines.join('\n');
}

/// L'action en une phrase ordinaire, pour la carte de confirmation (« Allumer
/// la broche », « Déplacer l'axe X de +5 mm à 300 mm/min »). Jamais le nom
/// technique de l'outil.
String lexiconActionLabel(LexiconMatch m) {
  switch (m.intent) {
    case 'urgence':
      return tr('Arrêt d\'urgence');
    case 'etat':
      return tr('Lire l\'état de la machine');
    case 'pause':
      return tr('Mettre le programme en pause');
    case 'homing':
      return tr('Lancer le homing (la machine va vers ses capteurs)');
    case 'zero':
      return tr('Poser le zéro pièce à la position actuelle');
    case 'brocheon':
      return tr('Allumer la broche');
    case 'brocheoff':
      return tr('Éteindre la broche');
    case 'jog':
      final axis = '${m.args['axis']}';
      final rotary = axis == 'A' || axis == 'C';
      final d = m.args['distance'];
      final signed = d is num && d >= 0 ? '+$d' : '$d';
      return tr('Déplacer l\'axe {} de {} {} à {} {}', [
        axis,
        signed,
        rotary ? '°' : 'mm',
        m.args['feedrate'],
        rotary ? '°/min' : 'mm/min',
      ]);
    default:
      return m.tool;
  }
}

/// Réponse affichée une fois l'outil exécuté. Aucune génération : une phrase
/// fixe, relue pour la langue de l'opérateur si elle l'est, sinon dans la
/// langue de l'application.
///
/// [lexicon] peut manquer (fichier retiré entre la demande et la
/// confirmation) : on répond alors dans la langue de l'application.
String lexiconReply({
  required LexiconMatch match,
  required String toolResult,
  required CommandLexicon? lexicon,
}) {
  String fixed(String key, String fallback) =>
      lexicon?.reply(key, match.languages) ?? fallback;

  if (match.intent == 'etat') {
    try {
      return describeMachineState(
          (jsonDecode(toolResult) as Map).cast<String, dynamic>());
    } catch (_) {
      return tr('Je n\'ai pas pu lire l\'état de la machine.');
    }
  }

  final ok = toolResult.startsWith('OK');
  if (match.intent == 'urgence') {
    return ok
        ? fixed('estop_sent', tr('Arrêt d\'urgence envoyé à la machine.'))
        : fixed(
            'estop_failed',
            tr('ATTENTION — {}. Utilise le bouton rouge « Arrêt d\'urgence » ou coupe l\'alimentation.',
                [toolResult]));
  }
  if (!ok) {
    return tr('Non exécuté — {}', [toolResult]);
  }
  final String done;
  switch (match.intent) {
    case 'pause':
      done = fixed('program_paused', tr('Programme mis en pause.'));
    case 'homing':
      done = fixed('homing_started',
          tr('Homing lancé : la machine va vers ses capteurs de fin de course.'));
    case 'zero':
      done = fixed('zero_set', tr('Zéro pièce posé à la position actuelle.'));
    case 'brocheon':
      done = fixed('spindle_on', tr('Broche allumée.'));
    case 'brocheoff':
      done = fixed('spindle_off', tr('Broche éteinte.'));
    case 'jog':
      final a = match.args;
      final rotary = a['axis'] == 'A' || a['axis'] == 'C';
      done = '${fixed('done', tr('C\'est fait.'))} '
          '${a['axis']} ${a['distance']} ${rotary ? '°' : 'mm'} · F${a['feedrate']}';
    default:
      done = fixed('done', tr('C\'est fait.'));
  }
  // Un mouvement accepté « avec attention » (près d'une limite) le dit : la
  // mise en garde de l'outil ne doit pas se perdre dans une phrase fixe.
  final warning = RegExp(r'attention\s*:\s*(.+)$', dotAll: true).firstMatch(toolResult);
  return warning == null ? done : '$done\n⚠ ${warning.group(1)!.trim()}';
}

/// Réponse quand il n'y a PAS de modèle pour répondre (assistant désactivé,
/// pas de clé, serveur absent) et que le lexique n'a rien compris. Dit ce qui
/// manque et ce qui marche quand même.
String lexiconHelp(String? refusal) {
  final examples = tr(
      'Sans l\'assistant IA je comprends des ordres courts : « arrête », '
      '« état de la machine », « pause », « homing », « allume la broche », '
      '« éteins la broche », « zéro pièce », « avance X de 5 mm à 300 ».');
  switch (refusal) {
    case 'negation':
      return '${tr('Je ne traite pas les phrases négatives : dis simplement ce que tu veux faire.')} $examples';
    case 'question':
      return '${tr('C\'est une question : il faut activer l\'assistant IA pour y répondre.')} $examples';
    case 'condition':
      return '${tr('Je ne fais qu\'un ordre à la fois : donne-les l\'un après l\'autre.')} $examples';
    case 'direction':
      return tr(
          'Je ne devine pas un sens de déplacement avec un mot (« recule », « monte »). '
          'Donne l\'axe, le signe et la distance : « avance X de -5 mm à 300 ».');
    case 'nombre_ambigu':
      return tr('Un nombre écrit en lettres peut se lire de deux façons : écris-le en chiffres.');
    case 'manque:axe':
      return tr('Il manque l\'axe : X, Y, Z, A ou C.');
    case 'manque:distance':
      return tr('Il manque la distance (en mm, ou en degrés pour A et C).');
    case 'manque:vitesse':
      return tr('Il manque la vitesse (par exemple « à 300 »).');
    case 'trop_long':
      return tr('Phrase trop longue : une commande à la fois, en peu de mots.');
    default:
      return '${tr('Je n\'ai pas compris.')} $examples';
  }
}
