import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/file_picker_service.dart';

/// Un fichier G-code du dossier de travail (mobile).
class WorkFile {
  final String name;
  final String path;
  final int size;
  const WorkFile(this.name, this.path, this.size);
}

const _kWorkFolderKey = 'work_folder_path';

/// Chemin du **dossier de travail** choisi par l'utilisateur, persisté dans les
/// préférences pour rester disponible aux prochains lancements.
class WorkFolderNotifier extends StateNotifier<String?> {
  WorkFolderNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kWorkFolderKey);
  }

  Future<void> _persist(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_kWorkFolderKey);
    } else {
      await prefs.setString(_kWorkFolderKey, path);
    }
  }

  /// Ouvre le sélecteur de dossier Android et enregistre le choix.
  Future<String?> pickAndSet() async {
    final path = await FilePickerService.pickWorkFolder();
    if (path != null && path.isNotEmpty) {
      await _persist(path);
      state = path;
    }
    return path;
  }

  Future<void> clear() async {
    await _persist(null);
    state = null;
  }
}

final workFolderProvider =
    StateNotifierProvider<WorkFolderNotifier, String?>(
        (ref) => WorkFolderNotifier());

/// Compteur d'invalidation : incrémenté après ajout/édition pour rafraîchir la
/// liste sans changer de dossier.
final workFilesRefreshProvider = StateProvider<int>((ref) => 0);

/// Liste des fichiers G-code du dossier de travail. Lit le système de fichiers
/// (mobile) ; vide si aucun dossier n'est choisi ou en cas d'accès refusé.
final workFilesProvider = Provider<List<WorkFile>>((ref) {
  ref.watch(workFilesRefreshProvider); // dépendance pour le rafraîchissement
  final folder = ref.watch(workFolderProvider);
  if (folder == null || folder.isEmpty) return const [];
  try {
    return FilePickerService.listWorkFiles(folder)
        .map((f) => WorkFile(f.name, f.path, f.size))
        .toList();
  } catch (_) {
    // Accès refusé (permission « tous les fichiers » non accordée, URI SAF…).
    return const [];
  }
});
