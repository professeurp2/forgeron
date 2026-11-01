import 'dart:math' as math;

/// Durée de chaque bloc telle que la machine l'exécute, selon les mêmes règles
/// que `pipeline/verify5.py` : grbl mesure un bloc sur √(mm² + deg²), et chaque
/// axe reste plafonné par son `max_rate`. Les accélérations ne sont pas comptées :
/// les durées sont des minorants.
class GcodeReplay {
  const GcodeReplay._();

  /// `max_rate` de `scratch/config_5axes_production.yaml` : X, Y, Z, A, C.
  static const List<double> maxRates = [500, 500, 300, 3600, 3600];

  /// Temps cumulé (s) à la fin de chaque point de [points] ([x, y, z, a, c, type],
  /// type 0 = rapide). [feedAt] rend le F modal en mm/min du point demandé.
  static List<double> cumulativeSeconds(
    List<List<double>> points,
    double Function(int index) feedAt,
  ) {
    final out = List<double>.filled(points.length, 0.0);
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += blockSeconds(points[i - 1], points[i], feedAt(i));
      out[i] = total;
    }
    return out;
  }

  static double blockSeconds(List<double> from, List<double> to, double feed) {
    var squared = 0.0;
    var axisMinutes = 0.0;
    for (var k = 0; k < 5; k++) {
      final d = to[k] - from[k];
      squared += d * d;
      axisMinutes = math.max(axisMinutes, d.abs() / maxRates[k]);
    }
    final isRapid = to[5] == 0.0;
    final minutes = !isRapid && feed > 0
        ? math.max(axisMinutes, math.sqrt(squared) / feed)
        : axisMinutes;
    return minutes * 60.0;
  }
}
