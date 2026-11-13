import '../../domain/models/backoffice_event.dart';

/// Ce que l'écran du backoffice met en tête : des comptes, calculés à partir
/// du tampon d'événements — jamais estimés, jamais extrapolés.
class BackofficeStats {
  const BackofficeStats({
    this.evenements = 0,
    this.problemes = 0,
    this.toursIa = 0,
    this.toursOk = 0,
    this.toursErreur = 0,
    this.toursVides = 0,
    this.latenceIaP50Ms,
    this.appelsOutils = 0,
    this.outilsEchoues = 0,
    this.confirmationsAttendues = 0,
    this.confirmationsLocal = 0,
    this.confirmationsRelais = 0,
    this.refus = 0,
    this.gardes = 0,
    this.commandesIa = 0,
    this.commandesOperateur = 0,
    this.reponsesOk = 0,
    this.reponsesErreur = 0,
    this.latenceCarteP50Ms,
    this.alarmes = 0,
    this.blocages = 0,
    this.urgences = 0,
    this.urgencesNonTransmises = 0,
    this.relaisLiaisons = 0,
    this.relaisRefus = 0,
    this.relaisMessages = 0,
    this.veilleurAlertes = 0,
    this.veilleurReponsesIa = 0,
    this.dernierTourIa,
    this.toursParModele = const {},
    this.toursImages = 0,
    this.relaisVision = 0,
    this.imagesSansModele = 0,
  });

  /// Tours par modèle (`forgeron-qwen`, `gemma3n:latest`, `gemini-…`).
  final Map<String, int> toursParModele;

  /// Tours confiés au modèle d'images.
  final int toursImages;

  /// Passages de relais « le modèle d'images a décrit, le pilote agit ».
  final int relaisVision;

  /// Images jointes alors qu'aucun modèle d'images n'est branché.
  final int imagesSansModele;

  final int evenements;
  final int problemes;

  final int toursIa;
  final int toursOk;
  final int toursErreur;
  final int toursVides;
  final int? latenceIaP50Ms;

  final int appelsOutils;
  final int outilsEchoues;
  final int confirmationsAttendues;
  final int confirmationsLocal;
  final int confirmationsRelais;
  final int refus;
  final int gardes;

  /// Commandes envoyées à la carte pendant un outil de l'IA.
  final int commandesIa;
  final int commandesOperateur;
  final int reponsesOk;
  final int reponsesErreur;
  final int? latenceCarteP50Ms;

  final int alarmes;
  final int blocages;
  final int urgences;
  final int urgencesNonTransmises;

  final int relaisLiaisons;
  final int relaisRefus;
  final int relaisMessages;

  final int veilleurAlertes;
  final int veilleurReponsesIa;

  final BackofficeEvent? dernierTourIa;

  double get tauxReussiteIa => toursIa == 0 ? 0 : toursOk / toursIa;

  static BackofficeStats of(Iterable<BackofficeEvent> events) {
    var evenements = 0, problemes = 0;
    var toursIa = 0, toursOk = 0, toursErreur = 0, toursVides = 0;
    var appels = 0,
        echoues = 0,
        attendues = 0,
        confLocal = 0,
        confRelais = 0,
        refus = 0,
        gardes = 0;
    var cmdIa = 0, cmdOp = 0, repOk = 0, repErr = 0;
    var alarmes = 0, blocages = 0, urgences = 0, urgencesNT = 0;
    var liaisons = 0, relRefus = 0, relMsg = 0;
    var vAlertes = 0, vIa = 0;
    BackofficeEvent? dernierTour;
    final latIa = <int>[];
    final latCarte = <int>[];
    final parModele = <String, int>{};
    var toursImages = 0, relaisVision = 0, imagesSansModele = 0;

    for (final e in events) {
      evenements++;
      if (e.isProblem) problemes++;
      switch (e.kind) {
        case 'ia.tour':
          toursIa++;
          dernierTour = e;
          final modele = e.details['modele'];
          if (modele is String && modele.isNotEmpty) {
            parModele[modele] = (parModele[modele] ?? 0) + 1;
          }
          if (e.details['role'] == 'images') toursImages++;
          final outcome = e.details['issue'];
          if (outcome == 'ok') {
            toursOk++;
            final l = e.details['latence_ms'];
            if (l is num) latIa.add(l.toInt());
          } else if (outcome == 'error') {
            toursErreur++;
          } else if (outcome == 'empty') {
            toursVides++;
          }
        case 'ia.vision.relais':
          relaisVision++;
        case 'ia.vision.absente':
          imagesSansModele++;
        case 'ia.outil.execute':
          appels++;
          if (e.details['echec'] == true) echoues++;
        case 'ia.outil.attente':
          attendues++;
        case 'ia.outil.confirme':
          if (e.origin == BackofficeOrigin.relais) {
            confRelais++;
          } else {
            confLocal++;
          }
        case 'ia.outil.refuse':
          refus++;
        case 'firmware.tx':
          if (e.callId != null) {
            cmdIa++;
          } else {
            cmdOp++;
          }
        case 'firmware.reponse':
          if (e.details['reponse'] == 'ok') {
            repOk++;
          } else {
            repErr++;
          }
          final l = e.details['latence_ms'];
          if (l is num && e.callId != null) latCarte.add(l.toInt());
        case 'firmware.alarme':
        case 'machine.alarme':
          alarmes++;
        case 'firmware.blocage':
          blocages++;
        case 'ia.urgence':
        case 'machine.urgence':
          urgences++;
        case 'firmware.urgence_non_transmise':
          urgencesNT++;
        case 'relais.liaison':
          liaisons++;
        case 'relais.refus':
          relRefus++;
        case 'relais.message':
          relMsg++;
        case 'veilleur.alerte':
          vAlertes++;
        case 'veilleur.ia':
          if (e.details['reponse'] != null) vIa++;
      }
      if (e.source == BackofficeSource.garde) gardes++;
    }

    return BackofficeStats(
      evenements: evenements,
      problemes: problemes,
      toursIa: toursIa,
      toursOk: toursOk,
      toursErreur: toursErreur,
      toursVides: toursVides,
      latenceIaP50Ms: _p50(latIa),
      appelsOutils: appels,
      outilsEchoues: echoues,
      confirmationsAttendues: attendues,
      confirmationsLocal: confLocal,
      confirmationsRelais: confRelais,
      refus: refus,
      gardes: gardes,
      commandesIa: cmdIa,
      commandesOperateur: cmdOp,
      reponsesOk: repOk,
      reponsesErreur: repErr,
      latenceCarteP50Ms: _p50(latCarte),
      alarmes: alarmes,
      blocages: blocages,
      urgences: urgences,
      urgencesNonTransmises: urgencesNT,
      relaisLiaisons: liaisons,
      relaisRefus: relRefus,
      relaisMessages: relMsg,
      veilleurAlertes: vAlertes,
      veilleurReponsesIa: vIa,
      dernierTourIa: dernierTour,
      toursParModele: parModele,
      toursImages: toursImages,
      relaisVision: relaisVision,
      imagesSansModele: imagesSansModele,
    );
  }

  static int? _p50(List<int> values) {
    if (values.isEmpty) return null;
    final s = values.toList()..sort();
    return s[(s.length - 1) ~/ 2];
  }

  Map<String, dynamic> toJson() => {
    'evenements': evenements,
    'problemes': problemes,
    'ia': {
      'tours': toursIa,
      'ok': toursOk,
      'erreurs': toursErreur,
      'vides': toursVides,
      'latence_p50_ms': latenceIaP50Ms,
      'par_modele': toursParModele,
      'tours_images': toursImages,
      'relais_vision': relaisVision,
      'images_sans_modele': imagesSansModele,
      'appels_outils': appelsOutils,
      'outils_echoues': outilsEchoues,
      'confirmations_attendues': confirmationsAttendues,
      'confirmations_local': confirmationsLocal,
      'confirmations_relais': confirmationsRelais,
      'refus': refus,
      'gardes': gardes,
    },
    'firmware': {
      'commandes_ia': commandesIa,
      'commandes_operateur': commandesOperateur,
      'reponses_ok': reponsesOk,
      'reponses_erreur': reponsesErreur,
      'latence_p50_ms': latenceCarteP50Ms,
      'alarmes': alarmes,
      'blocages': blocages,
      'urgences': urgences,
      'urgences_non_transmises': urgencesNonTransmises,
    },
    'relais': {
      'liaisons': relaisLiaisons,
      'refus': relaisRefus,
      'messages': relaisMessages,
    },
    'veilleur': {'alertes': veilleurAlertes, 'reponses_ia': veilleurReponsesIa},
  };
}

/// État d'une chaîne « l'IA demande → l'opérateur tranche → la commande part
/// → la carte répond ».
enum BackofficeChainStatus { attente, refusee, enCours, ok, echec }

/// Tous les événements d'un même appel d'outil, remis dans l'ordre : c'est la
/// vue « que s'est-il passé entre le modèle et la carte ? ».
class BackofficeChain {
  BackofficeChain(this.callId, this.events);

  final String callId;

  /// Du plus ancien au plus récent.
  final List<BackofficeEvent> events;

  BackofficeEvent? _first(String kind) {
    for (final e in events) {
      if (e.kind == kind) return e;
    }
    return null;
  }

  BackofficeEvent? get demande => _first('ia.outil.demande');
  BackofficeEvent? get attente => _first('ia.outil.attente');
  BackofficeEvent? get confirmation => _first('ia.outil.confirme');
  BackofficeEvent? get refus => _first('ia.outil.refuse');
  BackofficeEvent? get execution => _first('ia.outil.execute');

  String get tool =>
      '${(demande ?? attente ?? execution ?? events.first).details['outil'] ?? '?'}';
  Map<String, dynamic> get args {
    final a = (demande ?? attente ?? execution)?.details['arguments'];
    return a is Map ? a.cast<String, dynamic>() : const {};
  }

  String? get origin => (demande ?? attente ?? events.first).origin;
  String? get turnId => events.first.turnId;
  DateTime get start => events.first.time;
  DateTime get end => events.last.time;

  List<BackofficeEvent> get commandes => events
      .where((e) => e.kind == 'firmware.tx' || e.kind == 'firmware.tx_echec')
      .toList();
  List<BackofficeEvent> get reponses =>
      events.where((e) => e.kind == 'firmware.reponse').toList();
  List<BackofficeEvent> get gardes =>
      events.where((e) => e.source == BackofficeSource.garde).toList();

  bool get touchesFirmware =>
      commandes.isNotEmpty ||
      events.any((e) => e.kind == 'firmware.programme.debut');

  BackofficeChainStatus get status {
    if (refus != null) return BackofficeChainStatus.refusee;
    if (gardes.isNotEmpty && execution == null) {
      return BackofficeChainStatus.refusee;
    }
    final ex = execution;
    if (ex == null) {
      return attente != null && confirmation == null
          ? BackofficeChainStatus.attente
          : BackofficeChainStatus.enCours;
    }
    if (ex.details['echec'] == true) return BackofficeChainStatus.echec;
    if (events.any((e) => e.kind == 'firmware.tx_echec') ||
        reponses.any((e) => e.details['reponse'] != 'ok')) {
      return BackofficeChainStatus.echec;
    }
    return BackofficeChainStatus.ok;
  }

  /// Regroupe par `callId`, la chaîne la plus récente d'abord.
  static List<BackofficeChain> build(Iterable<BackofficeEvent> events) {
    final byCall = <String, List<BackofficeEvent>>{};
    for (final e in events) {
      final id = e.callId;
      if (id == null) continue;
      byCall.putIfAbsent(id, () => []).add(e);
    }
    final chains = [
      for (final en in byCall.entries) BackofficeChain(en.key, en.value),
    ];
    // Deux chaînes nées dans la même milliseconde : le numéro d'ordre tranche.
    chains.sort((a, b) {
      final byTime = b.start.compareTo(a.start);
      return byTime != 0 ? byTime : b.events.first.seq.compareTo(a.events.first.seq);
    });
    return chains;
  }
}
