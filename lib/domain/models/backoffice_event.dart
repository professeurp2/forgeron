import 'package:flutter/foundation.dart';

/// D'où vient un événement du backoffice.
enum BackofficeSource {
  /// L'agent IA : messages, tours de modèle, appels d'outils.
  ia,

  /// Le relais PC ↔ téléphone (chat synchronisé).
  relais,

  /// La carte FluidNC : commandes envoyées, réponses, alarmes, statut.
  firmware,

  /// Un garde-fou déterministe a refusé ou corrigé quelque chose.
  garde,

  /// Le veilleur d'événements critiques (alarme, arrêt d'urgence, surchauffe).
  veilleur,

  /// L'application elle-même (démarrage, export, vidage du journal).
  systeme,
}

/// Gravité d'un événement. `warning` et `critical` sont des « problèmes ».
enum BackofficeSeverity { info, notice, warning, critical }

/// Qui est à l'origine d'une action.
abstract final class BackofficeOrigin {
  /// Cet appareil (l'opérateur devant l'écran, ou l'agent qui y tourne).
  static const local = 'local';

  /// Le téléphone relié par le relais de chat.
  static const relais = 'relais';

  /// Le lexique fermé, sans modèle.
  static const lexique = 'lexique';

  /// Le modèle de langage (il a décidé l'appel d'outil).
  static const modele = 'modele';

  /// L'opérateur, par l'interface (jog, bouton, terminal).
  static const operateur = 'operateur';

  /// Le veilleur d'événements critiques.
  static const veilleur = 'veilleur';
}

/// Un événement du backoffice : UNE chose qui s'est passée, horodatée, avec
/// de quoi la relier aux autres.
///
/// Trois identifiants de corrélation, tous optionnels :
/// - [turnId] : le message de l'opérateur qui a déclenché la suite (tours de
///   modèle, appels d'outils, commandes envoyées à la carte) ;
/// - [callId] : un appel d'outil précis — c'est lui qui relie « l'IA a
///   demandé jog_axis » à « la commande est partie » puis à « la carte a
///   répondu ok » ;
/// - [origin] : qui a agi (voir [BackofficeOrigin]).
@immutable
class BackofficeEvent {
  const BackofficeEvent({
    required this.seq,
    required this.time,
    required this.source,
    required this.kind,
    required this.summary,
    this.severity = BackofficeSeverity.info,
    this.details = const {},
    this.turnId,
    this.callId,
    this.origin,
  });

  /// Numéro d'ordre dans la session (croissant, jamais réutilisé).
  final int seq;
  final DateTime time;
  final BackofficeSource source;

  /// Type d'événement, en pointillés : `ia.tour`, `firmware.tx`,
  /// `garde.gcode`… Stable, sert aux filtres et aux statistiques.
  final String kind;
  final BackofficeSeverity severity;

  /// Une ligne lisible par l'opérateur.
  final String summary;

  /// Le détail (arguments, résultat, latence…), montré déplié.
  final Map<String, dynamic> details;

  final String? turnId;
  final String? callId;
  final String? origin;

  bool get isProblem => severity.index >= BackofficeSeverity.warning.index;

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'ts': time.toUtc().toIso8601String(),
    'source': source.name,
    'kind': kind,
    'severity': severity.name,
    'summary': summary,
    if (details.isNotEmpty) 'details': details,
    if (turnId != null) 'turn': turnId,
    if (callId != null) 'call': callId,
    if (origin != null) 'origin': origin,
  };

  /// `null` si la ligne est illisible : une ligne corrompue n'est jamais
  /// fatale (un fichier de préférences plein de zéros est déjà arrivé).
  static BackofficeEvent? fromJson(Map<String, dynamic> j) {
    try {
      return BackofficeEvent(
        seq: (j['seq'] as num).toInt(),
        time: DateTime.parse(j['ts'] as String).toLocal(),
        source: BackofficeSource.values.byName(j['source'] as String),
        kind: j['kind'] as String,
        severity: BackofficeSeverity.values.byName(j['severity'] as String),
        summary: j['summary'] as String,
        details: ((j['details'] as Map?) ?? const {}).cast<String, dynamic>(),
        turnId: j['turn'] as String?,
        callId: j['call'] as String?,
        origin: j['origin'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  BackofficeEvent copyWith({int? seq}) => BackofficeEvent(
    seq: seq ?? this.seq,
    time: time,
    source: source,
    kind: kind,
    summary: summary,
    severity: severity,
    details: details,
    turnId: turnId,
    callId: callId,
    origin: origin,
  );

  @override
  String toString() => '#$seq ${source.name}/$kind [${severity.name}] $summary';
}
