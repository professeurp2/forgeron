import 'package:flutter/foundation.dart';
import '../../domain/repositories/config_repository.dart';

class MockConfigRepository implements ConfigRepository {
  String _currentConfig = '''
board: "Core_CNC_ESP32_V4"
name: "Machine_01_Trunnion"
stepping:
  engine: I2S_STATIC
  idle_ms: 250
  dir_delay_us: 1
  pulse_us: 2
axes:
  x:
    steps_per_mm: 160.000
    max_rate_mm_per_min: 5000.000
    acceleration_mm_per_sec2: 250.0
    max_travel_mm: 600.000
  y:
    steps_per_mm: 160.000
    max_rate_mm_per_min: 5000.000
    acceleration_mm_per_sec2: 250.0
    max_travel_mm: 800.000
''';

  @override
  Future<String> getConfig() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _currentConfig;
  }

  @override
  Future<void> saveConfig(String yaml) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentConfig = yaml;
  }

  @override
  Future<void> backupConfig() async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('Mock Config Backed Up');
  }

  @override
  Future<void> restoreConfig() async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('Mock Config Restored');
  }
}
