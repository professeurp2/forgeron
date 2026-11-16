import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/providers/backoffice_provider.dart';
import '../../application/providers/machine_provider.dart';
import '../../application/providers/simulation_provider.dart';
import '../../application/providers/stream_progress_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../application/services/chat_relay.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/utils/clipboard_image_helper.dart';
import '../../domain/models/machine_state.dart';

enum _CoworkingMode { host, join }

/// Écran dédié au **Coworking** (relais PC ↔ tablette/téléphone).
///
/// Deux modes :
///  - **Héberger (ce poste)** : ouvre/ferme le serveur relais sur le port 8767,
///    affiche le code à 6 chiffres et les IP locales du PC, la liste des
///    participants et l'activité de la session.
///  - **Rejoindre un PC** : vue synchronisée de la machine du PC (X/Y/Z/A/C,
///    avance, broche, avancement du programme, simulateur/jumeau) et chat IA
///    partagé en temps réel avec confirmations et arrêt d'urgence local.
class CoworkingScreen extends ConsumerStatefulWidget {
  const CoworkingScreen({super.key});

  @override
  ConsumerState<CoworkingScreen> createState() => _CoworkingScreenState();
}

class _CoworkingScreenState extends ConsumerState<CoworkingScreen> {
  _CoworkingMode _mode = _CoworkingMode.host;
  final _hostCtrl = TextEditingController(text: '192.168.137.1');
  final _codeCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  List<String> _localIps = const [];
  Uint8List? _pendingImage;
  String? _pendingImageMime;

  @override
  void initState() {
    super.initState();
    _loadLocalIps();
    final remote = ref.read(remoteChatClientProvider);
    if (remote.host != null && remote.host!.isNotEmpty) {
      _hostCtrl.text = remote.host!;
    } else {
      final def = ref.read(remoteChatClientProvider.notifier).defaultHost();
      if (def.isNotEmpty) _hostCtrl.text = def;
    }
    if (remote.status == RemoteChatStatus.connected) {
      _mode = _CoworkingMode.join;
    }
  }

  Future<void> _loadLocalIps() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final ips = <String>[];
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!ips.contains(addr.address)) ips.add(addr.address);
        }
      }
      ips.sort((a, b) {
        // Mettre 192.168.137.1 (hotspot Windows) en premier.
        if (a == '192.168.137.1') return -1;
        if (b == '192.168.137.1') return 1;
        return a.compareTo(b);
      });
      if (mounted) setState(() => _localIps = ips);
    } catch (_) {}
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _codeCtrl.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
          source: source, imageQuality: 75, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > ChatRelayProtocol.maxImageBytes) return;
      setState(() {
        _pendingImage = bytes;
        _pendingImageMime =
            file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      });
    } catch (_) {}
  }

  Future<void> _pasteImage() async {
    final res = await readClipboardImage();
    if (res == null || !mounted) return;
    if (res.bytes.length > ChatRelayProtocol.maxImageBytes) return;
    setState(() {
      _pendingImage = res.bytes;
      _pendingImageMime = res.mimeType;
    });
  }

  Future<void> _sendRemoteMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    final wasEstop = await ref
        .read(remoteChatClientProvider.notifier)
        .send(text, image: _pendingImage, mime: _pendingImageMime);
    _chatCtrl.clear();
    setState(() {
      _pendingImage = null;
      _pendingImageMime = null;
    });
    if (wasEstop && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Arrêt d\'urgence exécuté localement.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;

    return Container(
      color: fc.background,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildModeSwitcher(fc),
          const SizedBox(height: 16),
          Expanded(
            child: _mode == _CoworkingMode.host
                ? _buildHostView(fc)
                : _buildJoinView(fc),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher(ForgeronColorPalette fc) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchTab(
              icon: Icons.computer_rounded,
              label: tr('Héberger (ce poste)'),
              selected: _mode == _CoworkingMode.host,
              fc: fc,
              onTap: () => setState(() => _mode = _CoworkingMode.host),
            ),
          ),
          Expanded(
            child: _SwitchTab(
              icon: Icons.smartphone_rounded,
              label: tr('Rejoindre un PC'),
              selected: _mode == _CoworkingMode.join,
              fc: fc,
              onTap: () => setState(() => _mode = _CoworkingMode.join),
            ),
          ),
        ],
      ),
    );
  }

  // ── MODE HÔTE (CE POSTE) ──────────────────────────────────────────────────

  Widget _buildHostView(ForgeronColorPalette fc) {
    final hostState = ref.watch(chatRelayHostProvider);
    final host = ref.read(chatRelayHostProvider.notifier);
    final events = ref
        .watch(backofficeBusProvider)
        .where((e) => e.source == BackofficeSource.relais)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        final left = Column(
          children: [
            _buildSessionCard(fc, hostState, host),
            const SizedBox(height: 14),
            _buildPermissionsCard(fc),
          ],
        );
        final right = Column(
          children: [
            _buildParticipantsCard(fc, hostState),
            const SizedBox(height: 14),
            Expanded(child: _buildActivityCard(fc, events)),
          ],
        );

        if (!wide) {
          return ListView(
            children: [
              left,
              const SizedBox(height: 14),
              _buildParticipantsCard(fc, hostState),
              const SizedBox(height: 14),
              SizedBox(height: 280, child: _buildActivityCard(fc, events)),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 340, child: SingleChildScrollView(child: left)),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(
    ForgeronColorPalette fc,
    ChatRelayHostState hostState,
    ChatRelayHost host,
  ) {
    final open = hostState.running;
    return _PanelCard(
      fc: fc,
      icon: Icons.hub_outlined,
      title: 'SESSION',
      trailing: _StatusBadge(
        label: open ? 'OUVERTE' : 'FERMÉE',
        color: open ? fc.success : fc.textDisabled,
        fc: fc,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Ouvre la session pour qu\'une tablette ou un téléphone du même réseau rejoigne ce poste. Un code à 6 chiffres protège la liaison.'),
            style: TextStyle(color: fc.textSecondary, fontSize: 12.5, height: 1.4),
          ),
          if (open) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: fc.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fc.primary.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CODE DE LIAISON',
                      style: TextStyle(
                          color: fc.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  SelectableText(
                    hostState.code ?? '------',
                    style: TextStyle(
                      color: fc.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  if (_localIps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'IP : ${_localIps.join('  ·  ')}  (port ${ChatRelayProtocol.port})',
                      style: TextStyle(
                        color: fc.textSecondary,
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (hostState.error != null) ...[
            const SizedBox(height: 10),
            Text(hostState.error!,
                style: TextStyle(color: fc.danger, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: open ? host.stop : host.start,
              icon: Icon(
                  open ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 18),
              label: Text(
                open ? tr('Fermer la session') : tr('Ouvrir la session'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: open ? fc.danger : fc.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(ForgeronColorPalette fc) {
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: fc.textPrimary, fontSize: 12.5, height: 1.3)),
              ),
            ],
          ),
        );

    return _PanelCard(
      fc: fc,
      icon: Icons.verified_user_outlined,
      title: 'CE QU\'UN INVITÉ PEUT FAIRE',
      child: Column(
        children: [
          row(Icons.visibility_outlined, fc.success,
              'Voir l\'état de la machine et l\'avancement, en direct'),
          row(Icons.chat_bubble_outline, fc.success,
              'Parler au même agent IA et confirmer ses actions'),
          row(Icons.track_changes_outlined, fc.success,
              'Piloter le simulateur et le jumeau de ce PC'),
          row(Icons.cancel_outlined, fc.success,
              'Arrêter d\'urgence : chez lui d\'abord, puis par ce PC'),
          row(Icons.do_not_disturb_on_outlined, fc.danger,
              'Commander un axe par le lien : jamais'),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard(
      ForgeronColorPalette fc, ChatRelayHostState hostState) {
    return _PanelCard(
      fc: fc,
      icon: Icons.groups_outlined,
      title: 'PARTICIPANTS',
      trailing: Text('${hostState.clients}',
          style: TextStyle(
              color: fc.textSecondary,
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700)),
      child: Text(
        hostState.running
            ? (hostState.clients > 0
                ? '${hostState.clients} appareil(s) relié(s) à la session.'
                : 'En attente de connexion (IP + code ${hostState.code ?? ""}).')
            : 'La session est fermée.',
        style: TextStyle(color: fc.textSecondary, fontSize: 12.5),
      ),
    );
  }

  Widget _buildActivityCard(
      ForgeronColorPalette fc, List<BackofficeEvent> events) {
    return _PanelCard(
      fc: fc,
      icon: Icons.history_rounded,
      title: 'ACTIVITÉ DE LA SESSION',
      expandChild: true,
      child: events.isEmpty
          ? Center(
              child: Text('Rien encore.',
                  style: TextStyle(color: fc.textDisabled, fontSize: 12.5)),
            )
          : ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 12, color: fc.surfaceBorder),
              itemBuilder: (context, i) {
                final e = events[i];
                final time =
                    '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}';
                return Row(
                  children: [
                    Text(time,
                        style: TextStyle(
                            color: fc.textDisabled,
                            fontSize: 11,
                            fontFamily: 'JetBrains Mono')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.summary,
                          style:
                              TextStyle(color: fc.textPrimary, fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── MODE REJOINDRE UN PC (TABLETTE / CLIENT) ──────────────────────────────

  Widget _buildJoinView(ForgeronColorPalette fc) {
    final remote = ref.watch(remoteChatClientProvider);
    final client = ref.read(remoteChatClientProvider.notifier);

    if (remote.status != RemoteChatStatus.connected) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _PanelCard(
            fc: fc,
            icon: Icons.phonelink_rounded,
            title: 'REJOINDRE UN PC',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Entrez l\'adresse IP du PC hôte (ex. 192.168.137.1 sur le hotspot Windows) et le code à 6 chiffres affiché sur le PC.',
                  style: TextStyle(
                      color: fc.textSecondary, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostCtrl,
                  style: TextStyle(
                      color: fc.textPrimary, fontFamily: 'JetBrains Mono'),
                  decoration: InputDecoration(
                    labelText: 'IP du PC',
                    filled: true,
                    fillColor: fc.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontFamily: 'JetBrains Mono',
                      letterSpacing: 4),
                  decoration: InputDecoration(
                    labelText: 'Code à 6 chiffres',
                    filled: true,
                    fillColor: fc.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (remote.error != null) ...[
                  const SizedBox(height: 10),
                  Text(remote.error!,
                      style: TextStyle(color: fc.danger, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: remote.status == RemoteChatStatus.connecting
                        ? null
                        : () => client.connect(
                            _hostCtrl.text.trim(), _codeCtrl.text.trim()),
                    icon: const Icon(Icons.link_rounded),
                    label: Text(
                      remote.status == RemoteChatStatus.connecting
                          ? 'Connexion...'
                          : 'Se connecter au PC',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fc.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final machine = ref.watch(machineStateProvider).valueOrNull ??
        const MachineState(status: MachineStatus.offline);
    final prog = ref.watch(streamProgressProvider);
    final sim = ref.watch(simulationProvider);
    final snap = remote.snapshot;

    return Column(
      children: [
        // En-tête de session active + STOP local
        Row(
          children: [
            _DeviceDot(icon: Icons.computer_rounded, color: fc.primary, fc: fc),
            const SizedBox(width: 8),
            _DeviceDot(icon: Icons.tablet_mac_rounded, color: fc.success, fc: fc),
            const SizedBox(width: 8),
            _DeviceDot(icon: Icons.smartphone_rounded, color: fc.warning, fc: fc),
            const SizedBox(width: 12),
            _StatusBadge(
              label: 'Relié à ${remote.host ?? "PC"}',
              color: fc.success,
              fc: fc,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Quitter la session',
              onPressed: client.disconnect,
              icon: Icon(Icons.logout_rounded, color: fc.textSecondary),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(streamingProvider.notifier).stopStream(),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('STOP',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: fc.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colonne gauche : Machine + Programme + Simulateur
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildRemoteMachineCard(fc, machine),
                      const SizedBox(height: 12),
                      _buildRemoteProgramCard(fc, prog),
                      const SizedBox(height: 12),
                      _buildRemoteSimCard(fc, sim),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Colonne droite : Chat IA synchronisé
              Expanded(
                flex: 5,
                child: _buildRemoteChatPanel(fc, snap, client),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteMachineCard(ForgeronColorPalette fc, MachineState m) {
    final pos = m.mPos;
    Widget axisRow(String label, Color color, double val, {bool deg = false}) =>
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fc.background,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
              const Spacer(),
              Text(
                '${val.toStringAsFixed(deg ? 2 : 3)}${deg ? '°' : ''}',
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        );

    return _PanelCard(
      fc: fc,
      icon: Icons.precision_manufacturing_outlined,
      title: 'MACHINE DU PC',
      trailing: _StatusBadge(
        label: m.status.name.toUpperCase(),
        color: m.status == MachineStatus.alarm
            ? fc.danger
            : (m.status == MachineStatus.run ? fc.success : fc.primary),
        fc: fc,
      ),
      child: Column(
        children: [
          axisRow('X', fc.axisX, pos.isNotEmpty ? pos[0] : 0),
          axisRow('Y', fc.axisY, pos.length > 1 ? pos[1] : 0),
          axisRow('Z', fc.axisZ, pos.length > 2 ? pos[2] : 0),
          axisRow('A', fc.axisA, pos.length > 3 ? pos[3] : 0, deg: true),
          axisRow('C', fc.axisC, pos.length > 4 ? pos[4] : 0, deg: true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  fc: fc,
                  label: 'AVANCE',
                  value: '${m.feedrate.toStringAsFixed(0)} mm/min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  fc: fc,
                  label: 'BROCHE',
                  value: '${m.spindleSpeed.toStringAsFixed(0)} tr/min',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteProgramCard(
      ForgeronColorPalette fc, StreamProgress prog) {
    final pct = prog.percent.clamp(0, 100).toString();
    return _PanelCard(
      fc: fc,
      icon: Icons.description_outlined,
      title: 'PROGRAMME',
      trailing: _StatusBadge(
        label: prog.active ? 'EN COURS' : 'PRÊT',
        color: prog.active ? fc.success : fc.textDisabled,
        fc: fc,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ligne ${prog.currentLine} / ${prog.totalLines}',
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'JetBrains Mono')),
              const Spacer(),
              Text('$pct %',
                  style: TextStyle(
                      color: fc.primary,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'JetBrains Mono')),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prog.fraction,
              backgroundColor: fc.background,
              color: fc.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteSimCard(ForgeronColorPalette fc, SimulationState sim) {
    final simNotifier = ref.read(simulationProvider.notifier);
    return _PanelCard(
      fc: fc,
      icon: Icons.track_changes_outlined,
      title: 'SIMULATEUR DU PC',
      trailing: _StatusBadge(
        label: sim.isLive ? 'JUMEAU' : 'HORS LIGNE',
        color: sim.isLive ? fc.success : fc.textDisabled,
        fc: fc,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: sim.isLive
                ? simNotifier.stopFollowing
                : simNotifier.followMachine,
            icon: const Icon(Icons.sync_rounded, size: 15),
            label: Text(sim.isLive ? 'Arrêter le jumeau' : 'Suivre le réel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: sim.isLive ? fc.success : fc.surfaceBright,
              foregroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => simNotifier.play(speedMultiplier: 1.0),
            icon: const Icon(Icons.play_arrow_rounded, size: 15),
            label: const Text('Simuler'),
          ),
          OutlinedButton.icon(
            onPressed: simNotifier.reset,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Remettre à zéro'),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteChatPanel(
    ForgeronColorPalette fc,
    RemoteChatSnapshot snap,
    RemoteChatClient client,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              itemCount: snap.messages.length + (snap.streaming != null ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == snap.messages.length && snap.streaming != null) {
                  return _ChatBubble(
                      fc: fc, isUser: false, text: snap.streaming!);
                }
                final m = snap.messages[i];
                if (m.role == 'tool') return const SizedBox.shrink();
                return _ChatBubble(
                    fc: fc, isUser: m.role == 'user', text: m.text);
              },
            ),
          ),
          if (snap.pendingTool != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fc.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fc.warning.withValues(alpha: 0.7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Action en attente de confirmation',
                      style: TextStyle(
                          color: fc.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${snap.pendingTool} ${snap.pendingInput}',
                      style: TextStyle(
                          color: fc.textSecondary,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: client.reject,
                          child: const Text('Refuser'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: client.confirm,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: fc.primary,
                              foregroundColor: Colors.white),
                          child: const Text('Confirmer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.photo_camera_outlined,
                      color: fc.textSecondary),
                ),
                IconButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.image_outlined, color: fc.textSecondary),
                ),
                if (_pendingImage != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(_pendingImage!,
                          width: 34, height: 34, fit: BoxFit.cover),
                    ),
                  ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.keyV &&
                          (HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isMetaPressed)) {
                        _pasteImage();
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _chatCtrl,
                      style: TextStyle(color: fc.textPrimary, fontSize: 13),
                      onSubmitted: (_) => _sendRemoteMessage(),
                      decoration: InputDecoration(
                        hintText: 'Écrire au PC...',
                        hintStyle: TextStyle(color: fc.textDisabled),
                        filled: true,
                        fillColor: fc.background,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: fc.surfaceBorder),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendRemoteMessage,
                  icon: Icon(Icons.send_rounded, color: fc.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets visuels internes ────────────────────────────────────────────────

class _SwitchTab extends StatelessWidget {
  const _SwitchTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.fc,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ForgeronColorPalette fc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? fc.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? fc.primary.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: selected ? fc.primary : fc.textSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? fc.primary : fc.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.fc,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.expandChild = false,
  });

  final ForgeronColorPalette fc;
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: fc.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: fc.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.fc,
  });

  final String label;
  final Color color;
  final ForgeronColorPalette fc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceDot extends StatelessWidget {
  const _DeviceDot({required this.icon, required this.color, required this.fc});
  final IconData icon;
  final Color color;
  final ForgeronColorPalette fc;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fc.success,
              border: Border.all(color: fc.background, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(
      {required this.fc, required this.label, required this.value});
  final ForgeronColorPalette fc;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'JetBrains Mono')),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble(
      {required this.fc, required this.isUser, required this.text});
  final ForgeronColorPalette fc;
  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? fc.primary.withValues(alpha: 0.14)
              : fc.surfaceBright,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUser
                ? fc.primary.withValues(alpha: 0.4)
                : fc.surfaceBorder,
          ),
        ),
        child: Text(text, style: TextStyle(color: fc.textPrimary, fontSize: 13)),
      ),
    );
  }
}
