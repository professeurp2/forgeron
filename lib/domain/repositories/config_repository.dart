abstract class ConfigRepository {
  /// Gets the raw YAML configuration.
  Future<String> getConfig();

  /// Saves the YAML configuration to the machine.
  Future<void> saveConfig(String yaml);

  /// Backs up the current configuration.
  Future<void> backupConfig();

  /// Restores the configuration from a backup.
  Future<void> restoreConfig();
}
