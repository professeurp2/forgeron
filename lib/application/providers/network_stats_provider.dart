import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/machine_state.dart';
import 'di_providers.dart';

/// Statistiques réseau réelles de la liaison ESP32/FluidNC.
class NetworkStats {
  final bool connected;
  final int txCount; // trames envoyées
  final int rxCount; // trames reçues
  final int latencyMs; // RTT du heartbeat (? → <…>)
  final Duration uptime; // temps depuis la connexion

  const NetworkStats({
    this.connected = false,
    this.txCount = 0,
    this.rxCount = 0,
    this.latencyMs = 0,
    this.uptime = Duration.zero,
  });

  /// Qualité dérivée de la latence (100 % si < ~10 ms, dégradée ensuite).
  int get qualityPct {
    if (!connected) return 0;
    if (latencyMs <= 0) return 100;
    return (100 - latencyMs.clamp(0, 200) / 2).round().clamp(0, 100);
  }

  NetworkStats copyWith({
    bool? connected,
    int? txCount,
    int? rxCount,
    int? latencyMs,
    Duration? uptime,
  }) =>
      NetworkStats(
        connected: connected ?? this.connected,
        txCount: txCount ?? this.txCount,
        rxCount: rxCount ?? this.rxCount,
        latencyMs: latencyMs ?? this.latencyMs,
        uptime: uptime ?? this.uptime,
      );
}

class NetworkStatsNotifier extends StateNotifier<NetworkStats> {
  final Ref _ref;
  StreamSubscription<String>? _trafficSub;
  StreamSubscription<MachineState>? _stateSub;
  Timer? _tick;
  DateTime? _connectTime;
  DateTime? _lastPingSent;

  NetworkStatsNotifier(this._ref) : super(const NetworkStats()) {
    final repo = _ref.read(machineRepositoryProvider);
    _trafficSub = repo.trafficStream.listen(_onTraffic);
    _stateSub = repo.stateStream.listen(_onState);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _emitUptime());
  }

  void _onTraffic(String msg) {
    if (msg.startsWith('TX:')) {
      // Heartbeat '?' → on démarre le chrono de latence.
      if (msg.contains('?')) _lastPingSent = DateTime.now();
      state = state.copyWith(txCount: state.txCount + 1);
    } else if (msg.startsWith('RX:')) {
      // Réponse de statut '<…>' → on ferme le chrono.
      final isStatus = msg.contains('<');
      int? latency;
      if (isStatus && _lastPingSent != null) {
        latency = DateTime.now().difference(_lastPingSent!).inMilliseconds;
        _lastPingSent = null;
      }
      state = state.copyWith(
          rxCount: state.rxCount + 1,
          latencyMs: latency ?? state.latencyMs);
    }
  }

  void _onState(MachineState s) {
    final online = s.status != MachineStatus.offline;
    if (online && _connectTime == null) {
      _connectTime = DateTime.now();
    } else if (!online) {
      _connectTime = null;
    }
    if (online != state.connected) {
      state = state.copyWith(connected: online);
    }
  }

  void _emitUptime() {
    if (_connectTime == null) {
      if (state.uptime != Duration.zero) {
        state = state.copyWith(uptime: Duration.zero);
      }
      return;
    }
    state = state.copyWith(uptime: DateTime.now().difference(_connectTime!));
  }

  @override
  void dispose() {
    _trafficSub?.cancel();
    _stateSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }
}

final networkStatsProvider =
    StateNotifierProvider<NetworkStatsNotifier, NetworkStats>(
        (ref) => NetworkStatsNotifier(ref));

/// Formate une durée en `HHh MMm` / `MMm SSs`.
String formatUptime(Duration d) {
  if (d == Duration.zero) return '—';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}
