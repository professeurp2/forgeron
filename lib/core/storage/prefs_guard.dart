import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// État d'un fichier de préférences, tel que le voit [PrefsFileGuard].
enum PrefsFileState {
  /// Objet JSON lisible.
  valid,

  /// Fichier absent : premier lancement, ou réinitialisation voulue. Jamais
  /// « réparé » — ressusciter d'anciennes données malgré une suppression
  /// volontaire serait pire que ne rien faire.
  missing,

  /// Zéro octet, ou que des espaces.
  empty,

  /// Rempli d'octets nuls : la signature d'une coupure brutale pendant une
  /// écriture (le système a agrandi le fichier avant d'y mettre le contenu).
  zeroed,

  /// Du texte qui n'est pas un objet JSON.
  invalid,
}

/// Ce qu'a fait [PrefsFileGuard.restoreIfNeeded].
enum PrefsGuardAction {
  /// Rien à faire : le fichier est sain.
  none,

  /// Fichier absent : laissé tel quel.
  leftMissing,

  /// Fichier corrompu remplacé par une copie de secours saine.
  restored,

  /// Fichier corrompu, aucune copie saine : écarté pour que l'application
  /// démarre sur des réglages par défaut plutôt que de trébucher dessus.
  setAside,
}

class PrefsGuardReport {
  const PrefsGuardReport(this.action, this.state, {this.restoredFrom, this.keys});

  final PrefsGuardAction action;

  /// État du fichier AVANT intervention.
  final PrefsFileState state;

  /// Nom du fichier de secours utilisé, le cas échéant.
  final String? restoredFrom;

  /// Nombre de clés récupérées.
  final int? keys;

  @override
  String toString() => 'PrefsGuard($action, avant : $state'
      '${restoredFrom == null ? '' : ', depuis $restoredFrom'}'
      '${keys == null ? '' : ', $keys clés'})';
}

/// Gardien du fichier de préférences des plateformes de bureau.
///
/// `shared_preferences` garde, sous Windows et Linux, **tout** dans un seul
/// fichier JSON qu'il réécrit en entier à chaque changement, sans écriture
/// atomique. Une coupure de courant ou un blocage du PC au mauvais moment
/// laisse un fichier de la bonne taille… rempli de zéros : réglages de
/// connexion, discussions de l'agent, macros — tout part d'un coup (arrivé le
/// 21 octobre 2026).
///
/// On ne peut pas rendre l'écriture du greffon atomique ; on peut s'assurer
/// qu'**une copie saine existe toujours** et qu'elle est remise en place au
/// démarrage suivant :
///
/// - [backupIfValid] copie le fichier sain, de façon atomique, vers `.bak`
///   (récente) et `.daily.bak` (la première de la journée) ;
/// - [restoreIfNeeded], avant que l'application ne lise quoi que ce soit,
///   remplace un fichier corrompu par la meilleure copie saine.
///
/// Perte maximale : ce qui a changé depuis la dernière copie (une minute, avec
/// la planification de [start]).
class PrefsFileGuard {
  PrefsFileGuard(
    this.directory, {
    this.fileName = 'shared_preferences.json',
    DateTime Function()? clock,
    this.keepCorruptCopies = 3,
  }) : _clock = clock ?? DateTime.now;

  final String directory;
  final String fileName;
  final int keepCorruptCopies;
  final DateTime Function() _clock;

  String get _base => '$directory${Platform.pathSeparator}$fileName';
  File get main => File(_base);
  File get backup => File('$_base.bak');
  File get dailyBackup => File('$_base.daily.bak');

  /// Classe le contenu d'un fichier de préférences.
  static PrefsFileState inspect(List<int> bytes) {
    if (bytes.isEmpty) return PrefsFileState.empty;
    if (bytes.every((b) => b == 0)) return PrefsFileState.zeroed;
    try {
      final text = utf8.decode(bytes);
      if (text.trim().isEmpty) return PrefsFileState.empty;
      return jsonDecode(text) is Map<String, dynamic>
          ? PrefsFileState.valid
          : PrefsFileState.invalid;
    } catch (_) {
      return PrefsFileState.invalid;
    }
  }

  /// Nombre de clés d'un contenu sain, `null` sinon.
  static int? _keyCount(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes));
      return j is Map ? j.length : null;
    } catch (_) {
      return null;
    }
  }

  Future<PrefsFileState> _stateOf(File f) async {
    if (!await f.exists()) return PrefsFileState.missing;
    return inspect(await f.readAsBytes());
  }

  /// À appeler AVANT la première lecture des préférences.
  Future<PrefsGuardReport> restoreIfNeeded() async {
    final state = await _stateOf(main);
    if (state == PrefsFileState.valid) {
      return PrefsGuardReport(PrefsGuardAction.none, state);
    }
    if (state == PrefsFileState.missing) {
      return PrefsGuardReport(PrefsGuardAction.leftMissing, state);
    }

    // Corrompu : on garde la preuve avant de toucher à quoi que ce soit.
    await _keepEvidence();

    for (final candidate in [backup, dailyBackup]) {
      if (!await candidate.exists()) continue;
      final bytes = await candidate.readAsBytes();
      if (inspect(bytes) != PrefsFileState.valid) continue;
      await _atomicWrite(main, bytes);
      return PrefsGuardReport(
        PrefsGuardAction.restored,
        state,
        restoredFrom: candidate.uri.pathSegments.last,
        keys: _keyCount(bytes),
      );
    }

    // Rien de sain : on écarte le fichier fautif (il a été copié en preuve).
    try {
      await main.delete();
    } catch (_) {/* verrouillé : le greffon fera avec */}
    return PrefsGuardReport(PrefsGuardAction.setAside, state);
  }

  /// Copie le fichier courant vers les sauvegardes, **s'il est sain et non
  /// vide**. Un fichier corrompu — ou `{}` — n'écrase jamais une bonne copie.
  /// Retourne vrai si une copie a été faite.
  Future<bool> backupIfValid() async {
    if (!await main.exists()) return false;
    final List<int> bytes;
    try {
      bytes = await main.readAsBytes();
    } catch (_) {
      return false; // verrouillé un instant : la minute suivante
    }
    if (inspect(bytes) != PrefsFileState.valid) return false;
    if ((_keyCount(bytes) ?? 0) == 0) return false;

    await _atomicWrite(backup, bytes);

    final now = _clock();
    var needDaily = !await dailyBackup.exists();
    if (!needDaily) {
      final last = (await dailyBackup.lastModified()).toLocal();
      needDaily = last.year != now.year || last.month != now.month || last.day != now.day;
    }
    if (needDaily) await _atomicWrite(dailyBackup, bytes);
    return true;
  }

  /// Écrit dans un fichier voisin puis renomme : à aucun moment la
  /// destination n'est à moitié écrite.
  Future<void> _atomicWrite(File target, List<int> bytes) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  }

  Future<void> _keepEvidence() async {
    try {
      final t = _clock();
      String two(int n) => n.toString().padLeft(2, '0');
      final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
          '${two(t.hour)}${two(t.minute)}${two(t.second)}';
      await main.copy('$_base.corrupt-$stamp');

      final dir = Directory(directory);
      final copies = await dir
          .list()
          .where((e) => e is File && e.path.contains('$fileName.corrupt-'))
          .map((e) => e as File)
          .toList();
      copies.sort((a, b) => b.path.compareTo(a.path));
      for (final old in copies.skip(keepCorruptCopies)) {
        await old.delete();
      }
    } catch (_) {/* la preuve est un plus, jamais un obstacle */}
  }

  /// Planifie la sauvegarde périodique. Retourne le minuteur (à annuler).
  Timer start({Duration every = const Duration(minutes: 1)}) =>
      Timer.periodic(every, (_) => backupIfValid());
}
