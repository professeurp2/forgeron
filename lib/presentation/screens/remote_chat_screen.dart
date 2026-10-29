import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/providers/ai_agent_provider.dart';
import '../../application/providers/streaming_provider.dart';
import '../../application/services/chat_relay.dart';
import '../../application/services/tool_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/forgeron_colors.dart';

/// Le chat du PC, vu et piloté depuis le téléphone (voir chat_relay.dart).
///
/// L'agent tourne sur le PC ; cet écran montre son fil en direct, envoie les
/// messages et les photos, et répond aux confirmations. L'arrêt d'urgence,
/// lui, reste LOCAL : le bouton rouge et un « stop » tapé ici agissent par la
/// liaison du téléphone à la machine, jamais par le PC.
class RemoteChatScreen extends ConsumerStatefulWidget {
  const RemoteChatScreen({super.key});

  @override
  ConsumerState<RemoteChatScreen> createState() => _RemoteChatScreenState();
}

class _RemoteChatScreenState extends ConsumerState<RemoteChatScreen> {
  final _host = TextEditingController();
  final _code = TextEditingController();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  Uint8List? _image;
  String? _imageMime;

  @override
  void initState() {
    super.initState();
    final client = ref.read(remoteChatClientProvider.notifier);
    _host.text = ref.read(remoteChatClientProvider).host ?? client.defaultHost();
  }

  @override
  void dispose() {
    _host.dispose();
    _code.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _estop() {
    ref.read(streamingProvider.notifier).stopStream();
    HapticFeedback.heavyImpact();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _image == null) return;
    final wasEstop = await ref
        .read(remoteChatClientProvider.notifier)
        .send(text, image: _image, mime: _imageMime);
    _input.clear();
    setState(() {
      _image = null;
      _imageMime = null;
    });
    if (wasEstop && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Arrêt d\'urgence exécuté par CE téléphone, pas par le PC.'))));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > ChatRelayProtocol.maxImageBytes) return;
      setState(() {
        _image = bytes;
        _imageMime = file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      });
    } catch (_) {
      // Capture annulée / caméra indisponible.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final remote = ref.watch(remoteChatClientProvider);
    ref.listen(remoteChatClientProvider.select((r) => r.snapshot.messages.length), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    });
    final connected = remote.status == RemoteChatStatus.connected;

    return Scaffold(
      backgroundColor: fc.background,
      appBar: AppBar(
        backgroundColor: fc.surface,
        title: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? fc.success : fc.textDisabled,
            ),
          ),
          const SizedBox(width: 10),
          Text(tr('Chat du PC'), style: TextStyle(color: fc.textPrimary, fontSize: 16)),
        ]),
        actions: [
          if (connected)
            IconButton(
              tooltip: tr('Couper la liaison'),
              icon: Icon(Icons.link_off_rounded, color: fc.textSecondary),
              onPressed: () => ref.read(remoteChatClientProvider.notifier).disconnect(),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: fc.error),
              onPressed: _estop,
              icon: const Icon(Icons.dangerous_rounded, size: 18),
              label: Text(tr('STOP')),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: connected ? _chat(fc, remote.snapshot) : _pairing(fc, remote),
      ),
    );
  }

  Widget _pairing(ForgeronColorPalette fc, RemoteChatState remote) {
    final busy = remote.status == RemoteChatStatus.connecting;
    return ListView(
      key: const ValueKey('pairing'),
      padding: const EdgeInsets.all(20),
      children: [
        Icon(Icons.phonelink_ring_rounded, size: 48, color: fc.primary),
        const SizedBox(height: 12),
        Text(
          tr('Sur le PC : console Agent IA → bouton « Relier un téléphone ». '
              'Saisis ici le code à 6 chiffres qu\'il affiche.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: fc.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _host,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: tr('Adresse du PC'),
            hintText: '192.168.0.10',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(letterSpacing: 6, fontSize: 20),
          decoration: InputDecoration(
            labelText: tr('Code de liaison'),
            border: const OutlineInputBorder(),
          ),
        ),
        if (remote.error != null) ...[
          const SizedBox(height: 4),
          Text(remote.error!, style: TextStyle(color: fc.error, fontSize: 12.5)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => ref
                  .read(remoteChatClientProvider.notifier)
                  .connect(_host.text.trim(), _code.text.trim()),
          icon: busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.link_rounded),
          label: Text(tr('Se relier')),
        ),
      ],
    );
  }

  Widget _chat(ForgeronColorPalette fc, RemoteChatSnapshot snap) {
    final messages = snap.messages;
    final streaming = snap.streaming;
    return Column(
      key: const ValueKey('chat'),
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            itemCount: messages.length + (streaming != null ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= messages.length) {
                return _Bubble(fc: fc, mine: false, text: streaming!, live: true);
              }
              final m = messages[i];
              if (m.role == 'tool') return _ToolLine(fc: fc, message: m);
              return _Bubble(fc: fc, mine: m.role == 'user', text: m.text);
            },
          ),
        ),
        if (snap.processing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(children: [
              SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fc.primary)),
              const SizedBox(width: 8),
              for (final s in snap.specialists)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tr(ToolRouter.labels[s] ?? s),
                        style: TextStyle(fontSize: 10.5, color: fc.primary)),
                  ),
                ),
              Text(tr('Le PC travaille…'),
                  style: TextStyle(color: fc.textDisabled, fontSize: 11.5)),
            ]),
          ),
        if (snap.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(snap.error!, style: TextStyle(color: fc.error, fontSize: 12)),
          ),
        if (snap.pendingTool != null) _pendingCard(fc, snap),
        _composer(fc),
      ],
    );
  }

  Widget _pendingCard(ForgeronColorPalette fc, RemoteChatSnapshot snap) {
    final client = ref.read(remoteChatClientProvider.notifier);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fc.warning.withValues(alpha: 0.10),
        border: Border.all(color: fc.warning.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Action en attente de confirmation'),
            style: TextStyle(color: fc.warning, fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text('${snap.pendingTool} ${snap.pendingInput.isEmpty ? '' : snap.pendingInput}',
            style: TextStyle(color: fc.textPrimary, fontSize: 12.5)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(onPressed: client.reject, child: Text(tr('Refuser'))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(onPressed: client.confirm, child: Text(tr('Confirmer'))),
          ),
        ]),
      ]),
    );
  }

  Widget _composer(ForgeronColorPalette fc) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: fc.surface,
          border: Border(top: BorderSide(color: fc.surfaceBorder)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_image != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(_image!, height: 64),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _image = null),
                    child: const CircleAvatar(radius: 10, child: Icon(Icons.close, size: 12)),
                  ),
                ),
              ]),
            ),
          Row(children: [
            IconButton(
              tooltip: tr('Photo'),
              icon: Icon(Icons.photo_camera_outlined, color: fc.textSecondary),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            IconButton(
              tooltip: tr('Image de la galerie'),
              icon: Icon(Icons.image_outlined, color: fc.textSecondary),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: tr('Écrire au PC…'),
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: tr('Envoyer'),
              icon: Icon(Icons.send_rounded, color: fc.primary),
              onPressed: _send,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fc, required this.mine, required this.text, this.live = false});
  final ForgeronColorPalette fc;
  final bool mine;
  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mine ? fc.primary.withValues(alpha: 0.16) : fc.surface,
            border: Border.all(color: live ? fc.primary.withValues(alpha: 0.5) : fc.surfaceBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(text,
              style: TextStyle(color: fc.textPrimary, fontSize: 13.5, height: 1.35)),
        ),
      ),
    );
  }
}

class _ToolLine extends StatelessWidget {
  const _ToolLine({required this.fc, required this.message});
  final ForgeronColorPalette fc;
  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final running = message.toolResult == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(children: [
        Icon(running ? Icons.sync_rounded : (message.toolFailed ? Icons.error_outline : Icons.check_circle_outline),
            size: 14,
            color: running ? fc.primary : (message.toolFailed ? fc.error : fc.success)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message.toolName ?? message.text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fc.textSecondary, fontSize: 11.5, fontFamily: 'JetBrains Mono')),
        ),
      ]),
    );
  }
}
