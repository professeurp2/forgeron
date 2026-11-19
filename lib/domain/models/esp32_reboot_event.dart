import 'machine_state.dart';

/// Motif identifié d'un redémarrage (reboot / reset) de la carte ESP32 FluidNC.
enum Esp32RebootReason {
  /// Chute de tension (brownout) provoquée par l'appel de courant (~17 A)
  /// du moteur de broche DC 775 au démarrage (`M3` sur relais GPIO 21).
  brownoutSpindleSurge,

  /// Chute de tension sur le rail d'alimentation 12V ATX / 5V ESP32
  /// (`rst:0xf BROWNOUT_RESET` ou `Brownout detector was triggered`).
  powerSupplyDrop,

  /// Timeout Watchdog (`TG0WDT` / `TG1WDT` / `RTCWDT`) ou crash firmware
  /// (`Guru Meditation Error` / `Panic`).
  watchdogOrCrash,

  /// Redémarrage ou décrochage après une longue période d'usinage continu
  /// (> 20 min) : suspicion d'échauffement du régulateur ESP32 ou des TB6600.
  thermalOverheat,

  /// Reset logiciel volontaire (`Ctrl-X` / `0x18` / `SW_RESET`).
  manualOrSoftwareReset,

  /// Perte soudaine de l'état machine (retour à `MPos:0,0,0` ou `ALARM:15`
  /// Must Home après une micro-coupure WebSocket alors que la machine était
  /// référencée ou en mouvement).
  unexpectedSessionReset,
}

/// Événement structuré représentant un redémarrage temps réel de la carte ESP32.
class Esp32RebootEvent {
  final DateTime timestamp;
  final Esp32RebootReason reason;
  final String rawSignature;
  final MachineStatus previousStatus;
  final List<double> previousMPos;
  final bool wasSpindleRecentlyStarted;
  final int continuousRunMinutes;
  final int activeGcodeLine;

  const Esp32RebootEvent({
    required this.timestamp,
    required this.reason,
    required this.rawSignature,
    required this.previousStatus,
    required this.previousMPos,
    this.wasSpindleRecentlyStarted = false,
    this.continuousRunMinutes = 0,
    this.activeGcodeLine = 0,
  });

  /// Titre court affiché dans la bannière d'alerte et le Chatbot.
  String get title => switch (reason) {
        Esp32RebootReason.brownoutSpindleSurge =>
          'REDÉMARRAGE ESP32 — CHUTE DE TENSION BROCHE (BROWNOUT M3)',
        Esp32RebootReason.powerSupplyDrop =>
          'REDÉMARRAGE ESP32 — MICRO-COUPURE ALIMENTATION (BROWNOUT)',
        Esp32RebootReason.watchdogOrCrash =>
          'REDÉMARRAGE ESP32 — CRASH FIRMWARE / WATCHDOG',
        Esp32RebootReason.thermalOverheat =>
          'REDÉMARRAGE ESP32 — SUSPICION DE SURCHAUFFE THERMIQUE',
        Esp32RebootReason.manualOrSoftwareReset =>
          'RÉINITIALISATION ESP32 (RESET LOGICIEL)',
        Esp32RebootReason.unexpectedSessionReset =>
          'REDÉMARRAGE ESP32 DÉTECTÉ (PERTE D\'ORIGINE EN SESSION)',
      };

  /// Explication factuelle et matérielle immédiate (< 50 ms, sans attendre l'IA).
  String get factualSummary {
    final posStr = previousMPos.length >= 3
        ? 'X=${previousMPos[0].toStringAsFixed(1)}, '
            'Y=${previousMPos[1].toStringAsFixed(1)}, '
            'Z=${previousMPos[2].toStringAsFixed(1)}'
        : 'inconnue';
    final lineInfo = activeGcodeLine > 0 ? ' (ligne G-code #$activeGcodeLine)' : '';

    return switch (reason) {
      Esp32RebootReason.brownoutSpindleSurge =>
        'La carte ESP32 a redémarré juste après l\'allumage de la broche DC 775 '
            '(GPIO 21)$lineInfo. L\'appel de courant au démarrage (~17 A sur le '
            'relais 10 A) a provoqué un creux de tension sur l\'alimentation 5V/3.3V '
            'de l\'ESP32. Dernière position connue : $posStr.',
      Esp32RebootReason.powerSupplyDrop =>
        'Le détecteur de chute de tension (Brownout) de l\'ESP32 s\'est déclenché '
            '($rawSignature)$lineInfo. Vérifiez le rail 12V de l\'alimentation ATX '
            '(Delta DPS-475CB-1 A), le fusible série et le câble USB/5V de l\'ESP32. '
            'Dernière position connue : $posStr.',
      Esp32RebootReason.watchdogOrCrash =>
        'Le firmware FluidNC sur l\'ESP32 a redémarré suite à une erreur interne '
            'ou un Watchdog ($rawSignature)$lineInfo. Dernière position connue : $posStr.',
      Esp32RebootReason.thermalOverheat =>
        'La carte ESP32 a redémarré après $continuousRunMinutes min d\'usinage '
            'continu$lineInfo. Une surchauffe du régulateur 3.3V de l\'ESP32 ou '
            'des drivers TB6600 (GPIO 22 ENA) est probable. Dernière position : $posStr.',
      Esp32RebootReason.manualOrSoftwareReset =>
        'La carte ESP32 a effectué un reset logiciel ($rawSignature). '
            'Vérifiez la référence machine avant de reprendre un mouvement.',
      Esp32RebootReason.unexpectedSessionReset =>
        'La carte ESP32 a redémarré pendant la session ($rawSignature)$lineInfo : '
            'l\'origine machine a été perdue après la position $posStr.',
    };
  }

  /// Action immédiate recommandée à l'opérateur.
  String get recommendedAction => switch (reason) {
        Esp32RebootReason.brownoutSpindleSurge =>
          '1) Coupez la broche (M5). 2) Relancez le Homing (\$H) car la position '
              'machine est perdue. 3) Séparez l\'alimentation 5V de l\'ESP32 du rail '
              '12V moteur ou installez le MOSFET IRLB8721 + diode de roue libre sur GPIO 21.',
        Esp32RebootReason.powerSupplyDrop =>
          '1) Vérifiez les connecteurs Molex/SATA 12V et le fil PS_ON (vert→GND) '
              'de l\'alim ATX. 2) Relancez le Homing (\$H) avant tout déplacement.',
        Esp32RebootReason.watchdogOrCrash =>
          '1) Déverrouillez (\$X) puis relancez impérativement le Homing (\$H). '
              '2) Réduisez la fréquence de statut ou la vitesse maximale si le '
              'processeur sature en 5 axes simultanés.',
        Esp32RebootReason.thermalOverheat =>
          '1) Laissez refroidir le coffret électronique (TB6600 & ESP32) pendant '
              '5 minutes. 2) Relancez le Homing (\$H) avant de reprendre à la ligne #$activeGcodeLine.',
        Esp32RebootReason.manualOrSoftwareReset =>
          'Relancez un cycle de Homing (\$H) si les moteurs ont décéléré brutalement.',
        Esp32RebootReason.unexpectedSessionReset =>
          'La position machine (MPos) ayant été réinitialisée par le reboot de '
              'l\'ESP32, lancez obligatoirement un Homing (\$H) avant de reprendre.',
      };
}

/// Détecteur temps réel des bannières de boot, codes de reset ESP-IDF et
/// pertes d'état consécutives à un redémarrage de la carte ESP32.
class Esp32RebootDetector {
  Esp32RebootDetector._();

  static final RegExp _brownoutRegex = RegExp(
    r'(Brownout detector was triggered|rst:0xf\s*\(?BROWNOUT_RESET\)?|BROWNOUT_RESET)',
    caseSensitive: false,
  );

  static final RegExp _watchdogOrPanicRegex = RegExp(
    r'(Guru Meditation Error|Core\s+\d+\s+panic|rst:0x[789]\s*\(?.*WDT.*\)?|TG[01]WDT_SYS_RESET|RTCWDT_SYS_RESET|Interrupt wdt timeout|Task watchdog got triggered)',
    caseSensitive: false,
  );

  static final RegExp _powerOnOrBootBannerRegex = RegExp(
    r'(^Grbl\s+\d+\.\d+\s*\[FluidNC|\[MSG:INFO:\s*FluidNC\s+v\d|rst:0x1\s*\(?POWERON_RESET\)?|\[MSG:INFO:\s*Booting)',
    caseSensitive: false,
  );

  static final RegExp _softResetBannerRegex = RegExp(
    r'(rst:0x[3c]\s*\(?SW_.*RESET\)?|\[MSG:Reset to continue\])',
    caseSensitive: false,
  );

  /// Analyse une ligne brute reçue sur le WebSocket FluidNC.
  /// Retourne un [Esp32RebootEvent] si la ligne prouve que l'ESP32 vient de
  /// redémarrer en cours de session.
  static Esp32RebootEvent? inspectRawLine(
    String rawLine, {
    required MachineState currentState,
    required bool sessionAlreadyInitialized,
    DateTime? lastSpindleStartAt,
    Duration? continuousRunDuration,
    DateTime? now,
  }) {
    final line = rawLine.trim();
    if (line.isEmpty) return null;
    final clock = now ?? DateTime.now();

    final spindleJustStarted = lastSpindleStartAt != null &&
        clock.difference(lastSpindleStartAt).inSeconds.abs() <= 5;
    final runMinutes = continuousRunDuration?.inMinutes ?? 0;

    // 1. Détection explicite d'un Brownout matériel ESP32
    if (_brownoutRegex.hasMatch(line)) {
      return Esp32RebootEvent(
        timestamp: clock,
        reason: spindleJustStarted
            ? Esp32RebootReason.brownoutSpindleSurge
            : Esp32RebootReason.powerSupplyDrop,
        rawSignature: line,
        previousStatus: currentState.status,
        previousMPos: List<double>.from(currentState.mPos),
        wasSpindleRecentlyStarted: spindleJustStarted,
        continuousRunMinutes: runMinutes,
        activeGcodeLine: currentState.activeLineIndex,
      );
    }

    // 2. Détection d'un crash firmware / Watchdog ESP-IDF
    if (_watchdogOrPanicRegex.hasMatch(line)) {
      return Esp32RebootEvent(
        timestamp: clock,
        reason: runMinutes >= 20
            ? Esp32RebootReason.thermalOverheat
            : Esp32RebootReason.watchdogOrCrash,
        rawSignature: line,
        previousStatus: currentState.status,
        previousMPos: List<double>.from(currentState.mPos),
        wasSpindleRecentlyStarted: spindleJustStarted,
        continuousRunMinutes: runMinutes,
        activeGcodeLine: currentState.activeLineIndex,
      );
    }

    // 3. Bannière de démarrage FluidNC / Power-On Reset reçue alors que la
    //    session était déjà active (donc l'ESP32 a redémarré).
    if (sessionAlreadyInitialized && _powerOnOrBootBannerRegex.hasMatch(line)) {
      final reason = spindleJustStarted
          ? Esp32RebootReason.brownoutSpindleSurge
          : (runMinutes >= 20
              ? Esp32RebootReason.thermalOverheat
              : Esp32RebootReason.powerSupplyDrop);
      return Esp32RebootEvent(
        timestamp: clock,
        reason: reason,
        rawSignature: line,
        previousStatus: currentState.status,
        previousMPos: List<double>.from(currentState.mPos),
        wasSpindleRecentlyStarted: spindleJustStarted,
        continuousRunMinutes: runMinutes,
        activeGcodeLine: currentState.activeLineIndex,
      );
    }

    // 4. Reset logiciel en plein usinage (Run)
    if (sessionAlreadyInitialized &&
        currentState.status == MachineStatus.run &&
        _softResetBannerRegex.hasMatch(line)) {
      return Esp32RebootEvent(
        timestamp: clock,
        reason: Esp32RebootReason.manualOrSoftwareReset,
        rawSignature: line,
        previousStatus: currentState.status,
        previousMPos: List<double>.from(currentState.mPos),
        wasSpindleRecentlyStarted: spindleJustStarted,
        continuousRunMinutes: runMinutes,
        activeGcodeLine: currentState.activeLineIndex,
      );
    }

    return null;
  }

  /// Heuristique sur transition d'état : si la machine était déplacée
  /// (`MPos != 0`) ou en cours d'usinage (`Run`), et qu'après une brève
  /// déconnexion WebSocket elle réapparaît avec `ALARM:15` (Must Home) ou
  /// `MPos == (0,0,0)` en `Alarm`, c'est que l'ESP32 a rebooté pendant la
  /// micro-coupure.
  static Esp32RebootEvent? inspectStateTransition(
    MachineState? previousNonOffline,
    MachineState next, {
    required bool wasOfflineBetween,
    DateTime? lastSpindleStartAt,
    Duration? continuousRunDuration,
    DateTime? now,
  }) {
    if (previousNonOffline == null || !wasOfflineBetween) return null;
    if (next.status == MachineStatus.offline) return null;

    final wasDisplaced =
        previousNonOffline.mPos.any((coord) => coord.abs() > 0.5);
    final nowAllZero = next.mPos.every((coord) => coord.abs() < 0.001);
    final enteredMustHomeAlarm =
        next.status == MachineStatus.alarm && next.alarmCode == 15;

    if ((wasDisplaced && nowAllZero && next.status == MachineStatus.alarm) ||
        (previousNonOffline.status == MachineStatus.run &&
            enteredMustHomeAlarm)) {
      final clock = now ?? DateTime.now();
      final spindleJustStarted = lastSpindleStartAt != null &&
          clock.difference(lastSpindleStartAt).inSeconds.abs() <= 8;
      final runMinutes = continuousRunDuration?.inMinutes ?? 0;

      return Esp32RebootEvent(
        timestamp: clock,
        reason: spindleJustStarted
            ? Esp32RebootReason.brownoutSpindleSurge
            : Esp32RebootReason.unexpectedSessionReset,
        rawSignature: enteredMustHomeAlarm
            ? 'Reconnexion sur ALARM:15 (Must Home) après coupure'
            : 'Réinitialisation MPos (0,0,0) après coupure',
        previousStatus: previousNonOffline.status,
        previousMPos: List<double>.from(previousNonOffline.mPos),
        wasSpindleRecentlyStarted: spindleJustStarted,
        continuousRunMinutes: runMinutes,
        activeGcodeLine: previousNonOffline.activeLineIndex,
      );
    }
    return null;
  }
}

