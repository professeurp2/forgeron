import '../models/machine_state.dart';

abstract class MachineRepository {
  /// Flux (Stream) des états de la machine.
  Stream<MachineState> get stateStream;

  /// Flux des messages bruts provenant de la machine.
  Stream<String> get messageStream;

  /// Flux du trafic réseau brut (TX/RX) pour le diagnostic.
  Stream<String> get trafficStream;

  /// État actuel de la machine.
  MachineState get currentState;

  /// Envoie une chaîne G-code brute à la machine.
  Future<void> sendGCode(String gcode);

  /// Envoie une commande temps réel brute (ex: '~', '!', '\x18', '$X').
  void sendRaw(String data);

  /// Envoie plusieurs lignes de G-code optimisées pour le streaming haute vitesse.
  Future<void> sendGCodeBatch(List<String> lines);

  /// Déclenche un arrêt d'urgence.
  Future<void> emergencyStop();

  /// Effectue la prise d'origine (Home) des axes spécifiés. Si vide, tous les axes configurés.
  Future<void> home([List<String> axes = const []]);

  /// Déplace (Jog) la machine le long d'un axe.
  Future<void> jog(String axis, double distance, double feedrate);
  
  /// Reprend l'exécution du programme.
  Future<void> resume();

  /// Met en pause l'exécution du programme.
  Future<void> pause();
  
  /// Réinitialise le contrôleur de la machine (soft reset).
  Future<void> reset();

  /// Définit le pourcentage d'override de la vitesse d'avance (10-200%).
  Future<void> setFeedOverride(int percent);

  /// Définit le pourcentage d'override de la vitesse de broche (10-200%).
  Future<void> setSpindleOverride(int percent);

  /// Définit la vitesse de simulation (ignoré par les repositories physiques).
  void setSimulationSpeed(double speed);
}
