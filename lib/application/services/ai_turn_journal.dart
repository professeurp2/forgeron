import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Issue d'un tour de l'agent.
enum AiTurnOutcome {
  /// Réponse livrée (texte et/ou appels d'outils).
  ok,

  /// Le modèle n'a rien dit : ni texte, ni outil.
  empty,

  /// Échec réseau ou serveur.
  error,

  /// Interrompu par l'opérateur.
  cancelled,
}

/// Une ligne du journal : ce qui s'est passé pendant UN tour, **sans le
/// contenu de la conversation**.
///
/// Aucun texte d'opérateur, aucune réponse, aucun argument d'outil : seulement
/// de quoi savoir si l'agent va bien (version, latence, tokens, outils
/// appelés, garde-fous déclenchés). Un journal qu'on peut envoyer à un mentor
/// sans relire chaque ligne est un journal qu'on osera consulter — et
/// partager.
class AiTurnRecord {
  const AiTurnRecord({
    required this.time,
    required this.backend,
    required this.model,
    required this.outcome,
    required this.latencyMs,
    this.tokens = 0,
    this.tools = const [],
    this.notes = const [],
    this.declaredTools = 0,
    this.release,
    this.errorKind,
    this.front,
    this.lexicon,
  });

  final DateTime time;

  /// `local`, `gemini`, ou `lexique` quand le tour a été traité sans modèle par
  /// le lexique fermé.
  final String backend;
  final String model;
  final AiTurnOutcome outcome;
  final int latencyMs;
  final int tokens;

  /// Noms des outils appelés (jamais leurs arguments).
  final List<String> tools;

  /// Garde-fous intervenus (voir `AiApiResponse.notes`).
  final List<String> notes;

  /// Nombre d'outils déclarés au modèle pour ce tour.
  final int declaredTools;

  /// Empreintes du prompt et des outils au moment du tour.
  final String? release;

  /// `unreachable`, `quota`, `other` — jamais le message brut.
  final String? errorKind;

  /// Ce que le lexique fermé a décidé pour ce tour, sans le texte du message :
  /// `lexique:direct:readOnly:etat`, `lexique:confirmer:jog`,
  /// `lexique:execute:jog`, `lexique:abandon:jog`,
  /// `lexique:lecture_seule:question`, `lexique:refus:mots_inconnus`.
  final String? front;

  /// `version/empreinte` du lexique en service (ex. `0.2.0/1a2b3c4d`).
  final String? lexicon;

  Map<String, dynamic> toJson() => {
        'ts': time.toUtc().toIso8601String(),
        'backend': backend,
        'model': model,
        'outcome': outcome.name,
        'latency_ms': latencyMs,
        'tokens': tokens,
        if (tools.isNotEmpty) 'tools': tools,
        if (notes.isNotEmpty) 'notes': notes,
        'declared_tools': declaredTools,
        if (release != null) 'release': release,
        if (errorKind != null) 'error_kind': errorKind,
        if (front != null) 'front': front,
        if (lexicon != null) 'lexicon': lexicon,
      };

  static AiTurnRecord? fromJson(Map<String, dynamic> j) {
    try {
      return AiTurnRecord(
        time: DateTime.parse(j['ts'] as String),
        backend: j['backend'] as String,
        model: j['model'] as String,
        outcome: AiTurnOutcome.values.byName(j['outcome'] as String),
        latencyMs: (j['latency_ms'] as num).toInt(),
        tokens: (j['tokens'] as num?)?.toInt() ?? 0,
        tools: ((j['tools'] as List?) ?? const []).map((e) => '$e').toList(),
        notes: ((j['notes'] as List?) ?? const []).map((e) => '$e').toList(),
        declaredTools: (j['declared_tools'] as num?)?.toInt() ?? 0,
        release: j['release'] as String?,
        errorKind: j['error_kind'] as String?,
        front: j['front'] as String?,
        lexicon: j['lexicon'] as String?,
      );
    } catch (_) {
      return null; // ligne illisible : ignorée, jamais fatale
    }
  }
}

/// Résumé d'un journal : ce qu'on montre dans un écran de diagnostic ou
/// qu'on joint à un rapport.
class AiJournalSummary {
  AiJournalSummary._({
    required this.turns,
    required this.byOutcome,
    required this.latencyP50Ms,
    required this.latencyP95Ms,
    required this.meanTokens,
    required this.guards,
    required this.toolCalls,
  });

  final int turns;
  final Map<AiTurnOutcome, int> byOutcome;
  final int? latencyP50Ms;
  final int? latencyP95Ms;
  final double meanTokens;

  /// Garde-fou → nombre de déclenchements.
  final Map<String, int> guards;

  /// Outil → nombre d'appels.
  final Map<String, int> toolCalls;

  int count(AiTurnOutcome o) => byOutcome[o] ?? 0;

  /// Part des tours livrés (`ok`) parmi ceux qui ne sont pas annulés.
  double get successRate {
    final denom = turns - count(AiTurnOutcome.cancelled);
    return denom <= 0 ? 0 : count(AiTurnOutcome.ok) / denom;
  }

  static AiJournalSummary of(Iterable<AiTurnRecord> records) {
    final list = records.toList();
    final byOutcome = <AiTurnOutcome, int>{};
    final guards = <String, int>{};
    final tools = <String, int>{};
    for (final r in list) {
      byOutcome[r.outcome] = (byOutcome[r.outcome] ?? 0) + 1;
      for (final n in r.notes) {
        guards[n] = (guards[n] ?? 0) + 1;
      }
      for (final t in r.tools) {
        tools[t] = (tools[t] ?? 0) + 1;
      }
    }
    final lat = list.where((r) => r.outcome == AiTurnOutcome.ok).map((r) => r.latencyMs).toList()..sort();
    int? pct(double p) => lat.isEmpty ? null : lat[(p / 100 * lat.length).ceil().clamp(1, lat.length) - 1];
    return AiJournalSummary._(
      turns: list.length,
      byOutcome: byOutcome,
      latencyP50Ms: pct(50),
      latencyP95Ms: pct(95),
      meanTokens: list.isEmpty ? 0 : list.map((r) => r.tokens).reduce((a, b) => a + b) / list.length,
      guards: guards,
      toolCalls: tools,
    );
  }
}

/// Journal des tours de l'agent : un fichier JSON-lignes, avec rotation.
///
/// Écriture tolérante : un journal qui ne peut pas écrire (disque plein,
/// dossier verrouillé) n'a jamais le droit d'empêcher l'agent de répondre.
class AiTurnJournal {
  AiTurnJournal(
    this.directory, {
    this.fileName = 'ai_journal.jsonl',
    this.maxBytes = 1 << 20,
    this.keep = 3,
  });

  final String directory;
  final String fileName;

  /// Taille à partir de laquelle on fait tourner les fichiers.
  final int maxBytes;

  /// Nombre de fichiers conservés (le courant + les anciens).
  final int keep;

  String get _path => '$directory${Platform.pathSeparator}$fileName';
  File get file => File(_path);

  Future<void> record(AiTurnRecord r) async {
    try {
      await _rotateIfNeeded();
      await file.writeAsString('${jsonEncode(r.toJson())}\n',
          mode: FileMode.append, flush: true);
    } catch (_) {/* jamais fatal */}
  }

  Future<void> _rotateIfNeeded() async {
    if (!await file.exists() || await file.length() < maxBytes) return;
    // .2 → supprimé, .1 → .2, courant → .1
    for (var i = keep - 1; i >= 1; i--) {
      final from = File(i == 1 ? _path : '$_path.${i - 1}');
      final to = File('$_path.$i');
      if (await from.exists()) {
        if (await to.exists()) await to.delete();
        await from.rename(to.path);
      }
    }
  }

  /// Tous les tours conservés, du plus ancien au plus récent.
  Future<List<AiTurnRecord>> readAll() async {
    final out = <AiTurnRecord>[];
    for (var i = math.max(keep - 1, 0); i >= 0; i--) {
      final f = File(i == 0 ? _path : '$_path.$i');
      if (!await f.exists()) continue;
      for (final line in await f.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          final r = AiTurnRecord.fromJson(
              (jsonDecode(line) as Map).cast<String, dynamic>());
          if (r != null) out.add(r);
        } catch (_) {/* ligne illisible : ignorée */}
      }
    }
    return out;
  }
}
