import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show StateNotifier;

import '../../domain/models/backoffice_event.dart';
import 'backoffice_journal.dart';

/// Qui agit en ce moment sur la machine, du point de vue du backoffice.
///
/// Posé par le contrôleur de l'agent autour de l'exécution d'un outil : tout
/// ce qui part vers la carte pendant cette fenêtre lui est attribué. C'est ce
/// qui permet de répondre à « quelle commande l'IA a-t-elle réellement
/// envoyée ? » sans deviner à partir du texte de la discussion.
@immutable
class BackofficeActor {
  const BackofficeActor({
    required this.callId,
    required this.tool,
    this.origin,
    this.turnId,
  });

  final String callId;
  final String tool;
  final String? origin;
  final String? turnId;
}

/// Le bus d'audit : un tampon roulant d'événements, un journal persistant, et
/// la fenêtre d'attribution « qui agit ».
///
/// Règles :
/// - **jamais bloquant** : `emit` est synchrone, l'écriture sur disque part en
///   arrière-plan et ses échecs sont avalés ;
/// - **borné** : au-delà de [capacity] événements, les plus anciens tombent
///   (le journal sur disque, lui, garde tout jusqu'à la rotation) ;
/// - **sans contenu de conversation** au-delà d'un aperçu court : le détail
///   d'une discussion est déjà dans ses propres fichiers.
class BackofficeBus extends StateNotifier<List<BackofficeEvent>> {
  BackofficeBus({
    this.capacity = 4000,
    Future<BackofficeJournal?> Function()? journalFactory,
    DateTime Function()? clock,
  }) : _journalFactory = journalFactory,
       _clock = clock ?? DateTime.now,
       super(const []);

  final int capacity;
  final Future<BackofficeJournal?> Function()? _journalFactory;
  final DateTime Function() _clock;

  final ListQueue<BackofficeEvent> _buffer = ListQueue();
  int _seq = 0;

  BackofficeJournal? _journal;
  Future<BackofficeJournal?>? _journalFuture;
  bool _restoring = false;

  BackofficeActor? _actor;
  Timer? _release;

  /// Dernier numéro attribué.
  int get lastSeq => _seq;

  /// L'acteur courant, s'il y en a un (voir [beginAction]).
  BackofficeActor? get currentActor => _actor;

  Future<BackofficeJournal?> _journalOrNull() {
    final factory = _journalFactory;
    if (factory == null) return Future.value(null);
    return _journalFuture ??= () async {
      try {
        return _journal = await factory();
      } catch (_) {
        return null; // pas de journal ≠ pas de backoffice
      }
    }();
  }

  /// Relit le journal sur disque et le place AVANT les événements de cette
  /// session, pour que l'écran montre aussi ce qui s'est passé hier. Appelé
  /// une fois au démarrage ; sans journal, ne fait rien.
  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    try {
      final journal = await _journalOrNull();
      if (journal == null) return;
      final old = await journal.readAll();
      if (old.isEmpty) return;
      final current = _buffer.toList();
      // Ce qui a été émis dans cette session avant la fin de la relecture est
      // déjà sur le disque : on ne le reprend pas une seconde fois.
      final fresh =
          old.where((o) => !current.any((c) => _same(c, o))).toList();
      final keep = fresh.length > capacity
          ? fresh.sublist(fresh.length - capacity)
          : fresh;
      // Les anciens numéros continuent de croître : on renumérote tout, les
      // anciens d'abord, puis ceux déjà émis dans cette session.
      _buffer.clear();
      var seq = 0;
      for (final e in keep) {
        _buffer.add(e.copyWith(seq: ++seq));
      }
      for (final e in current) {
        _buffer.add(e.copyWith(seq: ++seq));
      }
      _seq = seq;
      _trim();
      _publish();
    } finally {
      _restoring = false;
    }
  }

  static bool _same(BackofficeEvent a, BackofficeEvent b) =>
      a.kind == b.kind &&
      a.source == b.source &&
      a.summary == b.summary &&
      a.time.millisecondsSinceEpoch == b.time.millisecondsSinceEpoch;

  /// Dépose un événement. Retourne celui qui a été enregistré (avec son
  /// numéro), pour que l'appelant puisse le relier à la suite.
  BackofficeEvent emit({
    required BackofficeSource source,
    required String kind,
    required String summary,
    BackofficeSeverity severity = BackofficeSeverity.info,
    Map<String, dynamic> details = const {},
    String? turnId,
    String? callId,
    String? origin,
  }) {
    final e = BackofficeEvent(
      seq: ++_seq,
      time: _clock(),
      source: source,
      kind: kind,
      summary: summary,
      severity: severity,
      details: details,
      turnId: turnId,
      callId: callId,
      origin: origin,
    );
    _buffer.add(e);
    _trim();
    _publish();
    unawaited(_persist(e));
    return e;
  }

  Future<void> _persist(BackofficeEvent e) async {
    final journal = _journal ?? await _journalOrNull();
    await journal?.record(e);
  }

  void _trim() {
    while (_buffer.length > capacity) {
      _buffer.removeFirst();
    }
  }

  void _publish() {
    if (!mounted) return;
    state = List.unmodifiable(_buffer);
  }

  // ── Fenêtre d'attribution ─────────────────────────────────────────────────

  /// Ouvre la fenêtre : tout ce qui part vers la carte est désormais attribué
  /// à [actor].
  void beginAction(BackofficeActor actor) {
    _release?.cancel();
    _release = null;
    _actor = actor;
  }

  /// Ferme la fenêtre — à la fin de la boucle d'événements courante, pas tout
  /// de suite : le flux de trafic est asynchrone, et une commande envoyée en
  /// toute fin d'outil n'arrive à la sonde qu'après que l'outil a rendu la
  /// main. Sans ce délai, la dernière commande d'un outil serait attribuée à
  /// personne.
  void endAction() {
    _release?.cancel();
    _release = Timer(Duration.zero, () {
      _actor = null;
      _release = null;
    });
  }

  // ── Entretien ─────────────────────────────────────────────────────────────

  /// Vide le tampon (et, si demandé, les fichiers du journal).
  Future<void> clear({bool wipeDisk = false}) async {
    _buffer.clear();
    _publish();
    if (wipeDisk) {
      final journal = _journal ?? await _journalOrNull();
      await journal?.wipe();
    }
    emit(
      source: BackofficeSource.systeme,
      kind: 'systeme.journal_vide',
      summary: wipeDisk
          ? 'Journal du backoffice vidé (mémoire et disque)'
          : 'Journal du backoffice vidé (mémoire)',
      severity: BackofficeSeverity.notice,
    );
  }

  /// Tout le tampon, du plus ancien au plus récent, prêt à être écrit.
  Map<String, dynamic> exportJson({Map<String, dynamic> extra = const {}}) => {
    'exporte_le': _clock().toIso8601String(),
    'evenements': _buffer.length,
    ...extra,
    'journal': [for (final e in _buffer) e.toJson()],
  };

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }
}
