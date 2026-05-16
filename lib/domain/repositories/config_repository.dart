abstract class ConfigRepository {
  /// Récupère la configuration YAML brute.
  Future<String> getConfig();

  /// Sauvegarde la configuration YAML sur la machine.
  Future<void> saveConfig(String yaml);

  /// Sauvegarde (backup) la configuration actuelle.
  Future<void> backupConfig();

  /// Restaure la configuration depuis une sauvegarde.
  Future<void> restoreConfig();
}
