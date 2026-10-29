import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/emergency_intent.dart';
import '../providers/ai_agent_provider.dart';
import '../providers/ai_agent_settings_provider.dart';

/// Chat synchronisé PC ↔ téléphone : **une seule session, deux vues**.
///
/// L'agent ne tourne qu'à UN endroit, le PC (il porte déjà Ollama et
/// reco3d). Le téléphone s'y relie par WebSocket sur le réseau de l'atelier,
/// voit le même fil en direct, envoie ses messages et ses photos, et répond
/// aux confirmations. Rien n'est dupliqué : pas deux agents qui divergent.
///
/// Règles de sécurité (docs/ia/etude-sindit-multi-agents.md §10) :
/// - l'arrêt d'urgence ne passe JAMAIS par le lien : tapé sur le téléphone, il
///   part de l'agent du téléphone, sur sa propre liaison à la machine ;
/// - la liaison exige le code à 6 chiffres affiché sur le PC : n'importe quel
///   appareil du réseau ne doit pas pouvoir confirmer un mouvement ;
/// - une confirmation est la même action des deux côtés : la première réponse
///   gagne, l'autre carte disparaît au rafraîchissement suivant ;
/// - lien coupé : rien n'est exécuté à la place de personne, l'action reste
///   en attente sur le PC.
class ChatRelayProtocol {
  const ChatRelayProtocol._();

  /// Port du relais, à côté de reco3d (8765 HTTP, 8766 UDP).
  static const int port = 8767;
  static const String path = '/chat';

  /// Photo transmise du téléphone : au-delà, refusée (une photo de téléphone
  /// compressée par l'écran de chat tient largement dessous).
  static const int maxImageBytes = 6 * 1024 * 1024;

  /// Instantané du chat envoyé aux appareils reliés.
  static Map<String, dynamic> snapshot(AiChatState s) => {
        'type': 'snapshot',
        'messages': [
          for (final m in s.messages)
            {...m.toJson(), if (m.isRunningTool) 'running': true},
        ],
        'processing': s.isProcessing,
        'streaming': ?s.streamingText,
        'error': ?s.error,
        'specialists': s.specialists,
        if (s.pendingConfirmation != null)
          'pending': {
            'tool': s.pendingConfirmation!.toolName,
            'input': s.pendingConfirmation!.input,
          },
      };

  static RemoteChatSnapshot? parseSnapshot(Map<String, dynamic> j) {
    if (j['type'] != 'snapshot') return null;
    final pending = (j['pending'] as Map?)?.cast<String, dynamic>();
    return RemoteChatSnapshot(
      messages: [
        for (final m in (j['messages'] as List? ?? const []).whereType<Map>())
          _message(m.cast<String, dynamic>()),
      ],
      processing: j['processing'] == true,
      streaming: j['streaming'] as String?,
      error: j['error'] as String?,
      specialists: [
        for (final s in (j['specialists'] as List? ?? const [])) '$s',
      ],
      pendingTool: pending?['tool'] as String?,
      pendingInput:
          (pending?['input'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Une étape d'outil encore en cours sur le PC reste « en cours » : relue
  /// par [AiChatMessage.fromJson], elle passerait pour interrompue (règle
  /// prévue pour une discussion rechargée après fermeture de l'app).
  static AiChatMessage _message(Map<String, dynamic> j) {
    final m = AiChatMessage.fromJson(j);
    if (j['running'] != true) return m;
    return AiChatMessage(
      role: 'tool',
      text: m.text,
      timestamp: m.timestamp,
      toolName: m.toolName,
      toolArgs: m.toolArgs,
    );
  }

  /// Code de liaison : 6 chiffres, tirés au hasard à chaque démarrage.
  static String newPairingCode([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }
}

/// Ce que le téléphone affiche du chat du PC.
@immutable
class RemoteChatSnapshot {
  const RemoteChatSnapshot({
    this.messages = const [],
    this.processing = false,
    this.streaming,
    this.error,
    this.specialists = const [],
    this.pendingTool,
    this.pendingInput = const {},
  });

  final List<AiChatMessage> messages;
  final bool processing;
  final String? streaming;
  final String? error;
  final List<String> specialists;
  final String? pendingTool;
  final Map<String, dynamic> pendingInput;
}

// ───────────────────────────── Hôte (PC) ────────────────────────────────────

/// État du relais côté PC.
@immutable
class ChatRelayHostState {
  const ChatRelayHostState({this.running = false, this.code, this.clients = 0, this.error});
  final bool running;
  final String? code;
  final int clients;
  final String? error;
}

/// Serveur du relais, dans l'application Windows. Démarré à la demande depuis
/// la console IA (il ouvre un port sur le réseau local).
class ChatRelayHost extends StateNotifier<ChatRelayHostState> {
  ChatRelayHost(this._ref) : super(const ChatRelayHostState());

  final Ref _ref;
  HttpServer? _server;
  final _sockets = <WebSocket>{};
  ProviderSubscription<AiChatState>? _sub;
  Timer? _throttle;

  Future<void> start() async {
    if (state.running) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, ChatRelayProtocol.port);
      _server = server;
      state = ChatRelayHostState(running: true, code: ChatRelayProtocol.newPairingCode());
      server.listen(_onRequest, onError: (_) {});
      _sub = _ref.listen<AiChatState>(aiAgentControllerProvider, (_, _) => _scheduleBroadcast());
    } catch (e) {
      state = ChatRelayHostState(error: 'Port ${ChatRelayProtocol.port} indisponible : $e');
    }
  }

  Future<void> stop() async {
    _throttle?.cancel();
    _sub?.close();
    _sub = null;
    for (final s in _sockets.toList()) {
      await s.close(WebSocketStatus.goingAway);
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
    if (mounted) state = const ChatRelayHostState();
  }

  Future<void> _onRequest(HttpRequest req) async {
    if (req.uri.path != ChatRelayProtocol.path || !WebSocketTransformer.isUpgradeRequest(req)) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    var paired = false;
    ws.listen((raw) async {
      Map<String, dynamic> msg;
      try {
        msg = (jsonDecode(raw as String) as Map).cast<String, dynamic>();
      } catch (_) {
        return;
      }
      if (!paired) {
        if (msg['type'] == 'hello' && msg['code'] == state.code) {
          paired = true;
          _sockets.add(ws);
          state = ChatRelayHostState(running: true, code: state.code, clients: _sockets.length);
          ws.add(jsonEncode(ChatRelayProtocol.snapshot(_ref.read(aiAgentControllerProvider))));
        } else {
          ws.add(jsonEncode({'type': 'refused', 'reason': 'Code de liaison incorrect.'}));
          await ws.close(WebSocketStatus.policyViolation);
        }
        return;
      }
      await _handle(msg);
    }, onDone: () {
      _sockets.remove(ws);
      if (mounted && state.running) {
        state = ChatRelayHostState(running: true, code: state.code, clients: _sockets.length);
      }
    }, onError: (_) {});
  }

  Future<void> _handle(Map<String, dynamic> msg) async {
    final ctl = _ref.read(aiAgentControllerProvider.notifier);
    switch (msg['type']) {
      case 'send':
        final text = '${msg['text'] ?? ''}';
        Uint8List? image;
        final b64 = msg['image'];
        if (b64 is String && b64.isNotEmpty) {
          final bytes = base64Decode(b64);
          if (bytes.length <= ChatRelayProtocol.maxImageBytes) image = bytes;
        }
        await ctl.sendUserMessage(text,
            imageBytes: image, imageMime: msg['mime'] as String?);
      case 'confirm':
        await ctl.confirmPendingAction();
      case 'reject':
        await ctl.rejectPendingAction();
    }
  }

  /// Au plus 10 instantanés par seconde : le texte en flux change très vite.
  void _scheduleBroadcast() {
    if (_sockets.isEmpty || (_throttle?.isActive ?? false)) return;
    _throttle = Timer(const Duration(milliseconds: 100), () {
      final payload = jsonEncode(ChatRelayProtocol.snapshot(_ref.read(aiAgentControllerProvider)));
      for (final s in _sockets) {
        s.add(payload);
      }
    });
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}

final chatRelayHostProvider =
    StateNotifierProvider<ChatRelayHost, ChatRelayHostState>((ref) => ChatRelayHost(ref));

// ──────────────────────────── Client (téléphone) ────────────────────────────

enum RemoteChatStatus { disconnected, connecting, connected, refused }

@immutable
class RemoteChatState {
  const RemoteChatState({
    this.status = RemoteChatStatus.disconnected,
    this.snapshot = const RemoteChatSnapshot(),
    this.host,
    this.error,
  });
  final RemoteChatStatus status;
  final RemoteChatSnapshot snapshot;
  final String? host;
  final String? error;

  RemoteChatState copyWith({
    RemoteChatStatus? status,
    RemoteChatSnapshot? snapshot,
    String? host,
    String? error,
    bool clearError = false,
  }) =>
      RemoteChatState(
        status: status ?? this.status,
        snapshot: snapshot ?? this.snapshot,
        host: host ?? this.host,
        error: clearError ? null : (error ?? this.error),
      );
}

class RemoteChatClient extends StateNotifier<RemoteChatState> {
  RemoteChatClient(this._ref) : super(const RemoteChatState());

  final Ref _ref;
  WebSocket? _ws;

  /// Adresse du PC par défaut : celle du serveur Ollama réglé dans l'agent,
  /// puisque c'est le même poste.
  String defaultHost() {
    final url = _ref.read(aiAgentSettingsProvider).localBaseUrl;
    final host = Uri.tryParse(url)?.host ?? '';
    return host == 'localhost' || host == '127.0.0.1' ? '' : host;
  }

  Future<void> connect(String host, String code) async {
    await disconnect();
    state = RemoteChatState(status: RemoteChatStatus.connecting, host: host);
    try {
      final ws = await WebSocket.connect(
              'ws://$host:${ChatRelayProtocol.port}${ChatRelayProtocol.path}')
          .timeout(const Duration(seconds: 5));
      _ws = ws;
      ws.add(jsonEncode({'type': 'hello', 'code': code.trim()}));
      ws.listen((raw) {
        final j = (jsonDecode(raw as String) as Map).cast<String, dynamic>();
        if (j['type'] == 'refused') {
          state = state.copyWith(status: RemoteChatStatus.refused, error: '${j['reason']}');
          return;
        }
        final snap = ChatRelayProtocol.parseSnapshot(j);
        if (snap != null) {
          state = state.copyWith(status: RemoteChatStatus.connected, snapshot: snap, clearError: true);
        }
      }, onDone: () {
        if (state.status != RemoteChatStatus.refused) {
          state = state.copyWith(
              status: RemoteChatStatus.disconnected,
              error: 'Liaison avec le PC coupée.');
        }
      }, onError: (_) {});
    } catch (e) {
      state = state.copyWith(
          status: RemoteChatStatus.disconnected,
          error: 'PC injoignable sur $host:${ChatRelayProtocol.port}. '
              'Vérifie que la liaison est activée dans la console IA du PC, '
              'et que les deux appareils sont sur le même réseau.');
    }
  }

  Future<void> disconnect() async {
    await _ws?.close();
    _ws = null;
    state = state.copyWith(status: RemoteChatStatus.disconnected, clearError: true);
  }

  /// Envoie un message au PC. Un ordre d'arrêt d'urgence ne part PAS : il est
  /// exécuté ici, par l'agent du téléphone (chemin rapide, sans modèle), sur
  /// la liaison du téléphone à la machine. Rend `true` si c'était un arrêt.
  Future<bool> send(String text, {Uint8List? image, String? mime}) async {
    if (isEmergencyStopRequest(text)) {
      await _ref.read(aiAgentControllerProvider.notifier).sendUserMessage(text);
      return true;
    }
    _ws?.add(jsonEncode({
      'type': 'send',
      'text': text,
      if (image != null) 'image': base64Encode(image),
      'mime': ?mime,
    }));
    return false;
  }

  void confirm() => _ws?.add(jsonEncode({'type': 'confirm'}));
  void reject() => _ws?.add(jsonEncode({'type': 'reject'}));

  @override
  void dispose() {
    unawaited(_ws?.close());
    super.dispose();
  }
}

final remoteChatClientProvider =
    StateNotifierProvider<RemoteChatClient, RemoteChatState>((ref) => RemoteChatClient(ref));
