import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../domain/models/esp32_reboot_event.dart';
import '../../domain/models/machine_state.dart';
import '../services/hardware_root_cause_correlator.dart';
import 'activity_log_provider.dart';
import 'di_providers.dart';
import 'machine_provider.dart';

/// Type de la dernière opération accomplie sur le contrôleur Forgeron.
/// Pilote la génération automatique de nouvelles suggestions (`NextBestActionEngine`).
enum OperationEventType {
  appStarted,
  machineConnected,
  homingCompleted,
  probingCompleted,
  stepFileLoaded,
  gcodeGeneratedOrLoaded,
  machiningStarted,
  machiningPaused,
  alarmTriggered,
  alarmCleared,
  esp32RebootDetected,
  demoBenchmarkLoaded,
  windowChanged,
}

/// Suggestion dynamique générée après chaque opération pour orienter l'utilisateur.
class SuggestedNextAction {
  final String id;
  final String emoji;
  final String label;
  final String prompt;
  final String? directGcode;
  final String? demoSampleId;

  const SuggestedNextAction({
    required this.id,
    required this.emoji,
    required this.label,
    required this.prompt,
    this.directGcode,
    this.demoSampleId,
  });
}

/// État immuable de la « Mémoire du Contrôleur » (Machine + ESP32 + FAO + Fenêtre active).
class ControllerMemoryState {
  final int activeWindowIndex;
  final String activeWindowName;
  final int esp32RebootCount;
  final Esp32RebootEvent? lastRebootEvent;
  final HardwareDiagnosis? activeDiagnosis;
  final DateTime? lastSpindleStartAt;
  final DateTime? continuousRunStartedAt;
  final String? activeFilePath;
  final String? activeDemoDomain; // 'manufacturing' | 'medicine'
  final OperationEventType lastOperationType;
  final String lastOperationSummary;
  final List<SuggestedNextAction> nextSuggestions;

  const ControllerMemoryState({
    this.activeWindowIndex = 0,
    this.activeWindowName = 'Contrôle & DRO 5-Axes',
    this.esp32RebootCount = 0,
    this.lastRebootEvent,
    this.activeDiagnosis,
    this.lastSpindleStartAt,
    this.continuousRunStartedAt,
    this.activeFilePath,
    this.activeDemoDomain,
    this.lastOperationType = OperationEventType.appStarted,
    this.lastOperationSummary = 'Contrôleur initialisé',
    this.nextSuggestions = const [],
  });

  ControllerMemoryState copyWith({
    int? activeWindowIndex,
    String? activeWindowName,
    int? esp32RebootCount,
    Esp32RebootEvent? lastRebootEvent,
    HardwareDiagnosis? activeDiagnosis,
    bool clearActiveDiagnosis = false,
    DateTime? lastSpindleStartAt,
    DateTime? continuousRunStartedAt,
    bool clearContinuousRun = false,
    String? activeFilePath,
    String? activeDemoDomain,
    OperationEventType? lastOperationType,
    String? lastOperationSummary,
    List<SuggestedNextAction>? nextSuggestions,
  }) {
    return ControllerMemoryState(
      activeWindowIndex: activeWindowIndex ?? this.activeWindowIndex,
      activeWindowName: activeWindowName ?? this.activeWindowName,
      esp32RebootCount: esp32RebootCount ?? this.esp32RebootCount,
      lastRebootEvent: lastRebootEvent ?? this.lastRebootEvent,
      activeDiagnosis:
          clearActiveDiagnosis ? null : (activeDiagnosis ?? this.activeDiagnosis),
      lastSpindleStartAt: lastSpindleStartAt ?? this.lastSpindleStartAt,
      continuousRunStartedAt: clearContinuousRun
          ? null
          : (continuousRunStartedAt ?? this.continuousRunStartedAt),
      activeFilePath: activeFilePath ?? this.activeFilePath,
      activeDemoDomain: activeDemoDomain ?? this.activeDemoDomain,
      lastOperationType: lastOperationType ?? this.lastOperationType,
      lastOperationSummary: lastOperationSummary ?? this.lastOperationSummary,
      nextSuggestions: nextSuggestions ?? this.nextSuggestions,
    );
  }

  /// Bloc injecté dans le prompt système de l'Agent IA pour qu'il soit la
  /// véritable « Mémoire du Contrôleur » depuis n'importe quelle fenêtre.
  String toSystemPromptBlock() {
    final buf = StringBuffer('=== MÉMOIRE DU CONTRÔLEUR FORGERON (TEMPS RÉEL) ===\n');
    buf.writeln('- Fenêtre active de l\'opérateur : $activeWindowName (onglet #$activeWindowIndex)');
    buf.writeln('- Dernière opération enregistrée : $lastOperationSummary (${lastOperationType.name})');
    buf.writeln('- Redémarrages carte ESP32 détectés durant la session : $esp32RebootCount');
    if (lastRebootEvent != null) {
      buf.writeln(
        '  • Dernier reboot ESP32 : ${lastRebootEvent!.title} — ${lastRebootEvent!.factualSummary}',
      );
    }
    if (activeDiagnosis != null) {
      buf.writeln('- DIAGNOSTIC MATÉRIEL ACTIF : ${activeDiagnosis!.headline}');
      buf.writeln('  • Cause matérielle : ${activeDiagnosis!.probableHardwareCause}');
      buf.writeln('  • Brochage GPIO ESP32 : ${activeDiagnosis!.gpioPinDetail}');
      buf.writeln('  • Action requise : ${activeDiagnosis!.immediateOperatorSteps}');
    }
    if (activeFilePath != null && activeFilePath!.isNotEmpty) {
      buf.writeln(
        '- Fichier CAO/STEP ou G-Code actif : $activeFilePath'
        '${activeDemoDomain != null ? ' (filière : $activeDemoDomain)' : ''}',
      );
    }
    buf.write(
      '- Câblage de référence ESP32 : X=GPIO4(NF), Y=GPIO13(NF), Z=GPIO14(NF), '
      'A=GPIO5(NF -88°), E-STOP=GPIO15(NF), Broche 775=GPIO21(Relais M3/M5), '
      'ENA TB6600=GPIO22, Alim=ATX 12V/38A.',
    );
    return buf.toString();
  }
}

/// Moteur déterministe de suggestions contextuelles (« Next Best Actions »)
/// recalculé après chaque opération de l'utilisateur ou événement machine.
class NextBestActionEngine {
  NextBestActionEngine._();

  static List<SuggestedNextAction> compute({
    required OperationEventType lastOp,
    required MachineStatus machineStatus,
    String? activeFilePath,
    String? activeDemoDomain,
    HardwareDiagnosis? activeDiagnosis,
  }) {
    // 1. Priorité absolue : Alarme ou Redémarrage ESP32 actif
    if (machineStatus == MachineStatus.alarm ||
        lastOp == OperationEventType.alarmTriggered ||
        lastOp == OperationEventType.esp32RebootDetected) {
      return [
        SuggestedNextAction(
          id: 'diag_immediate',
          emoji: '🩺',
          label: tr('Expliquer la cause & le GPIO'),
          prompt: activeDiagnosis != null
              ? 'Explique-moi en détail le diagnostic « ${activeDiagnosis.headline} » (${activeDiagnosis.gpioPinDetail}) et comment le résoudre.'
              : 'La machine est en alarme : quelle est la cause exacte et quel capteur GPIO vérifier ?',
        ),
        SuggestedNextAction(
          id: 'unlock_x',
          emoji: '🔓',
          label: tr('Déverrouiller (\$X)'),
          prompt: 'Déverrouille l\'alarme machine (\$X) pour me permettre de dégager l\'axe.',
          directGcode: '\$X',
        ),
        SuggestedNextAction(
          id: 'rehome_all',
          emoji: '🏠',
          label: tr('Relancer Homing (\$H)'),
          prompt: 'Lance une prise d\'origine machine complète (\$H).',
          directGcode: '\$H',
        ),
        SuggestedNextAction(
          id: 'demo_recovery',
          emoji: '⚡',
          label: tr('Vérifier l\'alimentation ATX / Broche'),
          prompt: 'Comment vérifier si la chute de tension vient du relais broche 775 (GPIO 21) ou de l\'alimentation ATX 12V ?',
        ),
      ];
    }

    // 2. Après le chargement d'un fichier STEP ou d'un cas de démo (Manufacturing / Médecine)
    if (lastOp == OperationEventType.stepFileLoaded ||
        lastOp == OperationEventType.demoBenchmarkLoaded) {
      final isMed = activeDemoDomain == 'medicine';
      return [
        SuggestedNextAction(
          id: 'gen_5axis_cam',
          emoji: '⚙️',
          label: isMed
              ? tr('Générer G-Code 5 axes (Implant/Médical)')
              : tr('Générer G-Code 5 axes (Manufacturing)'),
          prompt: activeFilePath != null
              ? 'Génère ou analyse le parcours G-code 5 axes pour le fichier chargé ($activeFilePath) et donne-moi les paramètres de coupe.'
              : 'Prépare le parcours G-code de finition 5 axes pour cette pièce.',
        ),
        SuggestedNextAction(
          id: 'check_envelope',
          emoji: '📏',
          label: tr('Vérifier l\'enveloppe X/Y/Z/A/C'),
          prompt: 'Vérifie si les dimensions de la pièce chargée rentrent dans les courses X, Y, Z, A, C de la machine.',
        ),
        SuggestedNextAction(
          id: 'switch_demo_domain',
          emoji: isMed ? '🏭' : '🏥',
          label: isMed
              ? tr('Tester STEP Manufacturing (Turbine)')
              : tr('Tester STEP Médecine (Implant crânien)'),
          prompt: isMed
              ? 'Lance la démonstration Manufacturing avec le fichier STEP de la turbine 5 axes (IMPELLER.STP).'
              : 'Lance la démonstration Médecine avec le fichier STEP de l\'implant crânien (rend.step).',
          demoSampleId: isMed ? 'manufacturing_impeller' : 'medicine_cranial_implant',
        ),
        SuggestedNextAction(
          id: 'probe_origin',
          emoji: '📍',
          label: tr('Préparer le palpage G54'),
          prompt: 'Guide-moi pour palper l\'origine pièce G54 avant d\'usiner ce modèle.',
        ),
      ];
    }

    // 3. Après la génération ou le chargement d'un programme G-Code
    if (lastOp == OperationEventType.gcodeGeneratedOrLoaded) {
      return [
        SuggestedNextAction(
          id: 'air_cut_check',
          emoji: '✈️',
          label: tr('Conseils test à vide (Air-Cut Z+20)'),
          prompt: 'Comment décaler mon origine Z de +20 mm en G54 pour exécuter ce programme à vide (air-cut) sans toucher la matière ?',
        ),
        SuggestedNextAction(
          id: 'verify_rtcp',
          emoji: '🛡️',
          label: tr('Contrôler la sécurité 5 axes (RTCP)'),
          prompt: 'Vérifie que le programme G-code actif ne contient aucun code RTCP incompatible (G43.4, TRAORI) ni collision.',
        ),
        SuggestedNextAction(
          id: 'start_cycle',
          emoji: '▶️',
          label: tr('Checklist avant départ cycle'),
          prompt: 'Fais-moi la checklist de sécurité finale avant de lancer l\'usinage sur la machine.',
        ),
      ];
    }

    // 4. Après un Homing terminé
    if (lastOp == OperationEventType.homingCompleted) {
      return [
        SuggestedNextAction(
          id: 'go_probing',
          emoji: '📍',
          label: tr('Palper l\'origine pièce Z (G54)'),
          prompt: 'Le homing est fait : comment palper le zéro Z de ma pièce avec la sonde ?',
        ),
        SuggestedNextAction(
          id: 'demo_manuf',
          emoji: '🏭',
          label: tr('Tester STEP Manufacturing (IMPELLER)'),
          prompt: 'Charge la démo Manufacturing avec le fichier STEP IMPELLER.STP.',
          demoSampleId: 'manufacturing_impeller',
        ),
        SuggestedNextAction(
          id: 'demo_med',
          emoji: '🏥',
          label: tr('Tester STEP Médecine (Implant crânien)'),
          prompt: 'Charge la démo Médecine avec le fichier STEP de l\'implant crânien (rend.step).',
          demoSampleId: 'medicine_cranial_implant',
        ),
      ];
    }

    // 5. Après une connexion machine
    if (lastOp == OperationEventType.machineConnected) {
      return [
        SuggestedNextAction(
          id: 'do_homing',
          emoji: '🏠',
          label: tr('Lancer le Homing (\$H)'),
          prompt: 'Lance le cycle de prise d\'origine machine (\$H).',
          directGcode: '\$H',
        ),
        SuggestedNextAction(
          id: 'check_pins',
          emoji: '🔌',
          label: tr('Vérifier l\'état des capteurs NF'),
          prompt: 'Vérifie l\'état actuel de la machine, des fins de course X/Y/Z/A et de l\'arrêt d\'urgence.',
        ),
        SuggestedNextAction(
          id: 'start_handson_demo',
          emoji: '🎬',
          label: tr('Prise en main guidée (Images & Vidéos)'),
          prompt: 'Présente-moi les fonctionnalités clés de Forgeron avec les prises en main visuelles.',
        ),
      ];
    }

    // 6. Par défaut (Démarrage / Navigation générale / Mode Démo)
    return [
      SuggestedNextAction(
        id: 'handson_tour',
        emoji: '🎬',
        label: tr('Prise en main (Images & Vidéos)'),
        prompt: 'Présente-moi chaque fonctionnalité de Forgeron avec les visuels de prise en main et des cas de test.',
      ),
      SuggestedNextAction(
        id: 'demo_step_manufacturing',
        emoji: '🏭',
        label: tr('Démo STEP Manufacturing (Turbine 5-Axes)'),
        prompt: 'Charge le fichier STEP de démonstration Manufacturing (IMPELLER.STP) et montre-moi le parcours 5 axes.',
        demoSampleId: 'manufacturing_impeller',
      ),
      SuggestedNextAction(
        id: 'demo_step_medicine',
        emoji: '🏥',
        label: tr('Démo STEP Médecine (Implant crânien)'),
        prompt: 'Charge le fichier STEP de démonstration Médecine (implant crânien rend.step) et prépare l\'analyse 5 axes.',
        demoSampleId: 'medicine_cranial_implant',
      ),
      SuggestedNextAction(
        id: 'check_machine_memory',
        emoji: '🧠',
        label: tr('État complet & Mémoire Contrôleur'),
        prompt: 'Donne-moi le bilan complet de l\'état de la machine, des axes X/Y/Z/A/C et de la santé de l\'ESP32.',
      ),
    ];
  }
}

class ControllerMemoryNotifier extends StateNotifier<ControllerMemoryState> {
  final Ref _ref;
  StreamSubscription<String>? _rawMsgSub;
  MachineState? _lastNonOfflineState;
  bool _wasOfflineSinceLastState = false;
  bool _sessionInitialized = false;

  static const List<String> windowNames = [
    'Contrôle & Cockpit 5-Axes',
    'Palpage & Origines WCS',
    'Table d\'Outils & Cinématique',
    'Atelier CAO/STEP & Programmes G-Code',
    'Caméra Vision & Reconstruction 3D',
    'Diagnostics Électriques & Réseau',
    'Console Copilote IA',
    'Paramètres Système',
  ];

  ControllerMemoryNotifier(this._ref)
      : super(
          ControllerMemoryState(
            nextSuggestions: NextBestActionEngine.compute(
              lastOp: OperationEventType.appStarted,
              machineStatus: MachineStatus.offline,
            ),
          ),
        ) {
    _initListeners();
  }

  void _initListeners() {
    // 1. Écoute des changements d'état machine
    _ref.listen<AsyncValue<MachineState>>(machineStateProvider, (prev, next) {
      final s = next.valueOrNull;
      if (s != null) _onMachineStateChanged(s);
    });

    // 2. Écoute des lignes brutes de l'ESP32 pour détecter les bannières de boot / brownouts
    try {
      final repo = _ref.read(machineRepositoryProvider);
      _rawMsgSub = repo.messageStream.listen(_onRawControllerLine);
    } catch (_) {}
  }

  Duration? get _currentContinuousRunDuration {
    final start = state.continuousRunStartedAt;
    if (start == null) return null;
    return DateTime.now().difference(start);
  }

  void _onRawControllerLine(String line) {
    final currentMachine = _ref.read(machineRepositoryProvider).currentState;
    final reboot = Esp32RebootDetector.inspectRawLine(
      line,
      currentState: currentMachine,
      sessionAlreadyInitialized: _sessionInitialized,
      lastSpindleStartAt: state.lastSpindleStartAt,
      continuousRunDuration: _currentContinuousRunDuration,
    );
    if (reboot != null) {
      recordEsp32Reboot(reboot);
    }
    if (line.contains('Grbl ') ||
        line.contains('FluidNC') ||
        line.startsWith('<')) {
      _sessionInitialized = true;
    }
  }

  void _onMachineStateChanged(MachineState next) {
    final now = DateTime.now();

    if (next.status == MachineStatus.offline) {
      _wasOfflineSinceLastState = true;
      return;
    }

    _sessionInitialized = true;

    // Suivi de l'allumage broche (pour corrélation Brownout M3)
    DateTime? spindleStart = state.lastSpindleStartAt;
    if (next.spindleOn && !(_lastNonOfflineState?.spindleOn ?? false)) {
      spindleStart = now;
    }

    // Suivi de la durée d'usinage continu (pour corrélation thermique)
    DateTime? runStart = state.continuousRunStartedAt;
    bool clearRun = false;
    if (next.status == MachineStatus.run &&
        _lastNonOfflineState?.status != MachineStatus.run) {
      runStart = now;
    } else if (next.status != MachineStatus.run &&
        next.status != MachineStatus.hold) {
      clearRun = true;
    }

    // Détection heuristique d'un reboot ESP32 après micro-coupure
    final transitionReboot = Esp32RebootDetector.inspectStateTransition(
      _lastNonOfflineState,
      next,
      wasOfflineBetween: _wasOfflineSinceLastState,
      lastSpindleStartAt: spindleStart,
      continuousRunDuration: _currentContinuousRunDuration,
      now: now,
    );

    if (transitionReboot != null) {
      _wasOfflineSinceLastState = false;
      _lastNonOfflineState = next;
      recordEsp32Reboot(transitionReboot);
      return;
    }

    // Transition vers ALARM
    if (next.status == MachineStatus.alarm &&
        _lastNonOfflineState?.status != MachineStatus.alarm) {
      final diag = HardwareRootCauseCorrelator.diagnoseAlarm(next, now: now);
      state = state.copyWith(
        lastSpindleStartAt: spindleStart,
        continuousRunStartedAt: runStart,
        clearContinuousRun: clearRun,
        activeDiagnosis: diag,
        lastOperationType: OperationEventType.alarmTriggered,
        lastOperationSummary: diag.headline,
        nextSuggestions: NextBestActionEngine.compute(
          lastOp: OperationEventType.alarmTriggered,
          machineStatus: next.status,
          activeFilePath: state.activeFilePath,
          activeDemoDomain: state.activeDemoDomain,
          activeDiagnosis: diag,
        ),
      );
    } else if (_lastNonOfflineState?.status == MachineStatus.alarm &&
        next.status == MachineStatus.idle) {
      // Alarme levée ($X)
      state = state.copyWith(
        lastSpindleStartAt: spindleStart,
        clearActiveDiagnosis: true,
        lastOperationType: OperationEventType.alarmCleared,
        lastOperationSummary: 'Alarme acquittée — Machine au repos (Idle)',
        nextSuggestions: NextBestActionEngine.compute(
          lastOp: OperationEventType.alarmCleared,
          machineStatus: next.status,
          activeFilePath: state.activeFilePath,
          activeDemoDomain: state.activeDemoDomain,
        ),
      );
    } else if (_lastNonOfflineState?.status == MachineStatus.home &&
        next.status == MachineStatus.idle) {
      // Fin de Homing ($H)
      state = state.copyWith(
        lastSpindleStartAt: spindleStart,
        clearActiveDiagnosis: true,
        lastOperationType: OperationEventType.homingCompleted,
        lastOperationSummary: 'Prise d\'origine machine (Homing) terminée',
        nextSuggestions: NextBestActionEngine.compute(
          lastOp: OperationEventType.homingCompleted,
          machineStatus: next.status,
          activeFilePath: state.activeFilePath,
          activeDemoDomain: state.activeDemoDomain,
        ),
      );
    } else if (_lastNonOfflineState == null &&
        next.status != MachineStatus.offline) {
      // Première connexion réussie
      state = state.copyWith(
        lastSpindleStartAt: spindleStart,
        lastOperationType: OperationEventType.machineConnected,
        lastOperationSummary: 'Connexion établie avec la carte ESP32 FluidNC',
        nextSuggestions: NextBestActionEngine.compute(
          lastOp: OperationEventType.machineConnected,
          machineStatus: next.status,
          activeFilePath: state.activeFilePath,
          activeDemoDomain: state.activeDemoDomain,
        ),
      );
    } else {
      state = state.copyWith(
        lastSpindleStartAt: spindleStart,
        continuousRunStartedAt: runStart,
        clearContinuousRun: clearRun,
      );
    }

    _wasOfflineSinceLastState = false;
    _lastNonOfflineState = next;
  }

  /// Enregistre un redémarrage temps réel de la carte ESP32 et met à jour le
  /// diagnostic et les suggestions de dépannage.
  void recordEsp32Reboot(Esp32RebootEvent event) {
    final diag = HardwareRootCauseCorrelator.diagnoseEsp32Reboot(event);
    final newCount = state.esp32RebootCount + 1;
    _ref.read(activityLogProvider.notifier).log(
          '🚨 ${event.title} (#$newCount) : ${event.rawSignature}',
        );
    state = state.copyWith(
      esp32RebootCount: newCount,
      lastRebootEvent: event,
      activeDiagnosis: diag,
      lastOperationType: OperationEventType.esp32RebootDetected,
      lastOperationSummary: '${event.title} (reboot #$newCount)',
      nextSuggestions: NextBestActionEngine.compute(
        lastOp: OperationEventType.esp32RebootDetected,
        machineStatus: MachineStatus.alarm,
        activeFilePath: state.activeFilePath,
        activeDemoDomain: state.activeDemoDomain,
        activeDiagnosis: diag,
      ),
    );
  }

  /// Met à jour la fenêtre/onglet actif pour que l'Agent IA sache toujours où
  /// se trouve l'opérateur.
  void setActiveWindow(int index, {String? customTitle}) {
    final title = customTitle ??
        (index >= 0 && index < windowNames.length
            ? windowNames[index]
            : 'Fenêtre #$index');
    state = state.copyWith(
      activeWindowIndex: index,
      activeWindowName: title,
    );
  }

  /// Enregistre une opération métier (chargement STEP, génération G-Code,
  /// lancement démo, palpage) et génère immédiatement de nouvelles suggestions.
  void recordOperation(
    OperationEventType type, {
    required String summary,
    String? filePath,
    String? demoDomain,
  }) {
    final currentStatus =
        _ref.read(machineRepositoryProvider).currentState.status;
    final nextFile = filePath ?? state.activeFilePath;
    final nextDomain = demoDomain ?? state.activeDemoDomain;

    state = state.copyWith(
      activeFilePath: nextFile,
      activeDemoDomain: nextDomain,
      lastOperationType: type,
      lastOperationSummary: summary,
      nextSuggestions: NextBestActionEngine.compute(
        lastOp: type,
        machineStatus: currentStatus,
        activeFilePath: nextFile,
        activeDemoDomain: nextDomain,
        activeDiagnosis: state.activeDiagnosis,
      ),
    );
  }

  @override
  void dispose() {
    _rawMsgSub?.cancel();
    super.dispose();
  }
}

final controllerMemoryProvider =
    StateNotifierProvider<ControllerMemoryNotifier, ControllerMemoryState>(
        (ref) => ControllerMemoryNotifier(ref));
