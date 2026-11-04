import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Environnement embarqué par l'installateur Windows (`installer/`).
///
/// L'installateur pose, à côté de `forgeron.exe`, un fichier
/// `forgeron_bundle.json` et un dossier `runtime/` (Python + OCP, Ollama et
/// ses modèles, superviseur des services). En développement (`flutter run`),
/// ce fichier n'existe pas : [isPresent] est faux et rien ne change — les
/// services cherchent alors `pipeline/.venv312` et les serveurs du réseau
/// comme avant.
class BundledRuntime {
  BundledRuntime._(this.appDir, this.manifest);

  /// Dossier d'installation (celui de `forgeron.exe`), ou `null` hors paquet.
  final Directory? appDir;

  /// Contenu de `forgeron_bundle.json` (version, modèles embarqués…).
  final Map<String, dynamic> manifest;

  static const ollamaUrl = 'http://127.0.0.1:11434';
  static const reco3dUrl = 'http://127.0.0.1:8765';

  static BundledRuntime? _instance;

  /// Détection faite une fois : le paquet ne change pas en cours de route.
  static BundledRuntime get instance => _instance ??= _detect();

  static BundledRuntime _detect() {
    if (kIsWeb || !Platform.isWindows) return BundledRuntime._(null, const {});
    try {
      final dir = File(Platform.resolvedExecutable).parent;
      final marker = File(_join(dir.path, 'forgeron_bundle.json'));
      if (!marker.existsSync()) return BundledRuntime._(null, const {});
      Map<String, dynamic> manifest = const {};
      try {
        manifest = jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        // Manifeste illisible : le paquet reste utilisable, sans métadonnées.
      }
      return BundledRuntime._(dir, manifest);
    } catch (_) {
      return BundledRuntime._(null, const {});
    }
  }

  bool get isPresent => appDir != null;

  String? _path(List<String> parts) =>
      appDir == null ? null : parts.fold<String>(appDir!.path, _join);

  /// `runtime/python/python.exe` s'il existe.
  String? get pythonExe {
    final p = _path(['runtime', 'python', 'python.exe']);
    return p != null && File(p).existsSync() ? p : null;
  }

  String? get _pythonwExe {
    final p = _path(['runtime', 'python', 'pythonw.exe']);
    return p != null && File(p).existsSync() ? p : null;
  }

  String? get _supervisorScript {
    final p = _path(['runtime', 'forgeron_services.py']);
    return p != null && File(p).existsSync() ? p : null;
  }

  /// Ollama est-il embarqué (et donc démarré par le superviseur) ?
  bool get hasOllama {
    final p = _path(['runtime', 'ollama', 'ollama.exe']);
    return p != null && File(p).existsSync();
  }

  /// reco3d est-il embarqué ?
  bool get hasReco3d {
    final p = _path(['tool', 'reco3d', 'service.py']);
    return p != null && File(p).existsSync();
  }

  /// Modèle principal et modèle de vision déclarés par le manifeste.
  String get defaultChatModel =>
      (manifest['chat_model'] as String?)?.trim().isNotEmpty == true
          ? manifest['chat_model'] as String
          : 'forgeron-qwen';
  String get defaultVisionModel => (manifest['vision_model'] as String?)?.trim() ?? '';

  /// Variables à passer aux scripts Python du pipeline quand ils tournent
  /// dans le Python embarqué : pas de paquets « utilisateur » du poste qui
  /// viendraient masquer ceux du paquet, pas de `.pyc` écrits dans le
  /// dossier du programme.
  Map<String, String>? get pythonEnvironment => isPresent
      ? const {
          'PYTHONNOUSERSITE': '1',
          'PYTHONDONTWRITEBYTECODE': '1',
          'PYTHONUTF8': '1',
        }
      : null;

  bool _started = false;

  /// Lance le superviseur des services locaux (Ollama, reco3d). Sans effet
  /// hors paquet, ou s'il a déjà été lancé par cette instance.
  ///
  /// Le superviseur surveille le PID de l'application et arrête tout ce
  /// qu'il a démarré quand elle se ferme — même sur un plantage — donc rien
  /// à faire ici à la fermeture.
  Future<void> startServices() async {
    if (_started || !isPresent) return;
    final pythonw = _pythonwExe ?? pythonExe;
    final script = _supervisorScript;
    if (pythonw == null || script == null) {
      debugPrint('[Runtime] superviseur introuvable : services locaux non démarrés');
      return;
    }
    _started = true;
    try {
      await Process.start(
        pythonw,
        [script, '--parent-pid', '$pid', '--app-dir', appDir!.path],
        workingDirectory: appDir!.path,
        environment: pythonEnvironment,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      _started = false;
      debugPrint('[Runtime] lancement du superviseur impossible : $e');
    }
  }

  static String _join(String a, String b) => '$a${Platform.pathSeparator}$b';
}

