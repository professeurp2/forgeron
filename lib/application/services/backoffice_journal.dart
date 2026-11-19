import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../domain/models/backoffice_event.dart';

/// Journal persistant du backoffice : JSON-lignes, avec rotation.
///
/// Même contrat que `AiTurnJournal` : une écriture qui échoue (disque plein,
/// dossier verrouillé) n'a jamais le droit de gêner ce qu'elle observe. Le
/// backoffice regarde, il ne retient personne.
class BackofficeJournal {
  BackofficeJournal(
    this.directory, {
    this.fileName = 'backoffice.jsonl',
    this.maxBytes = 2 << 20,
    this.keep = 3,
  });

  final String directory;
  final String fileName;

  /// Taille à partir de laquelle on fait tourner les fichiers.
  final int maxBytes;

  /// Nombre de fichiers conservés (le courant + les anciens).
  final int keep;

  String get _path => '$directory${Platform.pathSeparator}$fileName';
  File get file => File(_path);

  /// Écritures en file : deux `append` concurrents sur Windows peuvent se
  /// chevaucher ; on les sérialise.
  Future<void> _chain = Future.value();

  Future<void> record(BackofficeEvent e) {
    final line = '${jsonEncode(e.toJson())}\n';
    return _chain = _chain.then((_) async {
      try {
        await _rotateIfNeeded();
        await file.writeAsString(line, mode: FileMode.append, flush: true);
      } catch (_) {
        /* jamais fatal */
      }
    });
  }

  Future<void> _rotateIfNeeded() async {
    if (!await file.exists() || await file.length() < maxBytes) return;
    for (var i = keep - 1; i >= 1; i--) {
      final from = File(i == 1 ? _path : '$_path.${i - 1}');
      final to = File('$_path.$i');
      if (await from.exists()) {
        if (await to.exists()) await to.delete();
        await from.rename(to.path);
      }
    }
  }

  /// Tous les événements conservés, du plus ancien au plus récent.
  Future<List<BackofficeEvent>> readAll() async {
    final out = <BackofficeEvent>[];
    for (var i = math.max(keep - 1, 0); i >= 0; i--) {
      final f = File(i == 0 ? _path : '$_path.$i');
      if (!await f.exists()) continue;
      List<String> lines;
      try {
        lines = await f.readAsLines();
      } catch (_) {
        continue;
      }
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final e = BackofficeEvent.fromJson(
            (jsonDecode(line) as Map).cast<String, dynamic>(),
          );
          if (e != null) out.add(e);
        } catch (_) {
          /* ligne illisible : ignorée */
        }
      }
    }
    return out;
  }

  /// Efface les fichiers du journal (demande explicite de l'opérateur).
  Future<void> wipe() async {
    await _chain;
    for (var i = 0; i < keep; i++) {
      final f = File(i == 0 ? _path : '$_path.$i');
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
