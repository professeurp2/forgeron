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
  ///
  /// [onStall] est appelé si la machine cesse d'acquitter (liaison ou blocage) —
  /// sans quoi l'UI resterait indéfiniment en « RUN ».
  Future<void> sendGCodeBatch(
    List<String> lines, {
    void Function()? onComplete,
    void Function(int index)? onProgress,
    void Function(String reason)? onStall,
  });

  /// Déclenche un arrêt d'urgence.
  ///
  /// SÉCURITÉ : retourne `false` si la commande n'a **pas pu être transmise**
  /// (liaison coupée). L'appelant DOIT alors alerter l'opérateur : la machine
  /// n'est pas arrêtée, quoi qu'affiche l'interface.
  Future<bool> emergencyStop();

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

  /// Définit l'offset d'un système de coordonnées pièce via `G10 L2`.
  ///
  /// [wcs] est le nom du système ('G54'..'G59'), [offset] une liste de 5
  /// valeurs [X, Y, Z, A, C] en unités machine (mm / degrés).
  Future<void> setWcsOffset(String wcs, List<double> offset);
}
