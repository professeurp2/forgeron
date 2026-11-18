import 'package:flutter/foundation.dart';

/// Genre d'appareil d'un participant.
abstract final class CoworkKind {
  /// Le PC qui héberge la session (l'agent et la machine sont chez lui).
  static const host = 'hote';
  static const tablet = 'tablette';
  static const phone = 'telephone';
  static const desktop = 'pc';
}

/// Un participant de la session de coworking : qui est là, sur quoi.
@immutable
class CoworkParticipant {
  const CoworkParticipant({
    required this.id,
    required this.name,
    required this.kind,
    this.since,
  });

  final String id;
  final String name;
  final String kind;
  final DateTime? since;

  bool get isHost => kind == CoworkKind.host;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        if (since != null) 'since': since!.toUtc().toIso8601String(),
      };

  static CoworkParticipant? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final name = '${raw['name'] ?? ''}'.trim();
    return CoworkParticipant(
      id: id,
      // Un nom reçu du réseau est une donnée : borné, jamais vide.
      name: name.isEmpty ? 'Appareil' : (name.length > 40 ? name.substring(0, 40) : name),
      kind: '${raw['kind'] ?? CoworkKind.phone}',
      since: DateTime.tryParse('${raw['since'] ?? ''}')?.toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoworkParticipant && other.id == id && other.name == name && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, name, kind);
}

/// Ce que l'hôte partage de son poste, en plus de la discussion : l'état de
/// la machine, l'avancement du programme et le simulateur.
///
/// C'est ce qui fait du relais une session de TRAVAIL et non un simple chat :
/// la tablette voit les cotes bouger sans avoir sa propre liaison à la carte
/// (FluidNC n'accepte que peu de clients à la fois). Tout ce qui est ici
/// vient de l'état du PC au moment de l'envoi ; rien n'est recalculé chez
/// l'invité.
@immutable
class CoworkWorkspace {
  const CoworkWorkspace({
    this.status = 'offline',
    this.wPos = const [0, 0, 0, 0, 0],
    this.mPos = const [0, 0, 0, 0, 0],
    this.feed = 0,
    this.spindle = 0,
    this.alarm,
    this.line = 0,
    this.totalLines = 0,
    this.streaming = false,
    this.simStatus = 'idle',
    this.simProgress = 0,
    this.simSpeed = 1,
    this.simDeviation,
    this.at,
  });

  /// Statut de la carte (`idle`, `run`, `hold`, `alarm`, `offline`…).
  final String status;
  final List<double> wPos;
  final List<double> mPos;
  final double feed;
  final double spindle;
  final int? alarm;

  /// Ligne acquittée par la carte, et taille du programme chargé.
  final int line;
  final int totalLines;
  final bool streaming;

  /// Simulateur du PC : `idle`, `playing`, `paused`, `completed`, `live`.
  final String simStatus;
  final double simProgress;
  final double simSpeed;
  final double? simDeviation;

  /// Heure de l'instantané chez l'hôte.
  final DateTime? at;

  bool get online => status != 'offline';
  bool get hasProgram => totalLines > 0;
  double get programFraction =>
      totalLines <= 0 ? 0 : (line / totalLines).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'status': status,
        'w': wPos,
        'm': mPos,
        'f': feed,
        's': spindle,
        if (alarm != null) 'alarm': alarm,
        'line': line,
        'lines': totalLines,
        'streaming': streaming,
        'sim': simStatus,
        'simPct': simProgress,
        'simSpeed': simSpeed,
        if (simDeviation != null) 'simDev': simDeviation,
        'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      };

  static List<double> _axes(Object? raw) {
    final out = <double>[0, 0, 0, 0, 0];
    if (raw is List) {
      for (var i = 0; i < raw.length && i < 5; i++) {
        final v = raw[i];
        if (v is num && v.isFinite) out[i] = v.toDouble();
      }
    }
    return out;
  }

  static double _num(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;

  static CoworkWorkspace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return CoworkWorkspace(
      status: '${raw['status'] ?? 'offline'}',
      wPos: _axes(raw['w']),
      mPos: _axes(raw['m']),
      feed: _num(raw['f']),
      spindle: _num(raw['s']),
      alarm: (raw['alarm'] as num?)?.toInt(),
      line: _num(raw['line']).toInt(),
      totalLines: _num(raw['lines']).toInt(),
      streaming: raw['streaming'] == true,
      simStatus: '${raw['sim'] ?? 'idle'}',
      simProgress: _num(raw['simPct']).clamp(0, 100).toDouble(),
      simSpeed: _num(raw['simSpeed']),
      simDeviation: raw['simDev'] is num ? (raw['simDev'] as num).toDouble() : null,
      at: DateTime.tryParse('${raw['at'] ?? ''}')?.toLocal(),
    );
  }

  /// Égalité sur le CONTENU (hors horodatage) : sert à ne pas renvoyer un
  /// instantané identique au précédent.
  bool sameContentAs(CoworkWorkspace o) =>
      status == o.status &&
      listEquals(wPos, o.wPos) &&
      listEquals(mPos, o.mPos) &&
      feed == o.feed &&
      spindle == o.spindle &&
      alarm == o.alarm &&
      line == o.line &&
      totalLines == o.totalLines &&
      streaming == o.streaming &&
      simStatus == o.simStatus &&
      simProgress == o.simProgress &&
      simSpeed == o.simSpeed &&
      simDeviation == o.simDeviation;
}
