import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/utils/gcode_parser.dart';
import 'package:forgeron/core/utils/trajectory_validator.dart';
import 'package:forgeron/domain/models/trunnion_config.dart';

AnalyzedGCode _fromToolpath(List<List<double>> toolpath) => AnalyzedGCode(
      lines: List.filled(toolpath.length, ''),
      toolpath: toolpath,
      modalStates: const {},
    );

void main() {
  group('TrajectoryValidator — limites issues de TrunnionConfig', () {
    test('Rejette un Z sous la course configurée (pas une constante figée)', () {
      const config = TrunnionConfig(travelZ: 100.0);
      final analyzed = _fromToolpath([
        [0, 0, -50, 0, 0, 1],
        [0, 0, -150, 0, 0, 1], // -150 < -travelZ (-100) → doit échouer
      ]);

      final result = TrajectoryValidator.validate(analyzed, config: config);

      expect(result.isValid, false);
      expect(result.errorLine, 2);
    });

    test('Accepte un Z valide pour une course Z plus grande', () {
      const config = TrunnionConfig(travelZ: 200.0);
      final analyzed = _fromToolpath([
        [0, 0, -150, 0, 0, 1], // valide car -150 >= -200
      ]);

      final result = TrajectoryValidator.validate(analyzed, config: config);

      expect(result.isValid, true);
    });

    test('Rejette un angle A hors de la plage configurée', () {
      const config = TrunnionConfig(aAxisMaxAngle: 45.0);
      final analyzed = _fromToolpath([
        [0, 0, 0, 60, 0, 1], // 60° > 45° configuré → doit échouer
      ]);

      final result = TrajectoryValidator.validate(analyzed, config: config);

      expect(result.isValid, false);
    });

    test('Accepte un angle A dans la plage par défaut (±90°)', () {
      const config = TrunnionConfig();
      final analyzed = _fromToolpath([
        [0, 0, 0, 89, 0, 1],
      ]);

      final result = TrajectoryValidator.validate(analyzed, config: config);

      expect(result.isValid, true);
    });
  });
}
