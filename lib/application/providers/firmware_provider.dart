import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'di_providers.dart';

/// Identité du firmware, extraite de la réponse GRBL/FluidNC à `$I`.
class FirmwareInfo {
  /// Chaîne complète du `[VER:…]`, ex : « 3.7 FluidNC v3.7.8 ».
  final String? version;

  /// Version GRBL protocolaire (premier token), ex : « 3.7 ».
  final String? grblVersion;

  /// Options de compilation `[OPT:…]`.
  final String? options;

  /// Carte / build, si rapporté dans un `[MSG:INFO:…]` au démarrage.
  final String? board;

  const FirmwareInfo({
    this.version,
    this.grblVersion,
    this.options,
    this.board,
  });

  bool get isKnown => version != null || board != null;

  FirmwareInfo copyWith({
    String? version,
    String? grblVersion,
    String? options,
    String? board,
  }) =>
      FirmwareInfo(
        version: version ?? this.version,
        grblVersion: grblVersion ?? this.grblVersion,
        options: options ?? this.options,
        board: board ?? this.board,
      );
}

/// Écoute les messages machine, réclame `$I` et en extrait l'identité firmware.
class FirmwareNotifier extends StateNotifier<FirmwareInfo> {
  final Ref _ref;
  StreamSubscription<String>? _sub;

  FirmwareNotifier(this._ref) : super(const FirmwareInfo()) {
    final repo = _ref.read(machineRepositoryProvider);
    _sub = repo.messageStream.listen(_parse);
    // Réclame l'identité dès la création (à l'ouverture de l'écran Diag).
    requestInfo();
  }

  /// (Re)demande le build-info à la machine.
  void requestInfo() {
    _ref.read(machineRepositoryProvider).sendRaw('\$I\n');
  }

  void _parse(String raw) {
    final m = raw.trim();
    if (m.startsWith('[VER:')) {
      // [VER:3.7 FluidNC v3.7.8:]  →  contenu = "3.7 FluidNC v3.7.8"
      var content = m.substring(5);
      if (content.endsWith(':]')) {
        content = content.substring(0, content.length - 2);
      } else if (content.endsWith(']')) {
        content = content.substring(0, content.length - 1);
      }
      content = content.trim();
      final grbl = content.isNotEmpty ? content.split(' ').first : null;
      state = state.copyWith(version: content, grblVersion: grbl);
    } else if (m.startsWith('[OPT:')) {
      state = state.copyWith(
          options: m.substring(5, m.length - 1).replaceAll(':]', ''));
    } else if (m.startsWith('[MSG:INFO:') && m.contains('FluidNC')) {
      // ex : [MSG:INFO: FluidNC v3.7.8]
      state = state.copyWith(
          board: m.substring(10, m.length - 1).trim());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final firmwareInfoProvider =
    StateNotifierProvider<FirmwareNotifier, FirmwareInfo>(
        (ref) => FirmwareNotifier(ref));
