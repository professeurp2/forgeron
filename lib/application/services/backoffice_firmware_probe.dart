import 'dart:collection';

import '../../core/utils/grbl_alarm_catalog.dart';
import '../../domain/models/backoffice_event.dart';
import '../../domain/models/machine_state.dart';
import 'backoffice_bus.dart';

/// Une commande partie vers la carte et pas encore acquittée.
class _PendingTx {
  _PendingTx(this.command, this.time, this.actor, this.txSeq);
  final String command;
  final DateTime time;
  final BackofficeActor? actor;
  final int txSeq;
}

/// Sonde du trafic FluidNC : lit ce qui part et ce qui revient, et en fait
/// des événements du backoffice reliés à leur auteur.
///
/// Ce qu'elle observe (le flux `trafficStream` du dépôt machine est déjà là
/// pour le diagnostic ; elle ne touche à rien) :
/// - une commande envoyée (`TX:`) hors usinage → `firmware.tx`, attribuée à
///   l'acteur courant du bus (un outil de l'IA) ou à l'opérateur ;
/// - la réponse de la carte (`ok` / `error:N`) → `firmware.reponse`, reliée à
///   la commande en attente la plus ancienne (FluidNC acquitte dans l'ordre),
///   avec la latence ;
/// - `ALARM:N`, `[MSG:…]`, la bannière de redémarrage ;
/// - un envoi échoué (liaison coupée) → `firmware.tx_echec`, critique ;
/// - pendant un usinage, les lignes ne sont PAS journalisées une à une (des
///   milliers) : un événement au départ, un à la fin avec les comptes, et
///   seules les erreurs entre les deux.
///
/// Pure : aucun Riverpod ici. Le branchement est dans
/// `backoffice_provider.dart`, les tests l'appellent directement.
class BackofficeFirmwareProbe {
  BackofficeFirmwareProbe(
    this.bus, {
    required this.interpret,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackofficeBus bus;

  /// Traduit une commande en action lisible (`$J=…` → « Jog manuel : … »),
  /// ou `null` pour une commande sans intérêt (heartbeat, requêtes d'état).
  final String? Function(String command) interpret;
  final DateTime Function() _clock;

  final ListQueue<_PendingTx> _awaitingAck = ListQueue();
  static const _maxAwaiting = 64;

  bool _streaming = false;
  BackofficeActor? _streamActor;
  int _streamLines = 0;
  int _streamOk = 0;
  int _streamErrors = 0;
  MachineStatus? _lastStatus;
  int? _lastAlarm;
  bool _lastEstop = false;

  bool get isStreaming => _streaming;

  // ── Trafic ────────────────────────────────────────────────────────────────

  void onTraffic(String raw) {
    if (raw.startsWith('TX ÉCHEC')) {
      final cmd = _clean(raw.substring(raw.indexOf(':') + 1));
      final actor = bus.currentActor;
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.tx_echec',
        summary: 'Commande NON transmise (liaison coupée) : ${_show(cmd)}',
        severity: BackofficeSeverity.critical,
        details: {'commande': _show(cmd), 'outil': ?actor?.tool},
        callId: actor?.callId,
        turnId: actor?.turnId,
        origin: actor?.origin ?? BackofficeOrigin.operateur,
      );
      return;
    }
    if (raw.startsWith('TX:')) {
      _onTx(raw.substring(3));
    } else if (raw.startsWith('RX:')) {
      _onRx(raw.substring(3).trim());
    }
  }

  void _onTx(String data) {
    final cmd = _clean(data);
    if (cmd.isEmpty || cmd == '?') return;
    final isLine = data.endsWith('\n') || data.endsWith('\r\n');
    final actor = bus.currentActor;

    if (_streaming) {
      _streamLines++;
      if (isLine) _enqueue(cmd, actor);
      return;
    }

    final label = interpret(cmd);
    // Les requêtes d'état envoyées par l'application elle-même (`$G`, `$#`…)
    // ne disent rien de l'opérateur ; on les garde seulement quand c'est un
    // outil de l'IA qui les a demandées.
    if (label == null && actor == null) return;

    final e = bus.emit(
      source: BackofficeSource.firmware,
      kind: 'firmware.tx',
      summary: label ?? 'Requête : ${_show(cmd)}',
      severity: _severityOfTx(cmd),
      details: {'commande': _show(cmd), 'outil': ?actor?.tool},
      callId: actor?.callId,
      turnId: actor?.turnId,
      origin: actor?.origin ?? BackofficeOrigin.operateur,
    );
    if (isLine) _enqueue(cmd, actor, txSeq: e.seq);
  }

  void _enqueue(String cmd, BackofficeActor? actor, {int txSeq = 0}) {
    _awaitingAck.add(_PendingTx(cmd, _clock(), actor, txSeq));
    while (_awaitingAck.length > _maxAwaiting) {
      _awaitingAck.removeFirst();
    }
  }

  void _onRx(String msg) {
    if (msg.isEmpty || msg.startsWith('<')) return; // rapport d'état

    if (msg == 'ok' || msg.startsWith('error:')) {
      final pending = _awaitingAck.isEmpty ? null : _awaitingAck.removeFirst();
      final ok = msg == 'ok';
      if (_streaming) {
        if (ok) {
          _streamOk++;
          return;
        }
        _streamErrors++;
      }
      // Un « ok » ne vaut d'être montré que s'il ferme une commande de l'IA :
      // les acquittements des gestes manuels inonderaient le journal.
      if (ok && pending?.actor == null) return;
      final latency = pending == null
          ? null
          : _clock().difference(pending.time).inMilliseconds;
      final code = ok ? null : int.tryParse(msg.substring(6).trim());
      final command = pending == null ? null : _show(pending.command);
      final txSeq = pending == null || pending.txSeq == 0
          ? null
          : pending.txSeq;
      final what = command == null ? '' : ' ← $command';
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.reponse',
        summary: ok
            ? 'ok$what${latency == null ? '' : ' ($latency ms)'}'
            : 'Carte : $msg${code == null ? '' : ' — ${grblErrorText(code)}'}$what',
        severity: ok ? BackofficeSeverity.info : BackofficeSeverity.warning,
        details: {
          'reponse': msg,
          'commande': ?command,
          'latence_ms': ?latency,
          'outil': ?pending?.actor?.tool,
          'tx_seq': ?txSeq,
        },
        callId: pending?.actor?.callId,
        turnId: pending?.actor?.turnId,
        origin: pending?.actor?.origin ?? BackofficeOrigin.operateur,
      );
      return;
    }

    if (msg.startsWith('ALARM:')) {
      final code = int.tryParse(msg.substring(6).trim());
      final info = GrblAlarmCatalog.lookup(code);
      _awaitingAck.clear(); // la carte a tout jeté
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.alarme',
        summary: info == null
            ? 'Carte : $msg'
            : 'ALARME ${info.code} — ${info.title}',
        severity: BackofficeSeverity.critical,
        details: {
          'code': ?code,
          'cause': ?info?.cause,
          'action': ?info?.action,
          'position_perdue': ?info?.positionLost,
        },
        origin: _streamActor?.origin,
        callId: _streamActor?.callId,
        turnId: _streamActor?.turnId,
      );
      return;
    }

    if (msg.startsWith('[MSG:')) {
      final body = msg.substring(5, msg.length - (msg.endsWith(']') ? 1 : 0));
      final isErr = body.startsWith('ERR') || body.contains('Error');
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.message',
        summary: 'Carte : $body',
        severity: isErr ? BackofficeSeverity.warning : BackofficeSeverity.info,
      );
      return;
    }

    if (msg.startsWith('Grbl') || msg.startsWith('FluidNC')) {
      _awaitingAck.clear();
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.redemarrage',
        summary: 'Carte redémarrée : $msg',
        severity: BackofficeSeverity.notice,
      );
    }
  }

  // ── Usinage (streaming) ───────────────────────────────────────────────────

  void onStreaming(bool streaming) {
    if (streaming == _streaming) return;
    _streaming = streaming;
    if (streaming) {
      _streamActor = bus.currentActor;
      _streamLines = 0;
      _streamOk = 0;
      _streamErrors = 0;
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.programme.debut',
        summary: _streamActor == null
            ? 'Programme lancé par l\'opérateur'
            : 'Programme lancé par l\'IA (${_streamActor!.tool})',
        severity: BackofficeSeverity.notice,
        details: {'outil': ?_streamActor?.tool},
        callId: _streamActor?.callId,
        turnId: _streamActor?.turnId,
        origin: _streamActor?.origin ?? BackofficeOrigin.operateur,
      );
    } else {
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'firmware.programme.fin',
        summary:
            'Programme terminé ou arrêté : $_streamLines ligne(s) envoyée(s), '
            '$_streamOk ok, $_streamErrors erreur(s)',
        severity: _streamErrors > 0
            ? BackofficeSeverity.warning
            : BackofficeSeverity.notice,
        details: {
          'lignes': _streamLines,
          'ok': _streamOk,
          'erreurs': _streamErrors,
          'outil': ?_streamActor?.tool,
        },
        callId: _streamActor?.callId,
        turnId: _streamActor?.turnId,
        origin: _streamActor?.origin ?? BackofficeOrigin.operateur,
      );
      _streamActor = null;
      _awaitingAck.clear();
    }
  }

  /// Le flux s'est bloqué (watchdog) : la carte n'acquitte plus.
  void onStall(String? reason) {
    if (reason == null) return;
    bus.emit(
      source: BackofficeSource.firmware,
      kind: 'firmware.blocage',
      summary: 'Flux bloqué : $reason',
      severity: BackofficeSeverity.critical,
      details: {'raison': reason},
      callId: _streamActor?.callId,
      turnId: _streamActor?.turnId,
      origin: _streamActor?.origin,
    );
  }

  /// L'arrêt d'urgence n'a PAS pu être transmis.
  void onEstopFailed(bool failed) {
    if (!failed) return;
    bus.emit(
      source: BackofficeSource.firmware,
      kind: 'firmware.urgence_non_transmise',
      summary: 'ARRÊT D\'URGENCE NON TRANSMIS — la machine n\'est pas arrêtée',
      severity: BackofficeSeverity.critical,
    );
  }

  // ── État machine ──────────────────────────────────────────────────────────

  void onState(MachineState s) {
    if (s.status != _lastStatus) {
      final from = _lastStatus;
      _lastStatus = s.status;
      if (s.status == MachineStatus.offline) {
        _awaitingAck.clear();
      }
      final isAlarm = s.status == MachineStatus.alarm;
      final line = s.status == MachineStatus.run ? s.activeLineIndex : null;
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'machine.statut',
        summary:
            'Statut : ${from?.name ?? '—'} → ${s.status.name}'
            '${isAlarm && s.alarmCode != null ? ' (alarme ${s.alarmCode})' : ''}',
        severity: isAlarm
            ? BackofficeSeverity.critical
            : (s.status == MachineStatus.offline
                  ? BackofficeSeverity.notice
                  : BackofficeSeverity.info),
        details: {
          'avant': from?.name,
          'apres': s.status.name,
          'alarme': ?s.alarmCode,
          'ligne': ?line,
        },
      );
    } else if (s.status == MachineStatus.alarm &&
        s.alarmCode != _lastAlarm &&
        s.alarmCode != null) {
      final info = GrblAlarmCatalog.lookup(s.alarmCode);
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'machine.alarme',
        summary: info == null
            ? 'Alarme ${s.alarmCode}'
            : 'ALARME ${info.code} — ${info.title}',
        severity: BackofficeSeverity.critical,
        details: {'code': s.alarmCode!, 'cause': ?info?.cause},
      );
    }
    _lastAlarm = s.status == MachineStatus.alarm ? s.alarmCode : null;

    if (s.emergencyTriggered && !_lastEstop) {
      bus.emit(
        source: BackofficeSource.firmware,
        kind: 'machine.urgence',
        summary: 'Arrêt d\'urgence matériel déclenché (E-STOP)',
        severity: BackofficeSeverity.critical,
      );
    }
    if (s.status != MachineStatus.offline) _lastEstop = s.emergencyTriggered;
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────

  static String _clean(String s) =>
      s.replaceAll('\r', '').replaceAll('\n', '').trim();

  BackofficeSeverity _severityOfTx(String cmd) {
    if (cmd == '\x18') {
      return BackofficeSeverity.warning; // soft reset / urgence
    }
    if (cmd == '!') return BackofficeSeverity.notice;
    final u = cmd.toUpperCase();
    if (u.startsWith('\$H') || u.startsWith('M3') || u.startsWith('M4')) {
      return BackofficeSeverity.notice;
    }
    return BackofficeSeverity.info;
  }

  /// Rend lisibles les caractères de contrôle de GRBL.
  static String _show(String cmd) {
    if (cmd.isEmpty) return cmd;
    final c = cmd.codeUnitAt(0);
    if (cmd.length == 1) {
      switch (c) {
        case 0x18:
          return 'Ctrl-X (soft reset)';
        case 0x85:
          return 'Jog cancel';
        case 0x90:
          return 'Avance 100 %';
        case 0x91:
          return 'Avance +10 %';
        case 0x92:
          return 'Avance −10 %';
        case 0x99:
          return 'Broche 100 %';
        case 0x9A:
          return 'Broche +10 %';
        case 0x9B:
          return 'Broche −10 %';
      }
    }
    return cmd.length > 120 ? '${cmd.substring(0, 117)}…' : cmd;
  }
}

/// Libellé court des codes `error:N` de GRBL/FluidNC les plus fréquents.
String grblErrorText(int code) =>
    const <int, String>{
      1: 'lettre G-code attendue',
      2: 'valeur numérique illisible',
      3: 'commande \$ inconnue',
      4: 'valeur négative interdite',
      5: 'homing désactivé dans la config',
      7: 'lecture EEPROM impossible',
      8: 'commande refusée : machine pas en Idle',
      9: 'commandes bloquées : alarme ou jog en cours',
      10: 'soft limits sans homing',
      11: 'ligne trop longue',
      13: 'porte de sécurité ouverte',
      15: 'jog hors des courses',
      16: 'commande de jog invalide',
      17: 'laser requiert PWM',
      20: 'commande non supportée',
      21: 'groupe modal en double',
      22: 'avance F non définie',
      23: 'commande G-code invalide',
      24: 'deux commandes du même groupe sur la ligne',
      25: 'mot G-code répété',
      26: 'mot sans valeur',
      27: 'numéro de ligne invalide',
      28: 'valeur manquante',
      29: 'système de coordonnées non supporté',
      30: 'G53 avec un autre groupe de mouvement',
      31: 'mots d\'axe inattendus',
      32: 'G2/G3 sans mot d\'axe',
      33: 'cible de mouvement invalide',
      34: 'arc impossible à calculer',
      35: 'G2/G3 sans offset',
      36: 'mots inutilisés sur la ligne',
      37: 'G43.1 : axe de l\'outil incorrect',
      38: 'numéro d\'outil hors plage',
    }[code] ??
    'erreur $code';
