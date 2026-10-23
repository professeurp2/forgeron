import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_provider.dart';

/// Configuration des fins de course d'un axe, lue depuis config.yaml FluidNC.
/// `soft_limits` est au niveau de l'axe ; `hard_limits` et `limit_*_pin` sont
/// sous `motor0` — mais comme ces clés sont uniques par axe, on les capte en
/// restant dans le bloc de l'axe courant.
class AxisLimitConfig {
  final String axis;
  final bool softLimits;
  final bool hardLimits;
  final String negPin;
  final String posPin;
  final String allPin;

  const AxisLimitConfig({
    required this.axis,
    this.softLimits = false,
    this.hardLimits = false,
    this.negPin = '',
    this.posPin = '',
    this.allPin = '',
  });
}

const _limitKeys = [
  'soft_limits',
  'hard_limits',
  'limit_neg_pin',
  'limit_pos_pin',
  'limit_all_pin',
];

List<AxisLimitConfig> parseLimitConfig(String yaml) {
  const want = ['x', 'y', 'z', 'a', 'c'];
  final data = {for (final a in want) a: <String, String>{}};

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
    if (curAxis == null) continue;

    for (final key in _limitKeys) {
      final m = RegExp('^$key:\\s*(.+?)\\s*\$').firstMatch(trimmed);
      if (m != null) {
        data[curAxis]![key] = m.group(1)!;
      }
    }
  }

  return want
      .map((a) => AxisLimitConfig(
            axis: a.toUpperCase(),
            softLimits: data[a]!['soft_limits'] == 'true',
            hardLimits: data[a]!['hard_limits'] == 'true',
            negPin: data[a]!['limit_neg_pin'] ?? '',
            posPin: data[a]!['limit_pos_pin'] ?? '',
            allPin: data[a]!['limit_all_pin'] ?? '',
          ))
      .toList();
}

/// Remplace dans [yaml] les valeurs des clés de limites fournies (par axe
/// minuscule → {clé: valeur en texte}). **Ne remplace que les lignes qui
/// existent déjà** (sûr : ne restructure pas le YAML). Retourne le YAML patché
/// et l'ensemble des clés « axe.clé » réellement appliquées, pour que l'UI
/// signale celles absentes (à ajouter via la WebUI).
({String yaml, Set<String> applied}) patchLimitConfig(
    String yaml, Map<String, Map<String, String>> byAxis) {
  const want = ['x', 'y', 'z', 'a', 'c'];
  final lines = yaml.split('\n');
  final applied = <String>{};
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

    final km = RegExp(r'^([a-z_]+):').firstMatch(trimmed);
    if (km != null) {
      final key = km.group(1)!;
      final nv = byAxis[curAxis]![key];
      if (nv != null) {
        lines[i] = '${' ' * indent}$key: $nv';
        applied.add('$curAxis.$key');
      }
    }
  }
  return (yaml: lines.join('\n'), applied: applied);
}

/// Config des limites dérivée du config.yaml (live ou cache).
final limitConfigProvider = Provider<AsyncValue<List<AxisLimitConfig>>>((ref) {
  final cfg = ref.watch(configResultProvider);
  return cfg.whenData((res) => parseLimitConfig(res.yaml));
});
