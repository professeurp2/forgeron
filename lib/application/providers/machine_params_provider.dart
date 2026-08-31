import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_provider.dart';

/// Cinématique d'un axe, extraite du config.yaml FluidNC.
class AxisKinematics {
  final String axis; // 'X','Y','Z','A','C'
  final double? stepsPerMm; // steps_per_mm
  final double? maxRate; // max_rate_mm_per_min
  final double? accel; // acceleration_mm_per_sec2
  final double? maxTravel; // max_travel_mm

  /// `homing.mpos_mm` : coordonnee machine atteinte au contact du capteur.
  final double? homingMpos;

  /// `homing.positive_direction` : sens dans lequel l\'axe part chercher son
  /// capteur.
  final bool? homingPositive;

  const AxisKinematics({
    required this.axis,
    this.stepsPerMm,
    this.maxRate,
    this.accel,
    this.maxTravel,
    this.homingMpos,
    this.homingPositive,
  });

  /// Bornes de la position machine, en mm ou degres.
  ///
  /// FluidNC place l\'origine machine AU CAPTEUR : `mpos_mm` est la coordonnee
  /// atteinte au contact, et le sens du homing dit de quel cote la course se
  /// deploie a partir de la :
  ///   - `positive_direction: false` -> capteur au minimum : [mpos, mpos+course]
  ///   - `positive_direction: true`  -> capteur au maximum : [mpos-course, mpos]
  ///
  /// Sans cette distinction, un axe bipolaire comme A (capteur a -88, course
  /// 178, donc -88 -> +90) serait mal situe : une simple valeur absolue
  /// rapportee a la course donnerait la meme fraction a -88 et a +88.
  (double, double)? get machineRange {
    final travel = maxTravel;
    final mpos = homingMpos;
    if (travel == null || travel <= 0 || mpos == null) return null;
    return (homingPositive ?? false)
        ? (mpos - travel, mpos)
        : (mpos, mpos + travel);
  }

  /// Position de [machinePos] dans la course, de 0 (une extremite) a 1
  /// (l\'autre). `null` si la course n\'est pas connue.
  double? travelFraction(double machinePos) {
    final range = machineRange;
    if (range == null) return null;
    final (lo, hi) = range;
    if (hi <= lo) return null;
    return ((machinePos - lo) / (hi - lo)).clamp(0.0, 1.0);
  }
}

/// Les 4 paramètres éditables et leur clé YAML FluidNC.
enum KinematicField {
  steps('PAS', 'steps_per_mm', 'pas/mm'),
  maxRate('F-MAX', 'max_rate_mm_per_min', 'mm/min'),
  accel('ACCEL', 'acceleration_mm_per_sec2', 'mm/s²'),
  maxTravel('COURSE', 'max_travel_mm', 'mm');

  final String label;
  final String yamlKey;
  final String unit;
  const KinematicField(this.label, this.yamlKey, this.unit);
}

/// Commande FluidNC pour changer un réglage à chaud (effet immédiat, volatil).
/// Ex : `$/axes/x/steps_per_mm=160.000`
String fluidNcSetCommand(String axis, KinematicField field, double value) {
  return '\$/axes/${axis.toLowerCase()}/${field.yamlKey}=${value.toStringAsFixed(3)}';
}

/// Parse la cinématique des axes (X,Y,Z,A,C) depuis le YAML FluidNC.
/// Analyse ligne par ligne (structure indentée à 2 espaces).
List<AxisKinematics> parseAxisKinematics(String yaml) {
  const want = ['x', 'y', 'z', 'a', 'c'];
  const keys = [
    'steps_per_mm',
    'max_rate_mm_per_min',
    'acceleration_mm_per_sec2',
    'max_travel_mm',
    // Sous `homing:` — la boucle balaie toutes les lignes de l'axe, quel que
    // soit leur niveau d'indentation, donc la cle imbriquee est atteinte.
    'mpos_mm',
  ];
  final data = {for (final a in want) a: <String, double>{}};
  final positive = <String, bool>{};

  final lines = yaml.split('\n');
  bool inAxes = false;
  int axesIndent = -1;
  String? curAxis;

  for (final raw in lines) {
    final line = raw.replaceAll('\t', '  ');
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final indent = line.length - trimmed.length;

    if (trimmed.startsWith('axes:')) {
      inAxes = true;
      axesIndent = indent;
      curAxis = null;
      continue;
    }
    if (!inAxes) continue;

    // Sortie de la section axes (dédent au niveau du parent).
    if (indent <= axesIndent) {
      inAxes = false;
      curAxis = null;
      continue;
    }

    // En-tête d'axe : une seule lettre suivie de ':' au premier niveau.
    final head = RegExp(r'^([a-zA-Z]):\s*$').firstMatch(trimmed);
    if (head != null && indent == axesIndent + 2) {
      final letter = head.group(1)!.toLowerCase();
      curAxis = want.contains(letter) ? letter : null;
      continue;
    }

    if (curAxis == null) continue;

    final pd = RegExp(r'^positive_direction:\s*(true|false)').firstMatch(trimmed);
    if (pd != null) positive[curAxis] = pd.group(1) == 'true';

    for (final key in keys) {
      final km = RegExp('^$key:\\s*([-\\d.]+)').firstMatch(trimmed);
      if (km != null) {
        final v = double.tryParse(km.group(1)!);
        if (v != null) data[curAxis]![key] = v;
      }
    }
  }

  return want
      .map((a) => AxisKinematics(
            axis: a.toUpperCase(),
            stepsPerMm: data[a]!['steps_per_mm'],
            maxRate: data[a]!['max_rate_mm_per_min'],
            accel: data[a]!['acceleration_mm_per_sec2'],
            maxTravel: data[a]!['max_travel_mm'],
            homingMpos: data[a]!['mpos_mm'],
            homingPositive: positive[a],
          ))
      .toList();
}

/// Réécrit dans [yaml] les valeurs de cinématique fournies ([byAxis] : axe
/// minuscule → {clé_yaml: valeur}), en respectant l'indentation FluidNC. Seules
/// les lignes de valeurs concernées sont modifiées ; le reste est intact.
/// Retourne le YAML patché (à ré-uploader vers config.yaml).
String patchAxisKinematicsYaml(
    String yaml, Map<String, Map<String, double>> byAxis) {
  const want = ['x', 'y', 'z', 'a', 'c'];
  final lines = yaml.split('\n');
  bool inAxes = false;
  int axesIndent = -1;
  String? curAxis;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].replaceAll('\t', '  ');
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final indent = line.length - trimmed.length;

    if (trimmed.startsWith('axes:')) {
      inAxes = true;
      axesIndent = indent;
      curAxis = null;
      continue;
    }
    if (!inAxes) continue;
    if (indent <= axesIndent) {
      inAxes = false;
      curAxis = null;
      continue;
    }

    final head = RegExp(r'^([a-zA-Z]):\s*$').firstMatch(trimmed);
    if (head != null && indent == axesIndent + 2) {
      final letter = head.group(1)!.toLowerCase();
      curAxis = want.contains(letter) ? letter : null;
      continue;
    }
    if (curAxis == null || !byAxis.containsKey(curAxis)) continue;

    final km = RegExp(r'^([a-z_]+):\s*[-\d.]+').firstMatch(trimmed);
    if (km != null) {
      final key = km.group(1)!;
      final nv = byAxis[curAxis]![key];
      if (nv != null) {
        lines[i] = '${' ' * indent}$key: ${nv.toStringAsFixed(3)}';
      }
    }
  }
  return lines.join('\n');
}

/// Cinématique réelle des axes, dérivée du config (live ou cache offline).
final axisKinematicsProvider = Provider<AsyncValue<List<AxisKinematics>>>((ref) {
  final cfg = ref.watch(configResultProvider);
  return cfg.whenData((res) => parseAxisKinematics(res.yaml));
});
