import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/emergency_intent.dart';
import '../../domain/models/backoffice_event.dart';
import '../../domain/models/cowork.dart';
import '../../domain/models/machine_state.dart';
import '../providers/ai_agent_provider.dart';
import '../providers/ai_agent_settings_provider.dart';
import '../providers/backoffice_provider.dart' show backofficeBusProvider;
import '../providers/di_providers.dart';
import '../providers/gcode_provider.dart';
import '../providers/machine_provider.dart';
import '../providers/simulation_provider.dart';
import '../providers/streaming_provider.dart';

export '../../domain/models/cowork.dart';

/// Chat synchronisé PC ↔ téléphone : **une seule session, deux vues**.
///
/// L'agent ne tourne qu'à UN endroit, le PC (il porte déjà Ollama et
/// reco3d). Le téléphone s'y relie par WebSocket sur le réseau de l'atelier,
/// voit le même fil en direct, envoie ses messages et ses photos, et répond
/// aux confirmations. Rien n'est dupliqué : pas deux agents qui divergent.
///
/// Depuis la v2, la session partage aussi l'ESPACE DE TRAVAIL (coworking) :
/// qui est là, l'état de la machine, l'avancement du programme, le simulateur
/// — et un invité peut piloter le simulateur du PC. Un invité resté en v1 ne
/// reçoit que le chat, comme avant.
///
/// Règles de sécurité (docs/ia/etude-sindit-multi-agents.md §10) :
/// - l'arrêt d'urgence ne DÉPEND jamais du lien : il part d'abord de
///   l'appareil lui-même, sur sa propre liaison à la machine. Le bouton STOP
///   d'un invité le demande EN PLUS au PC (second chemin, pour une tablette
///   sans liaison directe) ; un arrêt tapé dans le chat reste purement local ;
/// - un invité ne commande jamais un axe par le lien : il parle à l'agent
///   (dont les actions passent par la carte de confirmation) ou pilote le
///   simulateur, qui ne fait rien bouger ;
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

  /// Version du protocole. 1 = chat seul ; 2 = coworking (présence, espace de
  /// travail, simulateur, arrêt d'urgence relayé).
  static const int version = 2;
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
  const ChatRelayHostState({
    this.running = false,
    this.code,
    this.clients = 0,
    this.error,
    this.participants = const [],
    this.hostName = 'PC',
  });
  final bool running;
  final String? code;
  final int clients;
  final String? error;

  /// Les invités reliés (l'hôte n'y figure pas), dans l'ordre d'arrivée.
  final List<CoworkParticipant> participants;

  /// Nom sous lequel ce PC se présente aux invités.
  final String hostName;

  ChatRelayHostState _with({List<CoworkParticipant>? participants}) => ChatRelayHostState(
        running: running,
        code: code,
        clients: (participants ?? this.participants).length,
        error: error,
        participants: participants ?? this.participants,
        hostName: hostName,
      );
}

class _Guest {
  _Guest(this.socket, this.participant, this.address, {required this.cowork});
  final WebSocket socket;
  final CoworkParticipant participant;
  final String address;

  /// L'invité parle le protocole v2 (présence, espace de travail). Un
  /// téléphone resté en v1 ne reçoit que le chat, comme avant.
  final bool cowork;
}

/// Serveur du relais, dans l'application Windows. Démarré à la demande (il
/// ouvre un port sur le réseau local).
class ChatRelayHost extends StateNotifier<ChatRelayHostState> {
  ChatRelayHost(this._ref) : super(const ChatRelayHostState());

  final Ref _ref;
  HttpServer? _server;
  final _guests = <WebSocket, _Guest>{};
  final _subs = <ProviderSubscription<Object?>>[];
  Timer? _throttle;
  Timer? _workspaceThrottle;
  CoworkWorkspace? _lastWorkspace;
  int _guestCounter = 0;

  /// Trace pour le backoffice. Jamais fatal : le relais ne tombe pas parce
  /// que l'audit est indisponible.
  void _audit(String kind, String summary,
      {BackofficeSeverity severity = BackofficeSeverity.info,
      Map<String, dynamic> details = const {}}) {
    try {
      _ref.read(backofficeBusProvider.notifier).emit(
            source: BackofficeSource.relais,
            kind: kind,
            summary: summary,
            severity: severity,
            details: details,
            origin: BackofficeOrigin.relais,
          );
    } catch (_) {}
  }

  static String _localName() {
    try {
      final n = Platform.localHostname.trim();
      return n.isEmpty || n == 'localhost' ? 'PC' : n;
    } catch (_) {
      return 'PC';
    }
  }

  Future<void> start() async {
    if (state.running) return;
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, ChatRelayProtocol.port);
      _server = server;
      state = ChatRelayHostState(
          running: true, code: ChatRelayProtocol.newPairingCode(), hostName: _localName());
      server.listen(_onRequest, onError: (_) {});
      _subs
        ..add(_ref.listen<AiChatState>(aiAgentControllerProvider, (_, _) => _scheduleBroadcast()))
        // Espace de travail partagé : tout ce qui bouge sur le poste.
        ..add(_ref.listen<AsyncValue<MachineState>>(
            machineStateProvider, (_, _) => _scheduleWorkspace()))
        ..add(_ref.listen<bool>(streamingProvider, (_, _) => _scheduleWorkspace()))
        ..add(_ref.listen<SimulationState>(simulationProvider, (_, _) => _scheduleWorkspace()))
        ..add(_ref.listen<int>(
            gcodeProvider.select((g) => g.allLines.length), (_, _) => _scheduleWorkspace()));
      _audit('relais.demarre', 'Relais PC ↔ téléphone démarré (port ${ChatRelayProtocol.port})',
          severity: BackofficeSeverity.notice, details: {'port': ChatRelayProtocol.port});
    } catch (e) {
      state = ChatRelayHostState(error: 'Port ${ChatRelayProtocol.port} indisponible : $e');
      _audit('relais.erreur', 'Relais impossible à démarrer : port ${ChatRelayProtocol.port} indisponible',
          severity: BackofficeSeverity.warning, details: {'erreur': '$e'});
    }
  }

  Future<void> stop() async {
    _throttle?.cancel();
    _workspaceThrottle?.cancel();
    for (final s in _subs) {
      s.close();
    }
    _subs.clear();
    _lastWorkspace = null;
    final hadClients = _guests.length;
    for (final s in _guests.keys.toList()) {
      await s.close(WebSocketStatus.goingAway);
    }
    _guests.clear();
    final wasRunning = _server != null;
    await _server?.close(force: true);
    _server = null;
    if (mounted) state = const ChatRelayHostState();
    if (wasRunning) {
      _audit('relais.arrete', 'Relais arrêté ($hadClients appareil(s) débranché(s))',
          severity: BackofficeSeverity.notice, details: {'clients': hadClients});
    }
  }

  List<CoworkParticipant> get _participants => [for (final g in _guests.values) g.participant];

  /// L'état du poste, tel que les invités le verront.
  CoworkWorkspace _workspace() {
    MachineState? m;
    try {
      m = _ref.read(machineRepositoryProvider).currentState;
    } catch (_) {
      m = null;
    }
    final sim = _ref.read(simulationProvider);
    return CoworkWorkspace(
      status: (m?.status ?? MachineStatus.offline).name,
      wPos: m?.wPos ?? const [0, 0, 0, 0, 0],
      mPos: m?.mPos ?? const [0, 0, 0, 0, 0],
      feed: m?.feedrate ?? 0,
      spindle: m?.spindleSpeed ?? 0,
      alarm: m?.alarmCode,
      line: m?.activeLineIndex ?? 0,
      totalLines: _ref.read(gcodeProvider).allLines.length,
      streaming: _ref.read(streamingProvider),
      simStatus: sim.status.name,
      simProgress: sim.progressPct,
      simSpeed: sim.speedMultiplier,
      simDeviation: sim.liveDeviationMm,
      at: DateTime.now(),
    );
  }

  void _toCowork(Map<String, dynamic> message) {
    final payload = jsonEncode(message);
    for (final g in _guests.values) {
      if (g.cowork) g.socket.add(payload);
    }
  }

  void _broadcastPresence() {
    final host = CoworkParticipant(id: 'hote', name: state.hostName, kind: CoworkKind.host);
    _toCowork({
      'type': 'presence',
      'participants': [host.toJson(), for (final p in _participants) p.toJson()],
    });
  }

  Future<void> _onRequest(HttpRequest req) async {
    if (req.uri.path != ChatRelayProtocol.path || !WebSocketTransformer.isUpgradeRequest(req)) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final remote = req.connectionInfo?.remoteAddress.address ?? '?';
    final ws = await WebSocketTransformer.upgrade(req);
    ws.listen((raw) async {
      Map<String, dynamic> msg;
      try {
        msg = (jsonDecode(raw as String) as Map).cast<String, dynamic>();
      } catch (_) {
        _audit('relais.illisible', 'Message illisible reçu de $remote',
            severity: BackofficeSeverity.warning, details: {'adresse': remote});
        return;
      }
      final guest = _guests[ws];
      if (guest == null) {
        if (msg['type'] == 'hello' && msg['code'] == state.code) {
          final cowork = (msg['v'] as num? ?? 1) >= 2;
          final device = msg['device'];
          final id = 'invite-${++_guestCounter}';
          final declared = CoworkParticipant.fromJson(
              device is Map ? {...device, 'id': id} : {'id': id, 'name': 'Téléphone'});
          final participant = CoworkParticipant(
            id: id,
            name: declared?.name ?? 'Téléphone',
            kind: declared == null || declared.kind == CoworkKind.host
                ? CoworkKind.phone
                : declared.kind,
            since: DateTime.now(),
          );
          _guests[ws] = _Guest(ws, participant, remote, cowork: cowork);
          state = state._with(participants: _participants);
          if (cowork) {
            ws.add(jsonEncode({
              'type': 'welcome',
              'v': ChatRelayProtocol.version,
              'you': id,
              'host': state.hostName,
            }));
          }
          ws.add(jsonEncode(ChatRelayProtocol.snapshot(_ref.read(aiAgentControllerProvider))));
          if (cowork) {
            _lastWorkspace = _workspace();
            ws.add(jsonEncode({'type': 'workspace', ..._lastWorkspace!.toJson()}));
          }
          _broadcastPresence();
          _audit('relais.liaison',
              '${participant.name} relié depuis $remote (${_guests.length} appareil(s))',
              severity: BackofficeSeverity.notice,
              details: {
                'adresse': remote,
                'clients': _guests.length,
                'participant': participant.name,
                'genre': participant.kind,
                'coworking': cowork,
              });
        } else {
          _audit('relais.refus', 'Liaison REFUSÉE depuis $remote : code incorrect',
              severity: BackofficeSeverity.warning,
              details: {'adresse': remote, 'type': '${msg['type']}'});
          ws.add(jsonEncode({'type': 'refused', 'reason': 'Code de liaison incorrect.'}));
          await ws.close(WebSocketStatus.policyViolation);
        }
        return;
      }
      await _handle(msg, guest);
    }, onDone: () {
      final gone = _guests.remove(ws);
      if (mounted && state.running) {
        state = state._with(participants: _participants);
      }
      if (gone != null) {
        _broadcastPresence();
        _audit('relais.deconnexion',
            '${gone.participant.name} (${gone.address}) débranché (${_guests.length} restant(s))',
            severity: BackofficeSeverity.notice,
            details: {
              'adresse': gone.address,
              'clients': _guests.length,
              'participant': gone.participant.name,
            });
      }
    }, onError: (_) {});
  }

  Future<void> _handle(Map<String, dynamic> msg, _Guest guest) async {
    final ctl = _ref.read(aiAgentControllerProvider.notifier);
    final type = '${msg['type']}';
    final remote = guest.address;
    final who = guest.participant.name;
    switch (type) {
      case 'send':
        final text = '${msg['text'] ?? ''}';
        Uint8List? image;
        final b64 = msg['image'];
        var imageRefused = false;
        if (b64 is String && b64.isNotEmpty) {
          final bytes = base64Decode(b64);
          if (bytes.length <= ChatRelayProtocol.maxImageBytes) {
            image = bytes;
          } else {
            imageRefused = true;
          }
        }
        _audit('relais.message',
            'Message de $who : ${text.length} car.${image != null ? ', image ${image.length} o' : ''}'
            '${imageRefused ? ' (image refusée : trop lourde)' : ''}',
            severity: imageRefused ? BackofficeSeverity.warning : BackofficeSeverity.info,
            details: {
              'adresse': remote,
              'participant': who,
              'type': type,
              'longueur': text.length,
              'image_octets': ?image?.length,
              'image_refusee': imageRefused,
            });
        await ctl.sendUserMessage(text,
            imageBytes: image,
            imageMime: msg['mime'] as String?,
            origin: BackofficeOrigin.relais);
      case 'confirm':
        final pending = _ref.read(aiAgentControllerProvider).pendingConfirmation;
        _audit('relais.message',
            'Confirmation de $who${pending == null ? ' (rien en attente)' : ' : ${pending.toolName}'}',
            severity: BackofficeSeverity.notice,
            details: {'adresse': remote, 'participant': who, 'type': type, 'outil': ?pending?.toolName});
        await ctl.confirmPendingAction(origin: BackofficeOrigin.relais);
      case 'reject':
        final pending = _ref.read(aiAgentControllerProvider).pendingConfirmation;
        _audit('relais.message',
            'Refus de $who${pending == null ? ' (rien en attente)' : ' : ${pending.toolName}'}',
            severity: BackofficeSeverity.notice,
            details: {'adresse': remote, 'participant': who, 'type': type, 'outil': ?pending?.toolName});
        await ctl.rejectPendingAction(origin: BackofficeOrigin.relais);
      case 'sim':
        _handleSim(msg, guest);
      case 'estop':
        // Chemin de SECOURS, en plus de l'arrêt local de l'invité : une
        // tablette n'a pas forcément sa propre liaison à la carte, et le PC,
        // lui, l'a. L'arrêt ne DÉPEND jamais de ce lien (l'invité a déjà agi
        // de son côté) ; il en profite quand il existe.
        final sent = await _ref.read(streamingProvider.notifier).stopStream();
        _audit('relais.urgence',
            sent
                ? 'ARRÊT D\'URGENCE demandé par $who : transmis à la carte par le PC'
                : 'ARRÊT D\'URGENCE demandé par $who : NON TRANSMIS (PC hors liaison)',
            severity: BackofficeSeverity.critical,
            details: {'adresse': remote, 'participant': who, 'transmis': sent});
        guest.socket.add(jsonEncode({'type': 'estop_ack', 'sent': sent}));
      default:
        _audit('relais.illisible', 'Type de message inconnu « $type » depuis $remote',
            severity: BackofficeSeverity.warning, details: {'adresse': remote, 'type': type});
    }
  }

  /// Un invité pilote le SIMULATEUR du PC — et rien d'autre. Lecture, pause,
  /// vitesse, jumeau : aucune de ces actions ne fait bouger un axe.
  void _handleSim(Map<String, dynamic> msg, _Guest guest) {
    final sim = _ref.read(simulationProvider.notifier);
    final action = '${msg['action']}';
    final value = msg['value'];
    var known = true;
    switch (action) {
      case 'play':
        sim.play();
      case 'pause':
        sim.pause();
      case 'reset':
        sim.reset();
      case 'follow':
        sim.followMachine();
      case 'stop_follow':
        sim.stopFollowing();
      case 'seek':
        if (value is num && value.isFinite) sim.seekPercent(value.toDouble().clamp(0, 100));
      case 'speed':
        if (value is num && value.isFinite) sim.setSpeed(value.toDouble());
      default:
        known = false;
    }
    _audit(
        known ? 'relais.simulateur' : 'relais.illisible',
        known
            ? '${guest.participant.name} pilote le simulateur : $action${value is num ? ' $value' : ''}'
            : 'Commande de simulateur inconnue « $action » de ${guest.participant.name}',
        severity: known ? BackofficeSeverity.info : BackofficeSeverity.warning,
        details: {'participant': guest.participant.name, 'action': action, 'valeur': ?value is num ? value : null});
  }

  /// Au plus 10 instantanés par seconde : le texte en flux change très vite.
  void _scheduleBroadcast() {
    if (_guests.isEmpty || (_throttle?.isActive ?? false)) return;
    _throttle = Timer(const Duration(milliseconds: 100), () {
      final payload = jsonEncode(ChatRelayProtocol.snapshot(_ref.read(aiAgentControllerProvider)));
      for (final s in _guests.keys) {
        s.add(payload);
      }
    });
  }

  /// Au plus 4 espaces de travail par seconde — la cadence des rapports de la
  /// carte en mouvement — et seulement quand quelque chose a changé.
  void _scheduleWorkspace() {
    if (!_guests.values.any((g) => g.cowork)) return;
    if (_workspaceThrottle?.isActive ?? false) return;
    _workspaceThrottle = Timer(const Duration(milliseconds: 250), () {
      final w = _workspace();
      final last = _lastWorkspace;
      if (last != null && last.sameContentAs(w)) return;
      _lastWorkspace = w;
      _toCowork({'type': 'workspace', ...w.toJson()});
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

// ──────────────────────────── Client (invité) ───────────────────────────────

enum RemoteChatStatus { disconnected, connecting, connected, refused }

@immutable
class RemoteChatState {
  const RemoteChatState({
    this.status = RemoteChatStatus.disconnected,
    this.snapshot = const RemoteChatSnapshot(),
    this.host,
    this.error,
    this.participants = const [],
    this.workspace,
    this.selfId,
    this.hostName,
    this.estopRelayed,
  });
  final RemoteChatStatus status;
  final RemoteChatSnapshot snapshot;
  final String? host;
  final String? error;

  /// Tous les participants, hôte compris (vide face à un PC en v1).
  final List<CoworkParticipant> participants;

  /// L'espace de travail du PC, `null` tant qu'il n'a rien envoyé.
  final CoworkWorkspace? workspace;
  final String? selfId;
  final String? hostName;

  /// Réponse du PC au dernier arrêt d'urgence relayé : `true` transmis à la
  /// carte, `false` non transmis, `null` pas (encore) de réponse.
  final bool? estopRelayed;

  /// Le PC parle le protocole de coworking (présence, espace de travail).
  bool get cowork => selfId != null;

  RemoteChatState copyWith({
    RemoteChatStatus? status,
    RemoteChatSnapshot? snapshot,
    String? host,
    String? error,
    bool clearError = false,
    List<CoworkParticipant>? participants,
    CoworkWorkspace? workspace,
    String? selfId,
    String? hostName,
    bool? estopRelayed,
    bool clearEstop = false,
  }) =>
      RemoteChatState(
        status: status ?? this.status,
        snapshot: snapshot ?? this.snapshot,
        host: host ?? this.host,
        error: clearError ? null : (error ?? this.error),
        participants: participants ?? this.participants,
        workspace: workspace ?? this.workspace,
        selfId: selfId ?? this.selfId,
        hostName: hostName ?? this.hostName,
        estopRelayed: clearEstop ? null : (estopRelayed ?? this.estopRelayed),
      );
}

class RemoteChatClient extends StateNotifier<RemoteChatState> {
  RemoteChatClient(this._ref) : super(const RemoteChatState());

  final Ref _ref;
  WebSocket? _ws;

  void _audit(String kind, String summary,
      {BackofficeSeverity severity = BackofficeSeverity.info,
      Map<String, dynamic> details = const {}}) {
    try {
      _ref.read(backofficeBusProvider.notifier).emit(
            source: BackofficeSource.relais,
            kind: kind,
            summary: summary,
            severity: severity,
            details: details,
            origin: BackofficeOrigin.local,
          );
    } catch (_) {}
  }

  /// Adresse du PC par défaut : celle du serveur Ollama réglé dans l'agent,
  /// puisque c'est le même poste.
  String defaultHost() {
    final url = _ref.read(aiAgentSettingsProvider).localBaseUrl;
    final host = Uri.tryParse(url)?.host ?? '';
    return host == 'localhost' || host == '127.0.0.1' ? '' : host;
  }

  /// Se relie au PC. [name] et [kind] disent aux autres qui vient d'arriver
  /// (voir [CoworkKind]) ; sans eux, l'appareil s'annonce comme un téléphone.
  Future<void> connect(String host, String code, {String? name, String? kind}) async {
    await disconnect();
    state = RemoteChatState(status: RemoteChatStatus.connecting, host: host);
    try {
      final ws = await WebSocket.connect(
              'ws://$host:${ChatRelayProtocol.port}${ChatRelayProtocol.path}')
          .timeout(const Duration(seconds: 5));
      _ws = ws;
      ws.add(jsonEncode({
        'type': 'hello',
        'code': code.trim(),
        'v': ChatRelayProtocol.version,
        'device': {
          'name': (name == null || name.trim().isEmpty) ? 'Téléphone' : name.trim(),
          'kind': kind ?? CoworkKind.phone,
        },
      }));
      ws.listen((raw) {
        Map<String, dynamic> j;
        try {
          j = (jsonDecode(raw as String) as Map).cast<String, dynamic>();
        } catch (_) {
          return; // trame illisible : ignorée, jamais fatale
        }
        _onMessage(j, host);
      }, onDone: () {
        // L'écran a pu être quitté avant que la socket ne se ferme.
        if (!mounted) return;
        if (state.status != RemoteChatStatus.refused) {
          if (state.status == RemoteChatStatus.connected) {
            _audit('relais.client.coupure', 'Liaison avec le PC $host coupée',
                severity: BackofficeSeverity.warning, details: {'hote': host});
          }
          state = state.copyWith(
              status: RemoteChatStatus.disconnected,
              error: 'Liaison avec le PC coupée.');
        }
      }, onError: (_) {});
    } catch (e) {
      _audit('relais.client.injoignable', 'PC injoignable sur $host:${ChatRelayProtocol.port}',
          severity: BackofficeSeverity.warning, details: {'hote': host, 'erreur': '$e'});
      state = state.copyWith(
          status: RemoteChatStatus.disconnected,
          error: 'PC injoignable sur $host:${ChatRelayProtocol.port}. '
              'Vérifie que la liaison est activée sur le PC (Coworking), '
              'et que les deux appareils sont sur le même réseau.');
    }
  }

  void _onMessage(Map<String, dynamic> j, String host) {
    if (!mounted) return;
    switch (j['type']) {
      case 'refused':
        state = state.copyWith(status: RemoteChatStatus.refused, error: '${j['reason']}');
        _audit('relais.client.refus', 'Liaison refusée par le PC $host : ${j['reason']}',
            severity: BackofficeSeverity.warning, details: {'hote': host});
      case 'welcome':
        state = state.copyWith(selfId: '${j['you']}', hostName: '${j['host'] ?? 'PC'}');
      case 'presence':
        state = state.copyWith(participants: [
          for (final p in (j['participants'] as List? ?? const []))
            ?CoworkParticipant.fromJson(p),
        ]);
      case 'workspace':
        final w = CoworkWorkspace.fromJson(j);
        if (w != null) state = state.copyWith(workspace: w);
      case 'estop_ack':
        state = state.copyWith(estopRelayed: j['sent'] == true);
      default:
        final snap = ChatRelayProtocol.parseSnapshot(j);
        if (snap != null) {
          if (state.status != RemoteChatStatus.connected) {
            _audit('relais.client.connexion', 'Relié au PC $host',
                severity: BackofficeSeverity.notice, details: {'hote': host});
          }
          state = state.copyWith(
              status: RemoteChatStatus.connected, snapshot: snap, clearError: true);
        }
    }
  }

  Future<void> disconnect() async {
    await _ws?.close();
    _ws = null;
    state = const RemoteChatState();
  }

  /// Envoie un message au PC. Un ordre d'arrêt d'urgence ne part PAS : il est
  /// exécuté ici, par l'agent du téléphone (chemin rapide, sans modèle), sur
  /// la liaison du téléphone à la machine. Rend `true` si c'était un arrêt.
  Future<bool> send(String text, {Uint8List? image, String? mime}) async {
    if (isEmergencyStopRequest(text)) {
      _audit('relais.client.urgence_locale',
          'Arrêt d\'urgence tapé sur le téléphone : exécuté ICI, pas envoyé au PC',
          severity: BackofficeSeverity.critical);
      await _ref.read(aiAgentControllerProvider.notifier).sendUserMessage(text);
      return true;
    }
    _audit('relais.client.envoi',
        'Envoyé au PC : ${text.length} car.${image != null ? ', image ${image.length} o' : ''}',
        details: {'longueur': text.length, 'image_octets': ?image?.length});
    _ws?.add(jsonEncode({
      'type': 'send',
      'text': text,
      if (image != null) 'image': base64Encode(image),
      'mime': ?mime,
    }));
    return false;
  }

  void confirm() {
    _audit('relais.client.envoi', 'Confirmation envoyée au PC',
        severity: BackofficeSeverity.notice, details: {'type': 'confirm'});
    _ws?.add(jsonEncode({'type': 'confirm'}));
  }

  void reject() {
    _audit('relais.client.envoi', 'Refus envoyé au PC',
        severity: BackofficeSeverity.notice, details: {'type': 'reject'});
    _ws?.add(jsonEncode({'type': 'reject'}));
  }

  /// Pilote le simulateur du PC (`play`, `pause`, `reset`, `follow`,
  /// `stop_follow`, `seek`, `speed`). Sans effet sur la machine.
  void sim(String action, [num? value]) {
    _ws?.add(jsonEncode({'type': 'sim', 'action': action, 'value': ?value}));
  }

  /// Arrêt d'urgence depuis l'invité : exécuté ICI d'abord (si cet appareil a
  /// sa propre liaison à la carte), PUIS demandé au PC en second chemin.
  /// Rend ce que le chemin local a donné ; la réponse du PC arrive dans
  /// [RemoteChatState.estopRelayed].
  Future<bool> stopEverywhere() async {
    state = state.copyWith(clearEstop: true);
    final local = await _ref.read(streamingProvider.notifier).stopStream();
    final relayed = _ws != null && state.status == RemoteChatStatus.connected;
    if (relayed) _ws!.add(jsonEncode({'type': 'estop'}));
    _audit(
        'relais.client.urgence',
        'Arrêt d\'urgence : local ${local ? 'transmis' : 'NON transmis'}'
        '${relayed ? ', demandé aussi au PC' : ', PC non relié'}',
        severity: BackofficeSeverity.critical,
        details: {'local': local, 'relaye': relayed});
    return local;
  }

  @override
  void dispose() {
    unawaited(_ws?.close());
    super.dispose();
  }
}

final remoteChatClientProvider =
    StateNotifierProvider<RemoteChatClient, RemoteChatState>((ref) => RemoteChatClient(ref));
