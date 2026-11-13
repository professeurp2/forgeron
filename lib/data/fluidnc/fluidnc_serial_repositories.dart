import 'dart:async';
import 'dart:convert';
import '../../domain/models/gcode_file.dart';
import '../../domain/repositories/config_repository.dart';
import '../../domain/repositories/file_repository.dart';
import 'fluidnc_connection.dart';

/// Envoie une commande console FluidNC sur le transport actif ([FluidNCConnection])
/// et collecte les lignes de réponse jusqu'à `ok` ou `error:...`.
Future<List<String>> _sendAndCollect(
  FluidNCConnection? conn,
  String command, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (conn == null || !conn.isConnected) {
    throw Exception('Liaison USB non connectée');
  }

  final lines = <String>[];
  final completer = Completer<List<String>>();
  late StreamSubscription<String> sub;

  sub = conn.messages.listen((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('<')) return;
    if (trimmed == 'ok') {
      if (!completer.isCompleted) completer.complete(lines);
      return;
    }
    if (trimmed.startsWith('error:')) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('FluidNC $trimmed'));
      }
      return;
    }
    lines.add(line);
  });

  if (!conn.sendGCode(command)) {
    await sub.cancel();
    throw Exception('Échec d\'envoi de la commande "$command" sur USB');
  }

  try {
    return await completer.future.timeout(
      timeout,
      onTimeout: () => lines,
    );
  } finally {
    await sub.cancel();
  }
}

/// Implémentation USB/Série de [FileRepository] utilisant les commandes console FluidNC
/// (`$LocalFS/List`, `$LocalFS/Show`, `$LocalFS/Delete`, etc.).
class FluidNCSerialFileRepository implements FileRepository {
  final FluidNCConnection? _connection;

  FluidNCSerialFileRepository(this._connection);

  @override
  Future<List<GCodeFile>> listFiles({String path = '/'}) async {
    if (_connection == null || !_connection.isConnected) {
      return const [];
    }
    try {
      final lines = await _sendAndCollect(_connection, '\$LocalFS/List');
      final files = <GCodeFile>[];
      final re = RegExp(r'\[FILE:\s*([^|]+)\|SIZE:\s*(\d+)\]');
      for (final line in lines) {
        final m = re.firstMatch(line);
        if (m != null) {
          final name = m.group(1)!.trim();
          final size = int.tryParse(m.group(2) ?? '0') ?? 0;
          if (name.isNotEmpty) {
            files.add(GCodeFile(name: name, size: size));
          }
        }
      }
      return files;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String> readFile(String path) async {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final lines = await _sendAndCollect(
      _connection,
      '\$LocalFS/Show=$clean',
      timeout: const Duration(seconds: 10),
    );
    return lines.join('\n');
  }

  @override
  Future<void> uploadFile(String path, List<int> bytes) async {
    // En mode USB, le streaming G-code direct depuis le PC (GCodeStreamingService)
    // est utilisé pour l'usinage ; l'upload fichier HTTP n'est pas disponible sur UART.
    final _ = utf8.decode(bytes, allowMalformed: true);
    throw UnsupportedError(
      'Upload vers la flash ESP32 indisponible sur UART : utilisez le streaming direct USB ou le mode Wi-Fi.',
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    await _sendAndCollect(_connection, '\$LocalFS/Delete=$clean');
  }
}

/// Implémentation USB/Série de [ConfigRepository] via `$Config/Dump`.
class FluidNCSerialConfigRepository implements ConfigRepository {
  final FluidNCConnection? _connection;

  FluidNCSerialConfigRepository(this._connection);

  @override
  Future<String> getConfig() async {
    if (_connection == null || !_connection.isConnected) {
      return '# Impossible de charger config.yaml : liaison USB non connectée.';
    }
    try {
      final lines = await _sendAndCollect(
        _connection,
        '\$Config/Dump',
        timeout: const Duration(seconds: 6),
      );
      if (lines.isEmpty) {
        return '# Impossible de charger config.yaml depuis le port USB.';
      }
      return lines.join('\n');
    } catch (e) {
      return '# Impossible de charger config.yaml sur USB : $e';
    }
  }

  @override
  Future<void> saveConfig(String yaml) async {
    throw UnsupportedError(
      'L\'écriture complète de config.yaml nécessite la WebUI HTTP (mode Wi-Fi) ou la carte SD.',
    );
  }

  @override
  Future<void> backupConfig() async {
    await _sendAndCollect(_connection, '\$Config/Backup');
  }

  @override
  Future<void> restoreConfig() async {
    throw UnsupportedError(
      'La restauration de config.yaml nécessite la WebUI HTTP (mode Wi-Fi).',
    );
  }
}

