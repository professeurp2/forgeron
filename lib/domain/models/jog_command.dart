/// Modèle de commande Jog pour la machine CNC 5-axes Trunnion
///
/// Supporte les axes linéaires (X, Y, Z en mm) et
/// les axes rotatifs (A, C en degrés).
library;

enum JogMode { relative, absolute }

/// Commande jog typée pour un ou plusieurs axes simultanés.
class JogCommand {
  /// Axes à déplacer, ex: {'X': 10.0} ou {'A': 45.0, 'C': -90.0}
  final Map<String, double> axes;

  /// Vitesse de jog en mm/min pour les axes linéaires,
  /// ou en °/min pour les axes rotatifs (A, C).
  final double feedrate;

  /// Mode relatif (G91) ou absolu (G90)
  final JogMode mode;

  /// Unités métriques (G21) — toujours true pour cette machine
  final bool metric;

  const JogCommand({
    required this.axes,
    required this.feedrate,
    this.mode = JogMode.relative,
    this.metric = true,
  });

  /// Génère la commande GRBL/FluidNC formatée.
  /// Exemple : "$J=G91 G21 A45.000 C-90.000 F200\n"
  String toGrblCommand() {
    final modeStr = mode == JogMode.relative ? 'G91' : 'G90';
    final unitStr = metric ? 'G21' : 'G20';
    final axesStr = axes.entries
        .map((e) => '${e.key}${e.value.toStringAsFixed(3)}')
        .join(' ');
    final fStr = 'F${feedrate.toStringAsFixed(0)}';
    return '\$J=$modeStr $unitStr $axesStr $fStr\n';
  }

  /// Préfixes d'axes rotatifs de la machine trunnion
  static const rotaryAxes = {'A', 'C'};
  static const linearAxes = {'X', 'Y', 'Z'};

  /// Retourne true si cette commande ne concerne que des axes rotatifs
  bool get isRotaryOnly =>
      axes.keys.every((k) => rotaryAxes.contains(k.toUpperCase()));
}

/// Pas standards de jog pour les axes linéaires (mm)
class LinearJogStep {
  static const List<double> steps = [0.001, 0.01, 0.1, 1.0, 10.0, 100.0];
  static const double defaultFeedrate = 1000.0; // mm/min
}

/// Pas standards de jog pour les axes rotatifs (°)
class RotaryJogStep {
  static const List<double> steps = [0.1, 1.0, 5.0, 10.0, 45.0, 90.0];
  static const double defaultFeedrate = 200.0; // °/min
}
