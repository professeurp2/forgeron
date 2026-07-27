import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../application/providers/ai_agent_provider.dart';
import '../../application/providers/ai_agent_settings_provider.dart';
import '../../application/providers/ai_inbox_provider.dart';
import '../../application/providers/ai_usage_provider.dart';
import '../../application/providers/ai_model_provider.dart';
import 'ai_agent_settings_screen.dart';

/// Écran de chat avec l'agent IA — reprend le pattern visuel du terminal MDI
/// (log défilant, barre de saisie) et y ajoute des cartes de confirmation
/// inline pour les actions gatées par [AiAgentSettings].
class AiAssistantScreen extends ConsumerStatefulWidget {
  /// `true` quand l'écran est ouvert dans une route avec sa propre AppBar
  /// (mobile) → on masque l'en-tête interne pour éviter la double barre.
  /// `false` en embarqué desktop (l'en-tête interne porte param/effacer).
  final bool embedded;

  const AiAssistantScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Image en attente d'envoi (multimodal Gemini vision).
  Uint8List? _pendingImage;
  String? _pendingImageMime;

  // Audio : dictée (STT) + lecture des réponses (TTS).
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    // Écran ouvert → l'opérateur voit les messages en direct, on efface le
    // badge du bouton IA.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiInboxProvider.notifier).setScreenOpen(true);
    });
    _tts.setLanguage('fr-FR');
    _tts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    ref.read(aiInboxProvider.notifier).setScreenOpen(false);
    _speech.stop();
    _tts.stop();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Dictée vocale : bascule l'écoute du micro et remplit le champ de saisie.
  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = _speech.isAvailable ||
        await _speech.initialize(
          onStatus: (s) {
            if ((s == 'notListening' || s == 'done') && mounted) {
              setState(() => _listening = false);
            }
          },
          onError: (_) {
            if (mounted) setState(() => _listening = false);
          },
        );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reconnaissance vocale indisponible sur cet appareil.')),
        );
      }
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        if (mounted) setState(() => _inputCtrl.text = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(localeId: 'fr_FR'),
    );
  }

  /// Lecture vocale d'une réponse (nettoie le markdown pour l'oral).
  Future<void> _speak(String text) async {
    final clean = text
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  void _send() {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty && _pendingImage == null) return;
    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(
          text,
          imageBytes: _pendingImage,
          imageMime: _pendingImageMime,
        );
    _inputCtrl.clear();
    setState(() {
      _pendingImage = null;
      _pendingImageMime = null;
    });
    _scrollToEnd();
  }

  final ImagePicker _picker = ImagePicker();

  /// Propose caméra ou galerie (feuille du bas), comme une app de messagerie.
  Future<void> _showImageSourceSheet() async {
    final fc = context.fc;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: fc.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: fc.primary),
              title: Text('Prendre une photo',
                  style: TextStyle(color: fc.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: fc.primary),
              title: Text('Choisir dans la galerie',
                  style: TextStyle(color: fc.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (source != null) await _pickImageFrom(source);
  }

  /// Capture/sélectionne une image à joindre au prochain message.
  Future<void> _pickImageFrom(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 70, // compresse pour la 4G
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Image trop lourde (max 4 Mo sur la 4G).')),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _pendingImage = bytes;
        _pendingImageMime = _mimeFromName(file.name);
      });
    } catch (_) {
      // Capture annulée / caméra indisponible → on ignore.
    }
  }

  static String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Copie un message dans le presse-papiers (avec confirmation).
  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copié'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Envoi direct d'un texte prédéfini (chips de suggestion / compétences).
  void _sendText(String text) {
    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(text);
    _scrollToEnd();
  }

  static String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _scrollToEnd() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final chat = ref.watch(aiAgentControllerProvider);
    final settings = ref.watch(aiAgentSettingsProvider);
    final usage = ref.watch(aiUsageProvider);
    final model = ref.watch(aiModelProvider);

    ref.listen(aiAgentControllerProvider, (previous, next) {
      final grew = (previous?.messages.length ?? 0) < next.messages.length;
      if (grew ||
          previous?.isProcessing != next.isProcessing ||
          previous?.streamingText != next.streamingText) {
        _scrollToEnd();
      }
      // Lecture vocale du dernier message de l'assistant si le TTS est actif.
      if (grew && next.messages.isNotEmpty) {
        final last = next.messages.last;
        if (last.role == 'assistant' && ref.read(aiTtsEnabledProvider)) {
          _speak(last.text);
        }
      }
    });

    // Coupure du TTS → on stoppe toute lecture en cours.
    ref.listen(aiTtsEnabledProvider, (prev, next) {
      if (next == false) _tts.stop();
    });

    // Pas de Scaffold/AppBar ici : cet écran est embarqué comme un onglet
    // parmi d'autres (main_scaffold.dart), qui fournit déjà le chrome
    // (barre latérale desktop, ou AppBar + nav du bas sur mobile) — même
    // convention que MDITerminalScreen/DiagnosticsScreen.
    return Container(
      color: fc.background,
      child: Column(
        children: [
          // En-tête interne uniquement en embarqué (desktop) : en mobile,
          // l'AppBar de la route porte déjà titre + param + effacer.
          if (!widget.embedded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: fc.surface,
                border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: fc.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ASSISTANT IA',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fc.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined,
                        color: fc.textSecondary, size: 20),
                    tooltip: 'Paramètres de l\'agent',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AiAgentSettingsScreen()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: fc.textSecondary, size: 20),
                    tooltip: 'Effacer la conversation',
                    onPressed: () => ref
                        .read(aiAgentControllerProvider.notifier)
                        .clearConversation(),
                  ),
                ],
              ),
            ),
          if (!settings.enabled)
            _banner(
              fc,
              Icons.info_outline,
              fc.warning,
              'L\'agent IA est désactivé — active-le dans les paramètres pour discuter.',
            ),
          if (chat.error != null) _errorBanner(fc, chat),
          Expanded(
            child: (chat.messages.isEmpty && !chat.isProcessing)
                ? _emptyState(fc, settings.enabled)
                : Builder(builder: (context) {
                    final streaming = chat.streamingText != null &&
                        chat.streamingText!.isNotEmpty;
                    final thinking = chat.isProcessing &&
                        chat.pendingConfirmation == null &&
                        !streaming;
                    final extra = (streaming || thinking) ? 1 : 0;
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: chat.messages.length + extra,
                      itemBuilder: (ctx, i) {
                        if (i >= chat.messages.length) {
                          if (streaming) {
                            return _streamingBubble(fc, chat.streamingText!);
                          }
                          return _ThinkingBubble(fc: fc);
                        }
                        return _messageBubble(fc, chat.messages[i]);
                      },
                    );
                  }),
          ),
          if (chat.pendingConfirmation != null)
            _confirmationCard(fc, chat.pendingConfirmation!),
          if (chat.isProcessing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: fc.surfaceBorder,
                  color: fc.primary,
                ),
              ),
            ),
          _quotaStrip(fc, usage, model),
          _inputBar(fc, chat, settings.enabled),
        ],
      ),
    );
  }

  Widget _banner(ForgeronColorPalette fc, IconData icon, Color color, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }

  /// Rendu léger du markdown de l'assistant : **gras**, puces, et nettoyage
  /// LaTeX (`$...$`, `\text{}`) → texte lisible. Sans dépendance externe.
  static List<InlineSpan> _assistantSpans(String text) {
    var t = text
        .replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m[1] ?? '')
        .replaceAll(r'\times', ' × ')
        .replaceAll(r'\circ', '°')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'$', '');
    // Puces en début de ligne (« * » ou « - » suivi d'un espace).
    t = t.replaceAllMapped(
        RegExp(r'(^|\n)[ \t]*[*-][ \t]+'), (m) => '${m[1]}  • ');
    // Gras **...**
    final spans = <InlineSpan>[];
    final parts = t.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: t));
    return spans;
  }

  Widget _messageBubble(ForgeronColorPalette fc, AiChatMessage m) {
    if (m.role == 'tool') {
      return _ToolResultTile(fc: fc, raw: m.text, time: _fmtTime(m.timestamp));
    }

    final isUser = m.role == 'user';
    final baseStyle =
        TextStyle(color: fc.textPrimary, fontSize: 13, height: 1.35);

    // Contenu de la bulle : image (user) + texte, ou markdown rendu (assistant).
    final bubbleItems = <Widget>[];
    if (isUser && m.imageBytes != null) {
      bubbleItems.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
            child: Image.memory(m.imageBytes!, fit: BoxFit.cover),
          ),
        ),
      );
    }
    if (m.text.isNotEmpty) {
      if (bubbleItems.isNotEmpty) bubbleItems.add(const SizedBox(height: 8));
      bubbleItems.add(isUser
          ? SelectableText(m.text, style: baseStyle)
          : SelectableText.rich(
              TextSpan(style: baseStyle, children: _assistantSpans(m.text))));
    }
    final content = Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: isUser ? fc.primary.withValues(alpha: 0.15) : fc.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isUser ? 14 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 14),
            ),
            border: Border.all(
              color:
                  isUser ? fc.primary.withValues(alpha: 0.3) : fc.surfaceBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: bubbleItems,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3, left: 4, right: 4, bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fmtTime(m.timestamp),
                  style: TextStyle(color: fc.textDisabled, fontSize: 10)),
              if (!isUser && m.text.isNotEmpty) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _copy(m.text),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            size: 12, color: fc.textDisabled),
                        const SizedBox(width: 3),
                        Text('Copier',
                            style: TextStyle(
                                color: fc.textDisabled, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: content);
    }
    // Assistant : avatar robot à gauche de la bulle.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fc.primary.withValues(alpha: 0.15),
            border: Border.all(color: fc.primary.withValues(alpha: 0.4)),
          ),
          child: const Text('🤖', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Flexible(child: content),
      ],
    );
  }

  /// Bulle de réponse en cours de streaming (avatar + texte live + curseur).
  Widget _streamingBubble(ForgeronColorPalette fc, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fc.primary.withValues(alpha: 0.15),
            border: Border.all(color: fc.primary.withValues(alpha: 0.4)),
          ),
          child: const Text('🤖', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: fc.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(14),
              ),
              border: Border.all(color: fc.surfaceBorder),
            ),
            child: Text.rich(
              TextSpan(
                style:
                    TextStyle(color: fc.textPrimary, fontSize: 13, height: 1.35),
                children: [
                  ..._assistantSpans(text),
                  TextSpan(text: ' ▍', style: TextStyle(color: fc.primary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Bannière d'erreur avec bouton « Réessayer » et indicateur de reprise auto.
  Widget _errorBanner(ForgeronColorPalette fc, AiChatState chat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: fc.danger.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: fc.danger, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chat.error!,
                    style: TextStyle(color: fc.danger, fontSize: 12, height: 1.3)),
                if (chat.awaitingNetwork) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.6, color: fc.warning),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Reprise automatique dès le retour du réseau…',
                          style: TextStyle(color: fc.warning, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (chat.retryable) ...[
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () =>
                  ref.read(aiAgentControllerProvider.notifier).retryNow(),
              style: TextButton.styleFrom(
                foregroundColor: fc.danger,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }

  /// Barre compacte des quotas du jour, en bas de la discussion : modèle actif,
  /// requêtes consommées / RPD du modèle, et restantes. Non éditable.
  Widget _quotaStrip(ForgeronColorPalette fc, AiUsageState u, AiModelState m) {
    final limit = m.active.rpd;
    final used = u.usedFor(m.active.id);
    final remaining = (limit - used).clamp(0, limit);
    final frac = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final Color color;
    if (m.allExhausted) {
      color = fc.danger;
    } else if (frac > 0.85) {
      color = fc.warning;
    } else {
      color = fc.textDisabled;
    }
    final label = m.allExhausted
        ? 'Quota atteint (tous les modèles)'
        : '${m.active.label} · $used/$limit · $remaining restantes';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: fc.background,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Row(
        children: [
          Icon(m.auto ? Icons.autorenew : Icons.data_usage,
              size: 12, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          if (u.images > 0) ...[
            Text('🖼️ ${u.images}',
                style: TextStyle(color: fc.textDisabled, fontSize: 10.5)),
            const SizedBox(width: 10),
          ],
          Text('~${_fmtTokens(u.tokens)} tok',
              style: TextStyle(color: fc.textDisabled, fontSize: 10.5)),
        ],
      ),
    );
  }

  static String _fmtTokens(int t) {
    if (t >= 1000000) return '${(t / 1000000).toStringAsFixed(1)}M';
    if (t >= 1000) return '${(t / 1000).toStringAsFixed(1)}k';
    return '$t';
  }

  /// Écran d'accueil : présentation + chips de compétences cliquables.
  Widget _emptyState(ForgeronColorPalette fc, bool enabled) {
    const suggestions = <(IconData, String, String)>[
      (Icons.my_location, 'Position actuelle', 'Quelle est la position actuelle des axes ?'),
      (Icons.info_outline, 'État machine', 'Donne-moi l\'état complet de la machine.'),
      (Icons.home_outlined, 'Faire le Home', 'Lance le homing de tous les axes.'),
      (Icons.pause_circle_outline, 'Mettre en pause', 'Mets le programme en pause.'),
      (Icons.help_outline, 'Que sais-tu faire ?', 'Quelles actions peux-tu réaliser sur ma machine ?'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text('🤖', style: TextStyle(fontSize: 44, color: fc.primary)),
          const SizedBox(height: 12),
          Text('Assistant Forgeron',
              style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Pose une question ou demande une action sur ta CNC 5 axes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fc.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                ActionChip(
                  avatar: Icon(s.$1, size: 16, color: fc.primary),
                  label: Text(s.$2),
                  labelStyle: TextStyle(color: fc.textPrimary, fontSize: 12),
                  backgroundColor: fc.surface,
                  side: BorderSide(color: fc.surfaceBorder),
                  onPressed: enabled ? () => _sendText(s.$3) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confirmationCard(ForgeronColorPalette fc, AiPendingToolCall pending) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fc.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: fc.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'L\'agent souhaite exécuter :',
                  style: TextStyle(
                      color: fc.warning, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fc.terminalBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${pending.toolName}(${pending.input})',
              style: TextStyle(
                  color: fc.textPrimary, fontFamily: 'JetBrains Mono', fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(aiAgentControllerProvider.notifier).rejectPendingAction(),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: fc.danger, side: BorderSide(color: fc.danger)),
                  child: const Text('REFUSER'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ref
                      .read(aiAgentControllerProvider.notifier)
                      .confirmPendingAction(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: fc.warning, foregroundColor: Colors.black),
                  child: const Text('CONFIRMER'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputBar(ForgeronColorPalette fc, AiChatState chat, bool agentEnabled) {
    final enabled = agentEnabled &&
        !chat.isProcessing &&
        chat.pendingConfirmation == null;
    final String hint;
    if (!agentEnabled) {
      hint = 'Agent désactivé — voir paramètres';
    } else if (chat.pendingConfirmation != null) {
      hint = 'Confirme ou refuse l\'action ci-dessus';
    } else if (chat.isProcessing) {
      hint = 'L\'agent réfléchit…';
    } else {
      hint = 'Écris à l\'agent…';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aperçu de l'image en attente d'envoi.
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_pendingImage!,
                        width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Image jointe',
                        style: TextStyle(color: fc.textSecondary, fontSize: 12)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: fc.textDisabled, size: 18),
                    tooltip: 'Retirer l\'image',
                    onPressed: () => setState(() {
                      _pendingImage = null;
                      _pendingImageMime = null;
                    }),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: enabled ? _showImageSourceSheet : null,
                tooltip: 'Photo / image',
                iconSize: 20,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
                icon: Icon(Icons.photo_camera_rounded,
                    color: enabled ? fc.textSecondary : fc.textDisabled),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: enabled ? _toggleListen : null,
                tooltip: _listening ? 'Arrêter la dictée' : 'Dicter',
                iconSize: 20,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
                icon: Icon(
                  _listening ? Icons.mic : Icons.mic_none_rounded,
                  color: _listening
                      ? fc.danger
                      : (enabled ? fc.textSecondary : fc.textDisabled),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  enabled: enabled,
                  style: TextStyle(color: fc.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: fc.textDisabled),
                    filled: true,
                    fillColor: fc.surfaceBright,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: enabled ? (_) => _send() : null,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: enabled ? _send : null,
                style: IconButton.styleFrom(backgroundColor: fc.primary),
                icon: const Icon(Icons.send, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Appel d'outil dans le fil : puce compacte « 🔧 nom ✓ », dépliable pour voir
/// le détail (résultat JSON / message). Le texte brut est au format
/// `nom → détail` (cf. AiAgentController).
class _ToolResultTile extends StatefulWidget {
  final ForgeronColorPalette fc;
  final String raw;
  final String time;
  const _ToolResultTile(
      {required this.fc, required this.raw, required this.time});

  @override
  State<_ToolResultTile> createState() => _ToolResultTileState();
}

class _ToolResultTileState extends State<_ToolResultTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    final sep = widget.raw.indexOf(' → ');
    final name = sep >= 0 ? widget.raw.substring(0, sep) : widget.raw;
    final detail = sep >= 0 ? widget.raw.substring(sep + 3) : '';
    final isError = detail.toLowerCase().contains('erreur') ||
        detail.toLowerCase().contains('refusé');
    final accent = isError ? fc.danger : fc.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: detail.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isError ? Icons.error_outline : Icons.build_circle_outlined,
                      size: 14, color: accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'JetBrains Mono'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!isError)
                    Icon(Icons.check, size: 13, color: fc.success),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        size: 15, color: fc.textDisabled),
                  ],
                  const SizedBox(width: 4),
                  Text(widget.time,
                      style: TextStyle(color: fc.textDisabled, fontSize: 9)),
                ],
              ),
            ),
          ),
          if (_expanded && detail.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fc.terminalBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: fc.surfaceBorder),
              ),
              child: SelectableText(
                detail,
                style: TextStyle(
                    color: fc.textSecondary,
                    fontSize: 11,
                    fontFamily: 'JetBrains Mono',
                    height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bulle « l'agent réfléchit » avec trois points qui pulsent.
class _ThinkingBubble extends StatefulWidget {
  final ForgeronColorPalette fc;
  const _ThinkingBubble({required this.fc});

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fc.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: fc.surfaceBorder),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  _dot(fc, i),
                ],
                const SizedBox(width: 10),
                Text('réfléchit…',
                    style: TextStyle(color: fc.textDisabled, fontSize: 11)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot(ForgeronColorPalette fc, int index) {
    // Décalage de phase par point → effet de vague.
    final phase = (_ctrl.value + index * 0.2) % 1.0;
    final t = (phase < 0.5 ? phase : 1 - phase) * 2; // 0→1→0
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fc.primary.withValues(alpha: 0.35 + 0.55 * t),
      ),
    );
  }
}
