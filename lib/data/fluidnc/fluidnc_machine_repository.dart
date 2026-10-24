import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/models/machine_state.dart';
import '../../domain/repositories/machine_repository.dart';
import 'fluidnc_connection.dart';
import 'grbl_parser.dart';
import '../../application/services/streaming_service.dart';

/// Repository FluidNC Industriel pour machine CNC 5-axes Trunnion.
/// 
/// Exploite la classe FluidNCConnection pour une communication robuste :
///  - Gestion automatique du buffer (Backpressure).
///  - Reconnexion avec Exponential Backoff.
///  - Heartbeat pour la surveillance du lien WiFi.
class FluidNCMachineRepository implements MachineRepository {
  final FluidNCConnection _connection;
  final _stateController = StreamController<MachineState>.broadcast();
  MachineState _currentState = const MachineState(status: MachineStatus.offline);

  StreamSubscription? _msgSub;
  StreamSubscription? _statusSub;
  late final GCodeStreamingService _streamingService;

  FluidNCMachineRepository(this._connection) {
    _streamingService = GCodeStreamingService(_connection);
    _connection.connect();

    _msgSub = _connection.messages.listen(_handleMessage);
    _statusSub = _connection.status.listen((isConnected) {
      if (_stateController.isClosed) return;
      if (!isConnected) {
        // ── CRITIQUE : purger le streaming à la coupure ─────────────────────
        // Sans ça, _bytesInFlight / _sentByteCounts gardent les valeurs
        // d'avant la coupure. À la reconnexion, l'ESP32 a vidé son buffer RX
        // mais l'app croit encore y avoir des octets en vol : le
        // character-counting est désynchronisé, le buffer de 127 octets
        // déborde, des caractères sont perdus, et la machine exécute du
        // G-code tronqué. stop() remet les compteurs à zéro ET notifie l'UI
        // que le programme est interrompu.
        _streamingService.stop();
        _currentState = _currentState.copyWith(status: MachineStatus.offline);
        _stateController.add(_currentState);
      } else {
        // Séquence d'initialisation industrielle
        Future.delayed(const Duration(milliseconds: 500), () {
          _connection.sendRaw('\$G\n');   // État modal
          _connection.sendRaw('\$#\n');   // Offsets de travail
          _connection.sendRaw('\$I\n');   // Build info firmware (VER/OPT)
          _connection.sendRaw('[ESP110]\n'); // WiFi info
        });
      }
    });
  }

  void _handleMessage(String message) {
    if (_stateController.isClosed) return;

    // Détection des acquittements pour le StreamingService (Backpressure).
    // On ne compte un 'ok'/'error' QUE si un programme est réellement en cours :
    // sinon un 'ok' hors-bande (réponse à $X, $H, $G, $#… surtout le
    // déverrouillage d'alarme) serait pris pour l'acquittement d'une ligne →
    // compteur d'octets désynchronisé + relance de l'envoi dans la butée.
    if (message.trim() == 'ok' || message.startsWith('error:')) {
      if (_streamingService.isStreaming) _streamingService.handleAck();
    }

    final prevStatus = _currentState.status;
    final newState = GrblParser.parse(message, _currentState);
    if (newState != null) {
      _currentState = newState;
      _stateController.add(_currentState);

      // ── Entrée en ALARM (typiquement un dépassement de fin de course) ───────
      // Purge immédiate du flux : les lignes restantes du programme ne doivent
      // plus jamais partir. Sinon, au déverrouillage ($X), la machine repartait
      // dans la butée (→ re-alarme) et il fallait rebooter la carte. Combiné au
      // garde isStreaming ci-dessus, $X déverrouille désormais proprement.
      if (newState.status == MachineStatus.alarm &&
          prevStatus != MachineStatus.alarm) {
        _streamingService.stop();
      }
      // Signal de vie pour le watchdog de streaming : tant que la machine
      // bouge (Run/Jog→run, Home) OU est en pause volontaire (Hold, ex. M0
      // pour un changement d'outil), elle RÉPOND — ce n'est pas un blocage.
      // Sans Hold ici, une pause M0 (changement d'outil) déclenchait un faux
      // « Flux suspendu » au bout de 3 s. Si la machine meurt vraiment, plus
      // aucun statut n'arrive → le watchdog se déclenche quand même. SÉCURITÉ
      // préservée.
      if (newState.status == MachineStatus.run ||
          newState.status == MachineStatus.home ||
          newState.status == MachineStatus.hold) {
        _streamingService.notifyActivity();
      }
    }
  }

  @override
  Stream<MachineState> get stateStream => _stateController.stream;

  @override
  Stream<String> get messageStream => _connection.messages;

  /// Stream of raw network traffic (TX/RX) for diagnostics.
  Stream<String> get trafficStream => _connection.traffic;

  @override
  void sendRaw(String data) => _connection.sendRaw(data);

  @override
  MachineState get currentState => _currentState;

  @override
  Future<void> sendGCode(String gcode) async {
    _connection.sendGCode(gcode);
  }

  @override
  Future<void> sendGCodeBatch(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int index)? onProgress,
    void Function(String reason)? onStall,
  }) async {
    _streamingService.streamLines(
      lines,
      onComplete: onComplete,
      onStall: onStall,
      onProgress: (idx) {
        if (!_stateController.isClosed) {
          _currentState = _currentState.copyWith(activeLineIndex: idx);
          _stateController.add(_currentState);
        }
        onProgress?.call(idx);
      },
    );
  }

  @override
  Future<void> jog(String axis, double distance, double feedrate) async {
    // Annuler jog précédent (commande temps réel 0x85)
    _connection.sendRaw('\x85');
    // Le jog industriel utilise $J=G91...
    final cmd = '\$J=G91 G21 $axis${distance.toStringAsFixed(3)} F${feedrate.toStringAsFixed(0)}\n';
    _connection.sendRaw(cmd);
  }

  @override
  Future<bool> emergencyStop() async {
    // 1. Purger la file de streaming : plus une seule ligne ne doit partir.
    _streamingService.stop();
    // 2. Soft Reset (Ctrl-X) — et vérifier qu'il est RÉELLEMENT parti.
    final sent = _connection.sendRaw('\x18');
    if (!sent) {
      debugPrint(
        '[FORGERON] 🚨 ARRÊT D\'URGENCE NON TRANSMIS — liaison coupée. '
        'La machine n\'est PAS arrêtée.',
      );
    }
    return sent;
  }

  @override
  Future<void> home([List<String> axes = const []]) async {
    if (axes.isEmpty) {
      // Homing global — uniquement si des fins de course sont configurés
      _connection.sendGCode('\$H');
    } else {
      for (final axis in axes) {
        final a = axis.toUpperCase();
        // C n'a pas de fin de course → un $HC crasherait FluidNC : zéro G92 en
        // place. A a désormais un capteur de homing (gpio.5) → vrai $HA. X/Y/Z
        // → $H<axe>.
        if (a == 'C') {
          _connection.sendGCode('G92 ${a}0');
        } else {
          _connection.sendGCode('\$H$a');
        }
      }
    }
  }

  @override
  Future<void> resume() async {
    _connection.sendRaw('~'); // Cycle Start
  }

  @override
  Future<void> pause() async {
    _connection.sendRaw('!'); // Feed Hold
  }

  @override
  Future<void> reset() async {
    _connection.sendRaw('\x18');
  }

  // --- Overrides ---
  @override
  Future<void> setFeedOverride(int percent) async => _connection.sendRaw(percent == 100 ? '\x90' : (percent > 100 ? '\x91' : '\x92'));
  
  @override
  Future<void> setSpindleOverride(int percent) async => _connection.sendRaw(percent == 100 ? '\x99' : (percent > 100 ? '\x9A' : '\x9B'));

  @override
  void setSimulationSpeed(double speed) {} // Ignored for real hardware

  static const Map<String, int> _wcsToP = {
    'G54': 1, 'G55': 2, 'G56': 3, 'G57': 4, 'G58': 5, 'G59': 6,
  };

  @override
  Future<void> setWcsOffset(String wcs, List<double> offset) async {
    final p = _wcsToP[wcs.toUpperCase()];
    if (p == null) return;
    const axisLetters = ['X', 'Y', 'Z', 'A', 'C'];
    final cmd = StringBuffer('G10 L2 P$p');
    for (var i = 0; i < offset.length && i < axisLetters.length; i++) {
      cmd.write(' ${axisLetters[i]}${offset[i].toStringAsFixed(3)}');
    }
    _connection.sendGCode(cmd.toString());
    // Rafraîchir la table des offsets réelle depuis la machine.
    _connection.sendRaw('\$#\n');
  }

  void dispose() {
    _msgSub?.cancel();
    _statusSub?.cancel();
    _stateController.close();
    _streamingService.dispose();
    _connection.dispose();
  }
}
