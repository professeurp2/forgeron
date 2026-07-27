import 'dart:io';
import 'lib/core/utils/gcode_parser.dart';
import 'lib/core/utils/trajectory_validator.dart';
import 'lib/domain/models/trunnion_config.dart';

void main() async {
  final content = File('test_5axis.nc').readAsStringSync();
  final analyzed = await GCodeParser.parseLargeFile(content);
  final result = TrajectoryValidator.validate(analyzed, config: const TrunnionConfig());
  
  if (result.isValid) {
    print('SUCCESS: G-Code is valid');
  } else {
    print('ERROR: ${result.errorMessage} on line ${result.errorLine}');
  }
}
