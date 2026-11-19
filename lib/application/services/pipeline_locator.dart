import 'dart:io';

import 'bundled_runtime.dart';

/// Retrouve le dossier `pipeline/` et l'interpréteur Python qui va avec.
///
/// Trois services l'interrogent désormais (révolution, prismatique, aperçu
/// STEP) : c'était la même recherche recopiée à chaque fois, avec le risque
/// qu'une correction n'atterrisse que dans une copie.
///
/// La recherche remonte depuis le répertoire courant **et** depuis celui de
/// l'exécutable : `flutter run` et l'exe compilé
/// (`build/windows/x64/runner/Debug/`) n'ont pas le même répertoire courant,
/// et aucun des deux n'est fixe une fois l'app packagée.
class PipelineLocator {
  const PipelineLocator._();

  static const _maxDepth = 10;

  /// Dossier `pipeline/` contenant [marker], ou `null` si cette machine n'a
  /// pas l'environnement CAO installé.
  static Directory? findDir({required String marker}) {
    for (final start in {
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    }) {
      var dir = start;
      for (var i = 0; i < _maxDepth; i++) {
        final candidate = Directory(join(dir.path, 'pipeline'));
        if (File(join(candidate.path, marker)).existsSync()) return candidate;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    return null;
  }

  /// Interpréteur du venv du pipeline. `.venv312` d'abord : c'est celui qui
  /// porte les bindings OpenCASCADE (voir `pipeline/requirements-step.txt`).
  /// Dans l'installation Windows, il n'y a pas de venv : c'est le Python
  /// embarqué (`runtime/python`, voir [BundledRuntime]) qui les porte.
  static String? python(Directory pipelineDir) {
    final candidates = Platform.isWindows
        ? ['.venv312/Scripts/python.exe', '.venv/Scripts/python.exe']
        : ['.venv312/bin/python', '.venv/bin/python'];
    for (final rel in candidates) {
      final path = join(pipelineDir.path, rel.replaceAll('/', Platform.pathSeparator));
      if (File(path).existsSync()) return path;
    }
    return BundledRuntime.instance.pythonExe;
  }

  /// Environnement à passer à `Process.run` avec [python] : `null` (hérité)
  /// en développement, isolé des paquets du poste dans l'installation.
  static Map<String, String>? get environment =>
      BundledRuntime.instance.pythonEnvironment;

  static String join(String a, String b) => '$a${Platform.pathSeparator}$b';
}
