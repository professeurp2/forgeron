import '../../core/utils/grbl_alarm_catalog.dart';
import '../../domain/models/esp32_reboot_event.dart';
import '../../domain/models/machine_state.dart';

/// Action de remédiation proposée en 1 clic dans le Chatbot Omniprésent
/// lorsqu'une alarme ou un redémarrage ESP32 est détecté.
class RemediationAction {
  final String id;
  final String label;
  final String? gcodeCommand;
  final String? aiFollowUpPrompt;

  const RemediationAction({
    required this.id,
    required this.label,
    this.gcodeCommand,
    this.aiFollowUpPrompt,
  });
}

/// Diagnostic matériel complet corrélant l'état FluidNC avec le câblage réel
/// du prototype Forgeron 5 axes (ESP32 DevKit V1 + 5× TB6600 + Alim ATX 12V).
class HardwareDiagnosis {
  final DateTime timestamp;
  final String headline;
  final String probableHardwareCause;
  final String gpioPinDetail;
  final String immediateOperatorSteps;
  final List<RemediationAction> quickActions;
  final bool isEsp32Reboot;
  final int? alarmCode;

  const HardwareDiagnosis({
    required this.timestamp,
    required this.headline,
    required this.probableHardwareCause,
    required this.gpioPinDetail,
    required this.immediateOperatorSteps,
    required this.quickActions,
    this.isEsp32Reboot = false,
    this.alarmCode,
  });
}

/// Moteur de corrélation causale matérielle de Forgeron.
class HardwareRootCauseCorrelator {
  HardwareRootCauseCorrelator._();

  /// Mapping matériel exact du prototype Forgeron (`config_5axes_production.yaml`).
  static const Map<String, String> axisLimitGpioMap = {
    'X': 'GPIO 4 (switch NF fail-safe → GND, pull-up gpio.4:high:pu)',
    'Y': 'GPIO 13 (switch NF fail-safe → GND, pull-up gpio.13:high:pu)',
    'Z': 'GPIO 14 (switch NF fail-safe → GND, pull-up gpio.14:high:pu)',
    'A': 'GPIO 5 (switch NF fail-safe → GND, capteur homing à -88°)',
    'C': 'Axe C sans fin de course matériel (référence logicielle G92 C0)',
  };

  static const String estopGpioInfo =
      'GPIO 15 (bouton Arrêt d\'Urgence NF fail-safe → GND, gpio.15:high:pu)';
  static const String spindleGpioInfo =
      'GPIO 21 (relais tout-ou-rien 10 A pilotant le moteur DC 775 12V/200W, appel ~17 A)';
  static const String stepperEnableGpioInfo =
      'GPIO 22 (ENA partagé ×5 drivers TB6600)';

  /// Construit un diagnostic matériel enrichi à partir d'un code d'alarme
  /// GRBL/FluidNC et de l'état instantané des capteurs (`limitSwitches`, `Pn:`).
  static HardwareDiagnosis diagnoseAlarm(
    MachineState state, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final code = state.alarmCode;
    final info = GrblAlarmCatalog.lookup(code);
    const axes = ['X', 'Y', 'Z', 'A', 'C'];

    final activeAxes = <String>[];
    for (var i = 0; i < axes.length && i < state.limitSwitches.length; i++) {
      if (state.limitSwitches[i]) {
        activeAxes.add(axes[i]);
      }
    }

    final activePinsText = activeAxes.isEmpty
        ? (state.emergencyTriggered
            ? 'Broche E-STOP active : $estopGpioInfo'
            : 'Aucun capteur fin de course maintenu actif à cet instant (impulsion brève ou dépassement soft limit).')
        : activeAxes
            .map((a) => 'Axe $a : ${axisLimitGpioMap[a]}')
            .join(' | ');

    final headline = info == null
        ? 'ALARME MACHINE${code != null ? ' $code' : ''}'
        : 'ALARME ${info.code} — ${info.title}';

    String cause = info?.cause ?? 'La machine est passée en sécurité ALARME.';
    if (code == 1 && activeAxes.isNotEmpty) {
      cause += ' Capteur(s) en défaut : ${activeAxes.join(', ')}. '
          'Les fins de course étant câblés en NF (Normalement Fermé fail-safe), '
          'soit le chariot a physiquement appuyé sur la butée, soit un fil du '
          'capteur ${activeAxes.join('/')} est coupé ou débranché.';
    } else if (code == 11 || state.emergencyTriggered) {
      cause = 'Entrée d\'arrêt d\'urgence (E-STOP) ouverte sur GPIO 15. '
          'Bouton coup-de-poing enfoncé ou boucle NF ouverte.';
    }

    final steps = info?.action ??
        'Vérifiez mécaniquement les axes, déverrouillez avec \$X puis refaites une prise d\'origine (\$H).';

    return HardwareDiagnosis(
      timestamp: clock,
      headline: headline,
      probableHardwareCause: cause,
      gpioPinDetail: activePinsText,
      immediateOperatorSteps: steps,
      alarmCode: code,
      quickActions: [
        const RemediationAction(
          id: 'unlock_alarm',
          label: '🔓 Déverrouiller (\$X)',
          gcodeCommand: '\$X',
        ),
        const RemediationAction(
          id: 'rehome_machine',
          label: '🏠 Relancer Homing (\$H)',
          gcodeCommand: '\$H',
        ),
        RemediationAction(
          id: 'ask_ai_troubleshoot',
          label: '🩺 Dépannage guidé GPIO par l\'Agent',
          aiFollowUpPrompt:
              'Explique-moi étape par étape comment dépanner $headline '
              '(${activeAxes.isEmpty ? "aucun pin actif" : "axe(s) ${activeAxes.join(", ")}"}) '
              'sur le câblage ESP32 de Forgeron.',
        ),
      ],
    );
  }

  /// Construit un diagnostic matériel complet lorsqu'un redémarrage de la
  /// carte ESP32 est détecté en temps réel.
  static HardwareDiagnosis diagnoseEsp32Reboot(Esp32RebootEvent event) {
    final gpioDetail = switch (event.reason) {
      Esp32RebootReason.brownoutSpindleSurge =>
        '$spindleGpioInfo + Rail 12V ATX (Delta DPS-475CB-1 A)',
      Esp32RebootReason.powerSupplyDrop =>
        'Alimentation 5V ESP32 DevKit V1 / Rail 12V ATX (PS_ON fil vert → GND)',
      Esp32RebootReason.thermalOverheat =>
        '$stepperEnableGpioInfo + Régulateur LDO 3.3V AMS1117 sur ESP32',
      Esp32RebootReason.watchdogOrCrash =>
        'SoC ESP32 Dual-Core (Tâche temps réel I2S/RMT STEP + pile WiFi WebSocket)',
      Esp32RebootReason.manualOrSoftwareReset =>
        'Commande Reset (0x18 / Ctrl-X) reçue sur la liaison série/WebSocket',
      Esp32RebootReason.unexpectedSessionReset =>
        'Perte de contexte RAM ESP32 (compteurs MPos remis à 0.000)',
    };

    return HardwareDiagnosis(
      timestamp: event.timestamp,
      headline: event.title,
      probableHardwareCause: event.factualSummary,
      gpioPinDetail: gpioDetail,
      immediateOperatorSteps: event.recommendedAction,
      isEsp32Reboot: true,
      quickActions: [
        if (event.wasSpindleRecentlyStarted)
          const RemediationAction(
            id: 'spindle_off',
            label: '🛑 Couper Broche (M5)',
            gcodeCommand: 'M5',
          ),
        const RemediationAction(
          id: 'unlock_after_reboot',
          label: '🔓 Déverrouiller (\$X)',
          gcodeCommand: '\$X',
        ),
        const RemediationAction(
          id: 'home_after_reboot',
          label: '🏠 Refaire l\'Origine (\$H)',
          gcodeCommand: '\$H',
        ),
        RemediationAction(
          id: 'explain_reboot',
          label: '⚡ Analyser ce reboot ESP32',
          aiFollowUpPrompt:
              'La carte ESP32 vient de redémarrer (${event.title}, signature: '
              '« ${event.rawSignature} »). Explique-moi la cause exacte et '
              'comment sécuriser la reprise de mon travail.',
        ),
      ],
    );
  }
}

