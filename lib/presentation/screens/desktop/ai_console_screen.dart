import 'dart:io';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart'
    show Colors, Icons, MaterialPageRoute, SelectableText;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../application/providers/ai_agent_provider.dart';
import '../../../application/providers/ai_agent_settings_provider.dart';
import '../../../application/providers/ai_artifacts_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../application/providers/ai_model_provider.dart';
import '../../../application/providers/ai_usage_provider.dart';
import '../../../application/services/ai_agent_tools.dart';
import '../../../application/services/ai_window_launcher.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../core/theme/forgeron_fluent_theme.dart';
import '../../../core/utils/chat_markdown.dart';
import '../../../core/utils/voice_locale.dart';
import '../../widgets/trunnion_visualizer.dart';
import '../../widgets/viewer_scene.dart';
import '../ai_agent_settings_screen.dart';
import 'ai_console_timeline.dart';

/// Console de l'agent IA — desktop.
///
/// Trois colonnes, comme les outils de ce genre : les discussions à gauche, le
/// fil au milieu, ce que l'agent a PRODUIT à droite. Cette troisième colonne
/// est la raison d'être de la refonte : le pipeline fabrique une pièce et un
/// parcours d'outil, et l'écran n'en montrait rien — il fallait lire du JSON
/// pour savoir qu'un G-code existait.
///
/// Toute l'orchestration reste celle de [aiAgentControllerProvider] : cet
/// écran ne change que la présentation — mêmes outils, même agent, même
/// historique que l'écran mobile.
class AiConsoleScreen extends StatelessWidget {
  const AiConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fc = ForgeronTheme.of(context);
    return fluent.FluentTheme(
      data: forgeronFluentTheme(fc),
      child: const _AiConsoleBody(),
    );
  }
}

class _AiConsoleBody extends ConsumerStatefulWidget {
  const _AiConsoleBody();

  @override
  ConsumerState<_AiConsoleBody> createState() => _AiConsoleBodyState();
}

class _AiConsoleBodyState extends ConsumerState<_AiConsoleBody> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  // Image en attente d'envoi (multimodal) — même mécanisme que l'écran
  // mobile : sendUserMessage(text, imageBytes:, imageMime:). Ne PAS réinventer
  // un second canal d'envoi d'image.
  Uint8List? _pendingImage;
  String? _pendingImageMime;

  bool _railOpen = true;

  /// Le fil ne se recale en bas QUE si l'opérateur y était déjà. Sinon une
  /// génération longue le ramènerait de force à chaque mot pendant qu'il
  /// relit une étape plus haut.
  bool _atBottom = true;

  // Voix — dictée et lecture des réponses, comme sur mobile. Mêmes paquets,
  // même logique de correspondance de locale : pas un second système.
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _listening = false;
  String? _sttLocaleId;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.5);
    _applyVoiceLanguage();
    _scroll.addListener(_watchScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_watchScroll);
    _input.dispose();
    _scroll.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _watchScroll() {
    if (!_scroll.hasClients) return;
    final atBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
  }

  // ─────────────────────────────── Voix ──────────────────────────────────

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
      await _warn('Reconnaissance vocale indisponible',
          'Aucun micro détecté sur cet appareil.');
      return;
    }
    setState(() => _listening = true);
    _sttLocaleId ??= bestVoiceLocale(
      _wantedVoiceTag,
      (await _speech.locales()).map((l) => l.localeId),
      fallbacks: const ['fr-FR', 'en-US'],
    );
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        if (mounted) setState(() => _input.text = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(localeId: _sttLocaleId),
    );
  }

  String get _wantedVoiceTag {
    final language = ref.read(appLanguageProvider);
    if (!language.isAuto) return language.voiceTag;
    return WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
  }

  Future<void> _applyVoiceLanguage() async {
    _sttLocaleId = null; // re-résolu à la prochaine dictée
    try {
      final raw = await _tts.getLanguages;
      final available = (raw as List).map((e) => e.toString()).toList(growable: false);
      final match =
          bestVoiceLocale(_wantedVoiceTag, available, fallbacks: const ['fr-FR', 'en-US']);
      if (match != null) await _tts.setLanguage(match);
    } catch (_) {
      // getLanguages n'est pas implémenté sur toutes les plateformes.
    }
  }

  Future<void> _speak(String text) async {
    final clean = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' bloc de code ')
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  // ───────────────────────────── Envoi ───────────────────────────────────

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty && _pendingImage == null) return;
    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(
          text,
          imageBytes: _pendingImage,
          imageMime: _pendingImageMime,
        );
    _input.clear();
    setState(() {
      _pendingImage = null;
      _pendingImageMime = null;
      _atBottom = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _sendText(String text) {
    _input.text = text;
    _send();
  }

  /// Sélection d'image depuis un fichier — pas de caméra ici :
  /// `image_picker_windows` lève un `StateError` sur `ImageSource.camera`
  /// faute de `cameraDelegate`. La capture photo reste une action mobile ; le
  /// desktop travaille depuis des fichiers (export CAO, capture d'écran).
  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        await _warn('Image trop lourde', '8 Mo maximum.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _pendingImage = bytes;
        _pendingImageMime = _mimeFromName(file.name);
      });
    } catch (_) {
      // Sélection annulée → on ignore, comme côté mobile.
    }
  }

  static String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  /// Charge une pièce : l'aperçu 3D se prépare tout de suite (colonne de
  /// droite) pendant que l'agent, lui, reçoit la demande d'usinage. L'un
  /// n'attend pas l'autre — voir la pièce ne devrait jamais dépendre de la
  /// disponibilité du modèle.
  Future<void> _pickStepFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['step', 'stp'],
      dialogTitle: 'Charger une pièce (STEP)',
    );
    final path = result?.files.single.path;
    if (path == null) return; // annulé

    ref.read(aiArtifactsProvider.notifier).loadStep(path);
    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(
          'Charge ce fichier STEP et prépare le G-code de finition.\n\nFichier : $path',
        );
    setState(() => _atBottom = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _warn(String title, String message) async {
    if (!mounted) return;
    await fluent.displayInfoBar(context, builder: (ctx, close) {
      return fluent.InfoBar(
        title: Text(title),
        content: Text(message),
        severity: fluent.InfoBarSeverity.warning,
        onClose: close,
      );
    });
  }

  Future<void> _confirmClear() async {
    final ok = await fluent.showDialog<bool>(
      context: context,
      builder: (ctx) => fluent.ContentDialog(
        title: const Text('Effacer la discussion ?'),
        content: const Text(
            'Les messages et les étapes de cette discussion seront perdus. '
            'Les autres discussions ne sont pas touchées.'),
        actions: [
          fluent.Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          fluent.FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(aiAgentControllerProvider.notifier).clearConversation();
    }
  }

  // ───────────────────────────── Rendu ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiAgentControllerProvider);
    final fc = ForgeronTheme.of(context);

    ref.listen<AiPopupRequest?>(aiPopupRequestProvider, (previous, next) {
      if (next == null) return;
      ref.read(aiPopupRequestProvider.notifier).state = null;
      _showPopup(context, fc, next);
    });

    ref.listen(aiAgentControllerProvider, (previous, next) {
      // Le fil bouge : nouvelle étape, étape terminée, nouveau message. On ne
      // suit que si l'opérateur était déjà en bas (voir _atBottom).
      if (previous?.messages.length != next.messages.length ||
          previous?.streamingText != next.streamingText) {
        if (_atBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
        }
      }
      final grew = (previous?.messages.length ?? 0) < next.messages.length;
      if (grew && next.messages.isNotEmpty) {
        final last = next.messages.last;
        if (last.role == 'assistant' && ref.read(aiTtsEnabledProvider)) {
          _speak(last.text);
        }
      }
    });

    ref.listen(aiTtsEnabledProvider, (prev, next) {
      if (next == false) _tts.stop();
    });

    ref.listen(appLanguageProvider, (prev, next) {
      if (prev?.id != next.id) _applyVoiceLanguage();
    });

    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      // Les deux colonnes latérales s'effacent quand la fenêtre est étroite :
      // en dessous, le fil lui-même devient illisible, et c'est lui qui compte.
      content: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final showRail = _railOpen && constraints.maxWidth >= 900;
        return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showRail)
            _ConversationRail(
              fc: fc,
              chat: chat,
              onClose: () => setState(() => _railOpen = false),
              onClear: _confirmClear,
            ),
          Expanded(
            child: Column(
              children: [
                _Header(
                  fc: fc,
                  chat: chat,
                  railOpen: showRail,
                  onToggleRail: () => setState(() => _railOpen = !_railOpen),
                ),
                Expanded(child: _thread(fc, chat)),
                if (chat.pendingConfirmation != null)
                  _ConfirmationBar(fc: fc, pending: chat.pendingConfirmation!),
                if (chat.error != null) _ErrorBar(fc: fc, chat: chat),
                _Composer(
                  fc: fc,
                  controller: _input,
                  busy: chat.isProcessing,
                  onSend: _send,
                  onStop: () =>
                      ref.read(aiAgentControllerProvider.notifier).stopGeneration(),
                  onAttachStep: _pickStepFile,
                  onAttachImage: _pickImage,
                  pendingImage: _pendingImage,
                  onRemoveImage: () => setState(() {
                    _pendingImage = null;
                    _pendingImageMime = null;
                  }),
                  listening: _listening,
                  onToggleListen: _toggleListen,
                ),
              ],
            ),
          ),
          if (wide) _ArtifactsRail(fc: fc, onPickStep: _pickStepFile),
        ],
        );
      }),
    );
  }

  Widget _thread(ForgeronColorPalette fc, AiChatState chat) {
    final streaming = chat.streamingText != null && chat.streamingText!.isNotEmpty;
    final thinking = chat.isProcessing && chat.pendingConfirmation == null;

    if (chat.messages.isEmpty && !streaming && !thinking) {
      return _EmptyState(fc: fc, onPickStep: _pickStepFile, onAsk: _sendText);
    }

    final items = _withDaySeparators(groupConsoleItems(chat.messages));
    final extras = (streaming ? 1 : 0) + (thinking ? 1 : 0);

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
          itemCount: items.length + extras,
          itemBuilder: (context, i) {
            if (i >= items.length) {
              final offset = i - items.length;
              if (streaming && offset == 0) {
                return StreamingBubble(fc: fc, text: chat.streamingText!);
              }
              // Ligne d'état : ce que l'agent fait EN CE MOMENT, avec le
              // chrono et les jetons de l'échange en cours.
              return LiveStatusLine(
                fc: fc,
                since: chat.turnStartedAt,
                tokens: chat.turnTokens,
                activity: chat.runningTool != null
                    ? friendlyToolLabel(chat.runningTool!)
                    : (streaming ? 'Rédaction de la réponse…' : 'Réflexion…'),
              );
            }
            final item = items[i];
            if (item is DateTime) return DaySeparator(fc: fc, day: item);
            if (item is ToolRun) return ToolRunTile(fc: fc, run: item);
            return _MessageBubble(fc: fc, message: item as AiChatMessage);
          },
        ),
        if (!_atBottom)
          Positioned(
            right: 18,
            bottom: 12,
            child: fluent.Tooltip(
              message: 'Revenir en bas',
              child: fluent.IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: fc.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: fc.surfaceBorder),
                  ),
                  child: Icon(Icons.arrow_downward_rounded,
                      size: 16, color: fc.primary),
                ),
                onPressed: () {
                  setState(() => _atBottom = true);
                  _scrollToEnd();
                },
              ),
            ),
          ),
      ],
    );
  }

  /// Intercale un séparateur à chaque changement de journée. Le repère se
  /// prend sur l'horodatage du premier message de chaque élément.
  static List<Object> _withDaySeparators(List<Object> items) {
    final out = <Object>[];
    DateTime? lastDay;
    for (final item in items) {
      final ts = switch (item) {
        AiChatMessage m => m.timestamp,
        ToolRun r when r.steps.isNotEmpty => r.steps.first.timestamp,
        _ => null,
      };
      if (ts != null) {
        final day = DateTime(ts.year, ts.month, ts.day);
        // Un horodatage à zéro vient d'un historique sans date : on ne
        // fabrique pas un séparateur « 01/01/1970 » pour autant.
        if (ts.millisecondsSinceEpoch > 0 && day != lastDay) {
          out.add(day);
          lastDay = day;
        }
      }
      out.add(item);
    }
    return out;
  }

  void _showPopup(
      BuildContext context, ForgeronColorPalette fc, AiPopupRequest req) {
    final color = switch (req.severity) {
      'danger' => fc.danger,
      'warning' => fc.warning,
      _ => fc.info,
    };
    final icon = switch (req.severity) {
      'danger' => fluent.FluentIcons.error_badge,
      'warning' => fluent.FluentIcons.warning,
      _ => fluent.FluentIcons.info,
    };
    fluent.showDialog(
      context: context,
      builder: (context) => fluent.ContentDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(req.title)),
          ],
        ),
        content: Text(req.message),
        actions: [
          fluent.FilledButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════ Rail des discussions ═══════════════════════════

/// Colonne de gauche : les discussions sauvegardées. Elles existaient déjà
/// dans le contrôleur et n'étaient accessibles que depuis l'écran mobile — la
/// console desktop n'avait aucun moyen d'en ouvrir une autre, ni même de
/// savoir laquelle était ouverte.
class _ConversationRail extends ConsumerWidget {
  const _ConversationRail({
    required this.fc,
    required this.chat,
    required this.onClose,
    required this.onClear,
  });

  final ForgeronColorPalette fc;
  final AiChatState chat;
  final VoidCallback onClose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiAgentControllerProvider.notifier);
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: fc.sidebar,
        border: Border(right: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'DISCUSSIONS',
                    style: TextStyle(
                      color: fc.textDisabled,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                fluent.Tooltip(
                  message: 'Masquer le panneau',
                  child: fluent.IconButton(
                    icon: Icon(Icons.chevron_left_rounded,
                        size: 18, color: fc.textSecondary),
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: fluent.Button(
              onPressed: controller.newConversation,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(fluent.FluentIcons.add, size: 12),
                    SizedBox(width: 8),
                    Text('Nouvelle discussion'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: chat.conversations.length,
              itemBuilder: (context, i) {
                final c = chat.conversations[i];
                final active = c.id == chat.activeId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: fluent.HyperlinkButton(
                    onPressed: () => controller.switchConversation(c.id),
                    style: fluent.ButtonStyle(
                      padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      backgroundColor: WidgetStatePropertyAll(
                          active ? fc.primary.withValues(alpha: .12) : Colors.transparent),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                          side: active
                              ? BorderSide(color: fc.primary.withValues(alpha: .35))
                              : BorderSide.none,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: active ? fc.textPrimary : fc.textSecondary,
                                  fontSize: 12,
                                  fontWeight:
                                      active ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${c.messageCount} message${c.messageCount > 1 ? 's' : ''}',
                                style: TextStyle(color: fc.textDisabled, fontSize: 9.5),
                              ),
                            ],
                          ),
                        ),
                        fluent.Tooltip(
                          message: 'Supprimer',
                          child: fluent.IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 13, color: fc.textDisabled),
                            onPressed: () => controller.deleteConversation(c.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                Expanded(child: _QuotaStrip(fc: fc)),
                fluent.Tooltip(
                  message: 'Effacer cette discussion',
                  child: fluent.IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 16, color: fc.textSecondary),
                    onPressed: onClear,
                  ),
                ),
                fluent.Tooltip(
                  message: 'Paramètres de l\'agent',
                  child: fluent.IconButton(
                    icon: Icon(Icons.settings_outlined,
                        size: 16, color: fc.textSecondary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AiAgentSettingsScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Consommation du jour, reprise de l'écran mobile : sans elle, un quota
/// gratuit épuisé n'apparaît qu'au moment où l'agent refuse de répondre.
class _QuotaStrip extends ConsumerWidget {
  const _QuotaStrip({required this.fc});
  final ForgeronColorPalette fc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(aiUsageProvider);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        '${usage.requests} requête${usage.requests > 1 ? 's' : ''} · '
        '${formatTokens(usage.tokens)} jetons aujourd\'hui',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: usage.quotaHit ? fc.warning : fc.textDisabled,
          fontSize: 9.5,
        ),
      ),
    );
  }
}

// ══════════════════════════════ En-tête ════════════════════════════════════

class _Header extends ConsumerWidget {
  const _Header({
    required this.fc,
    required this.chat,
    required this.railOpen,
    required this.onToggleRail,
  });

  final ForgeronColorPalette fc;
  final AiChatState chat;
  final bool railOpen;
  final VoidCallback onToggleRail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        chat.conversations.where((c) => c.id == chat.activeId).toList();
    final title =
        active.isEmpty ? AiAgentController.kDefaultTitle : active.first.title;
    final ttsOn = ref.watch(aiTtsEnabledProvider);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Row(
        children: [
          if (!railOpen)
            fluent.Tooltip(
              message: 'Afficher les discussions',
              child: fluent.IconButton(
                icon: Icon(Icons.menu_rounded, size: 17, color: fc.textSecondary),
                onPressed: onToggleRail,
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [fc.primaryLight, fc.primary, fc.primaryDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(Icons.auto_awesome, size: 15, color: fc.background),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5),
                ),
                Text('pipeline CAM · outils machine',
                    style: TextStyle(color: fc.textDisabled, fontSize: 10.5)),
              ],
            ),
          ),
          const _ModelBadge(),
          const SizedBox(width: 8),
          fluent.Tooltip(
            message: ttsOn ? 'Lecture vocale activée' : 'Lecture vocale',
            child: fluent.IconButton(
              icon: Icon(
                ttsOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: ttsOn ? fc.primary : fc.textSecondary,
                size: 16,
              ),
              onPressed: () =>
                  ref.read(aiTtsEnabledProvider.notifier).state = !ttsOn,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelBadge extends ConsumerWidget {
  const _ModelBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = ForgeronTheme.of(context);
    final settings = ref.watch(aiAgentSettingsProvider);
    final useLocal = settings.localBaseUrl.isNotEmpty;
    final modelLabel =
        useLocal ? settings.localModel : ref.watch(aiModelProvider).active.id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fc.lcdBackground,
        border: Border.all(color: fc.lcdBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${useLocal ? "LOCAL" : "GEMINI"} · $modelLabel',
        style: TextStyle(
          color: fc.lcdText,
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ═══════════════════════════ Messages du fil ═══════════════════════════════

/// Un message de la conversation. L'opérateur à droite, l'agent à gauche et
/// sans bulle — sa prose est longue, une bulle la rendrait illisible.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.fc, required this.message});

  final ForgeronColorPalette fc;
  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.fromLTRB(60, 8, 0, 8),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          constraints: const BoxConstraints(maxWidth: 620),
          decoration: BoxDecoration(
            color: fc.surfaceHigh,
            border: Border.all(color: fc.surfaceBorder),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.imageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 220, maxWidth: 320),
                      child: Image.memory(message.imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              if (message.text.isNotEmpty)
                SelectableText(
                  message.text,
                  style: TextStyle(
                      color: fc.textPrimary, fontSize: 13, height: 1.5),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 40, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2, right: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fc.primary.withValues(alpha: .14),
            ),
            child: Icon(Icons.auto_awesome, size: 11, color: fc.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final part in _content()) part,
                if (message.interrupted)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Réponse interrompue.',
                      style: TextStyle(color: fc.warning, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Prose et blocs de code, séparés : le G-code arrive dans des ``` et doit
  /// être copiable et enregistrable, pas noyé dans le texte.
  List<Widget> _content() {
    final widgets = <Widget>[];
    final codeStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 12,
      color: fc.secondary,
    );
    for (final block in parseChatBlocks(message.text)) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 10));
      if (block.isCode) {
        widgets.add(_CodeBlock(fc: fc, block: block));
      } else {
        widgets.add(SelectableText.rich(
          TextSpan(
            style: TextStyle(color: fc.textPrimary, fontSize: 13.5, height: 1.6),
            children: chatProseSpans(block.text.trim(), codeStyle: codeStyle),
          ),
        ));
      }
    }
    return widgets;
  }
}

/// Bloc de code d'une réponse : monospace, défilement horizontal (les lignes
/// de G-code sont longues), et trois actions — copier, enregistrer sur le
/// disque, ouvrir dans une fenêtre à part. Sans elles il faudrait re-saisir le
/// programme à la main.
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.fc, required this.block});

  final ForgeronColorPalette fc;
  final ChatBlock block;

  @override
  Widget build(BuildContext context) {
    final isGcode = looksLikeGcode(block);
    final lineCount = block.text.trim().isEmpty
        ? 0
        : block.text.trimRight().split('\n').length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: fc.terminalBg,
        border: Border.all(color: fc.surfaceBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                Text(
                  isGcode
                      ? 'PROGRAMME · $lineCount lignes'
                      : (block.lang.isEmpty ? 'CODE' : block.lang.toUpperCase()),
                  style: TextStyle(
                    color: fc.textDisabled,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
                const Spacer(),
                fluent.Tooltip(
                  message: 'Copier',
                  child: fluent.IconButton(
                    icon: Icon(Icons.copy_rounded, size: 14, color: fc.textSecondary),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: block.text)),
                  ),
                ),
                if (isGcode) ...[
                  fluent.Tooltip(
                    message: 'Enregistrer sous…',
                    child: fluent.IconButton(
                      icon: Icon(Icons.save_alt_rounded,
                          size: 14, color: fc.textSecondary),
                      onPressed: () => _save(context),
                    ),
                  ),
                  fluent.Tooltip(
                    message: 'Ouvrir dans une fenêtre',
                    child: fluent.IconButton(
                      icon: Icon(Icons.open_in_new_rounded,
                          size: 14, color: fc.textSecondary),
                      onPressed: () => AiWindowLauncher.openGcode(
                        title: 'Programme de l\'agent',
                        content: block.text,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    block.text.trimRight(),
                    style: TextStyle(
                      color: fc.textSecondary,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final suggested = 'agent_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}.nc';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le programme',
      fileName: suggested,
      type: FileType.custom,
      allowedExtensions: ['nc', 'gcode', 'ngc', 'tap'],
    );
    if (path == null) return; // annulé
    try {
      await File(path).writeAsString(block.text);
    } catch (e) {
      if (!context.mounted) return;
      await fluent.displayInfoBar(context, builder: (ctx, close) {
        return fluent.InfoBar(
          title: const Text('Écriture impossible'),
          content: Text('$e'),
          severity: fluent.InfoBarSeverity.error,
          onClose: close,
        );
      });
    }
  }
}

// ═══════════════════════════ Barres d'état ═════════════════════════════════

class _ConfirmationBar extends ConsumerWidget {
  const _ConfirmationBar({required this.fc, required this.pending});

  final ForgeronColorPalette fc;
  final AiPendingToolCall pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiAgentControllerProvider.notifier);
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fc.warning.withValues(alpha: .08),
        border: Border.all(color: fc.warning.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(fluent.FluentIcons.warning, color: fc.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirmation requise : ${friendlyToolLabel(pending.toolName)}',
                  style: TextStyle(
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                if (pending.input.isNotEmpty)
                  Text(
                    pending.input.entries
                        .map((e) => '${e.key} : ${e.value}')
                        .join('   '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fc.textSecondary,
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          fluent.Button(
            onPressed: controller.rejectPendingAction,
            child: const Text('Refuser'),
          ),
          const SizedBox(width: 8),
          fluent.FilledButton(
            onPressed: controller.confirmPendingAction,
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

/// Erreur, avec le renvoi manuel quand l'action est rejouable — sur mobile ce
/// bouton existait, ici l'échec était une impasse.
class _ErrorBar extends ConsumerWidget {
  const _ErrorBar({required this.fc, required this.chat});

  final ForgeronColorPalette fc;
  final AiChatState chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fc.danger.withValues(alpha: .1),
        border: Border.all(color: fc.danger.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(chat.error ?? '',
                style: TextStyle(color: fc.danger, fontSize: 12.5)),
          ),
          if (chat.awaitingNetwork)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text('reprise automatique armée',
                  style: TextStyle(color: fc.textDisabled, fontSize: 10.5)),
            ),
          if (chat.retryable) ...[
            const SizedBox(width: 10),
            fluent.Button(
              onPressed: () =>
                  ref.read(aiAgentControllerProvider.notifier).retryNow(),
              child: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════ Barre de saisie ══════════════════════════════

class _Composer extends StatelessWidget {
  const _Composer({
    required this.fc,
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.onAttachStep,
    required this.onAttachImage,
    required this.pendingImage,
    required this.onRemoveImage,
    required this.listening,
    required this.onToggleListen,
  });

  final ForgeronColorPalette fc;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttachStep;
  final VoidCallback onAttachImage;
  final Uint8List? pendingImage;
  final VoidCallback onRemoveImage;
  final bool listening;
  final VoidCallback onToggleListen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: fc.surfaceBright,
          border: Border.all(
              color: listening ? fc.danger.withValues(alpha: .5) : fc.surfaceBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(pendingImage!,
                          width: 44, height: 44, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Text('Image jointe',
                        style: TextStyle(color: fc.textSecondary, fontSize: 12)),
                    const SizedBox(width: 4),
                    fluent.IconButton(
                      icon: Icon(Icons.close, color: fc.textDisabled, size: 15),
                      onPressed: onRemoveImage,
                    ),
                  ],
                ),
              ),
            // Le champ seul en haut, les commandes dessous : le texte n'est
            // pas comprimé entre six boutons.
            fluent.TextBox(
              controller: controller,
              placeholder: listening
                  ? 'Dictée en cours…'
                  : 'Demander une action ou une analyse à l\'agent…',
              minLines: 1,
              maxLines: 6,
              decoration: WidgetStatePropertyAll(BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.transparent),
              )),
              onSubmitted: (_) => onSend(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                fluent.Tooltip(
                  message: 'Charger une pièce (fichier STEP)',
                  child: fluent.IconButton(
                    icon: Icon(fluent.FluentIcons.attach,
                        color: fc.textSecondary, size: 16),
                    onPressed: onAttachStep,
                  ),
                ),
                fluent.Tooltip(
                  message: 'Joindre une image',
                  child: fluent.IconButton(
                    icon: Icon(Icons.image_outlined, color: fc.textSecondary, size: 17),
                    onPressed: onAttachImage,
                  ),
                ),
                fluent.Tooltip(
                  message: listening ? 'Arrêter la dictée' : 'Dicter',
                  child: fluent.IconButton(
                    icon: Icon(
                      listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: listening ? fc.danger : fc.textSecondary,
                      size: 17,
                    ),
                    onPressed: onToggleListen,
                  ),
                ),
                const Spacer(),
                busy
                    ? fluent.Tooltip(
                        message: 'Interrompre',
                        child: fluent.IconButton(
                          icon: Icon(Icons.stop_circle_outlined,
                              color: fc.danger, size: 20),
                          onPressed: onStop,
                        ),
                      )
                    : fluent.FilledButton(
                        onPressed: onSend,
                        child: const Icon(fluent.FluentIcons.send, size: 15),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ Rail des aperçus 3D ═════════════════════════════

/// Colonne de droite : ce que la discussion a produit de visualisable.
///
/// C'est la réponse au vrai manque de la version précédente — le pipeline
/// fabriquait une pièce et un parcours d'outil que rien ne montrait. Chaque
/// carte ouvre sa propre fenêtre OS : un cadre fixe et plein, le seul endroit
/// où un contrôle WebView natif tient correctement (voir `ai_viewer_windows.dart`).
class _ArtifactsRail extends ConsumerWidget {
  const _ArtifactsRail({required this.fc, required this.onPickStep});

  final ForgeronColorPalette fc;
  final VoidCallback onPickStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artifacts = ref.watch(aiArtifactsProvider);
    final docked = artifacts.docked != AiDockedViewer.none;
    return Container(
      // Le rail s'élargit quand il héberge une vue 3D : 276 px suffisent à des
      // fiches, pas à une pièce.
      width: docked ? 430 : 276,
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        border: Border(left: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                Icon(Icons.view_in_ar_rounded, size: 15, color: fc.secondary),
                const SizedBox(width: 8),
                Text(
                  'APERÇUS 3D',
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .9,
                  ),
                ),
              ],
            ),
          ),
          if (docked) _DockedViewer(fc: fc, artifacts: artifacts),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _StepCard(fc: fc, step: artifacts.step, onPickStep: onPickStep),
                const SizedBox(height: 12),
                _ToolpathCard(fc: fc, gcode: artifacts.gcode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// L'aperçu 3D logé dans la fenêtre principale.
///
/// Un cadre FIXE : hauteur constante, hors de toute liste défilante, sans
/// animation d'ouverture. Ce n'est pas une préférence esthétique — c'est la
/// condition pour qu'un contrôle WebView natif tienne. Le premier essai le
/// nichait dans un `Expander` animé au sein du fil : découpé au clip,
/// redimensionné à chaque image, il n'émettait jamais son signal « prêt ».
class _DockedViewer extends ConsumerWidget {
  const _DockedViewer({required this.fc, required this.artifacts});

  final ForgeronColorPalette fc;
  final AiArtifacts artifacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiArtifactsProvider.notifier);
    final isStep = artifacts.docked == AiDockedViewer.step;
    final title = isStep
        ? (artifacts.step?.fileName ?? 'Pièce')
        : (artifacts.gcode?.fileName ?? 'Parcours d\'outil');

    return Container(
      height: 330,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              color: fc.surface,
              border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                Icon(
                  isStep ? Icons.category_outlined : Icons.timeline_rounded,
                  size: 13,
                  color: fc.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                fluent.Tooltip(
                  message: 'Détacher dans une fenêtre',
                  child: fluent.IconButton(
                    icon: Icon(Icons.open_in_new_rounded,
                        size: 14, color: fc.textSecondary),
                    onPressed: () {
                      notifier.undock();
                      if (isStep) {
                        final preview = artifacts.step?.preview;
                        if (preview == null) return;
                        AiWindowLauncher.openStepPreview(
                          title: 'Aperçu — ${artifacts.step!.fileName}',
                          mesh: preview.mesh,
                          info: {
                            'encombrement': preview.sizeLabel,
                            'volume': '${preview.volume.toStringAsFixed(0)} mm³',
                            'triangles': preview.triangles,
                          },
                        );
                      } else {
                        final gcode = artifacts.gcode;
                        if (gcode == null) return;
                        AiWindowLauncher.openToolpath(
                          title: 'Parcours — ${gcode.fileName}',
                          gcodePath: gcode.path,
                        );
                      }
                    },
                  ),
                ),
                fluent.Tooltip(
                  message: 'Fermer l\'aperçu',
                  child: fluent.IconButton(
                    icon: Icon(Icons.close_rounded, size: 14, color: fc.textDisabled),
                    onPressed: notifier.undock,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: fc.background,
              child: isStep
                  ? TrunnionVisualizer(
                      mPos: const [0, 0, 0, 0, 0],
                      partMesh: artifacts.step?.preview?.mesh,
                      scene: ViewerScene.partOnly,
                    )
                  : _DockedToolpath(fc: fc, path: artifacts.gcode?.path),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le parcours logé dans la fenêtre principale.
///
/// Il charge le programme dans le `gcodeProvider` de CETTE portée — donc celui
/// de l'écran principal. C'est voulu ici, contrairement à la fenêtre détachée
/// qui a la sienne : afficher un parcours dans la fenêtre principale, c'est
/// justement l'ouvrir dans l'espace de travail.
class _DockedToolpath extends ConsumerStatefulWidget {
  const _DockedToolpath({required this.fc, required this.path});

  final ForgeronColorPalette fc;
  final String? path;

  @override
  ConsumerState<_DockedToolpath> createState() => _DockedToolpathState();
}

class _DockedToolpathState extends ConsumerState<_DockedToolpath> {
  String? _error;
  String? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DockedToolpath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final path = widget.path;
    if (path == null || path == _loaded) return;
    try {
      final content = await File(path).readAsString();
      await ref.read(gcodeProvider.notifier).loadFile(content);
      if (mounted) setState(() => _loaded = path);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('Parcours illisible : $_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: widget.fc.danger, fontSize: 11.5)),
        ),
      );
    }
    if (_loaded == null) {
      return const Center(child: fluent.ProgressRing());
    }
    return TrunnionVisualizer(
      mPos: const [0, 0, 0, 0, 0],
      toolpath: ref.watch(renderToolpathProvider),
      scene: ViewerScene.toolpathOnly,
    );
  }
}

/// Coque commune des cartes d'aperçu.
class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({
    required this.fc,
    required this.title,
    required this.icon,
    required this.children,
  });

  final ForgeronColorPalette fc;
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border.all(color: fc.surfaceBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: fc.textSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _StepCard extends ConsumerWidget {
  const _StepCard({required this.fc, required this.step, required this.onPickStep});

  final ForgeronColorPalette fc;
  final StepArtifact? step;
  final VoidCallback onPickStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = step;
    return _ArtifactCard(
      fc: fc,
      title: 'Pièce',
      icon: Icons.category_outlined,
      children: [
        if (s == null) ...[
          Text(
            'Aucune pièce chargée.',
            style: TextStyle(color: fc.textDisabled, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          fluent.Button(
            onPressed: onPickStep,
            child: const Text('Charger un STEP'),
          ),
        ] else ...[
          Text(
            s.fileName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: fc.textSecondary, fontSize: 11, fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: 8),
          if (s.loading)
            Row(
              children: [
                SizedBox(
                    width: 12,
                    height: 12,
                    child: fluent.ProgressRing(strokeWidth: 1.6)),
                const SizedBox(width: 8),
                Text('Préparation de l\'aperçu…',
                    style: TextStyle(color: fc.textDisabled, fontSize: 11)),
              ],
            )
          else if (s.error != null)
            Text(
              s.error!,
              style: TextStyle(color: fc.danger, fontSize: 10.5, height: 1.4),
            )
          else if (s.preview != null) ...[
            _kv(fc, 'encombrement', s.preview!.sizeLabel),
            _kv(fc, 'volume', '${s.preview!.volume.toStringAsFixed(0)} mm³'),
            _kv(fc, 'triangles', '${s.preview!.triangles}'),
            const SizedBox(height: 10),
            _ViewerActions(
              fc: fc,
              onDock: () =>
                  ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.step),
              onDetach: () => AiWindowLauncher.openStepPreview(
                title: 'Aperçu — ${s.fileName}',
                mesh: s.preview!.mesh,
                info: {
                  'encombrement': s.preview!.sizeLabel,
                  'volume': '${s.preview!.volume.toStringAsFixed(0)} mm³',
                  'triangles': s.preview!.triangles,
                },
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ToolpathCard extends ConsumerWidget {
  const _ToolpathCard({required this.fc, required this.gcode});

  final ForgeronColorPalette fc;
  final GcodeArtifact? gcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = gcode;
    return _ArtifactCard(
      fc: fc,
      title: 'Parcours d\'outil',
      icon: Icons.timeline_rounded,
      children: [
        if (g == null)
          Text(
            'Disponible dès que l\'agent aura généré un programme.',
            style: TextStyle(color: fc.textDisabled, fontSize: 11.5, height: 1.4),
          )
        else ...[
          Text(
            g.fileName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: fc.textSecondary, fontSize: 11, fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: 8),
          if (g.lines != null) _kv(fc, 'lignes', '${g.lines}'),
          if (g.operations != null) _kv(fc, 'opérations', '${g.operations}'),
          const SizedBox(height: 10),
          _ViewerActions(
            fc: fc,
            onDock: () =>
                ref.read(aiArtifactsProvider.notifier).dock(AiDockedViewer.toolpath),
            onDetach: () => AiWindowLauncher.openToolpath(
              title: 'Parcours — ${g.fileName}',
              gcodePath: g.path,
            ),
          ),
        ],
      ],
    );
  }
}

/// Les deux façons de regarder un aperçu : ici, ou dans sa propre fenêtre.
///
/// Les deux existent parce qu'aucune ne convient toujours : sur un seul écran
/// une fenêtre détachée recouvre la discussion, sur deux écrans elle est
/// exactement ce qu'il faut. Le trajet se fait dans les deux sens — la fenêtre
/// détachée porte le bouton du retour.
class _ViewerActions extends StatelessWidget {
  const _ViewerActions({
    required this.fc,
    required this.onDock,
    required this.onDetach,
  });

  final ForgeronColorPalette fc;
  final VoidCallback onDock;
  final VoidCallback onDetach;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: fluent.FilledButton(
            onPressed: onDock,
            child: const Text('Afficher ici', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 6),
        fluent.Tooltip(
          message: 'Ouvrir dans une fenêtre séparée',
          child: fluent.Button(
            onPressed: onDetach,
            style: const fluent.ButtonStyle(
              padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
            child: Icon(Icons.open_in_new_rounded, size: 14, color: fc.textSecondary),
          ),
        ),
      ],
    );
  }
}

Widget _kv(ForgeronColorPalette fc, String label, String value) {
  if (value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: fc.textDisabled, fontSize: 10.5)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
              color: fc.lcdText, fontSize: 10.5, fontFamily: 'JetBrainsMono'),
        ),
      ],
    ),
  );
}

// ════════════════════════════ Écran d'accueil ══════════════════════════════

/// Premier lancement d'une discussion : sans ça, l'agent IA ressemble à un
/// chat comme un autre — rien ne dit qu'il sait piloter le pipeline
/// STEP → G-code, ni ce qu'on peut lui demander.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.fc,
    required this.onPickStep,
    required this.onAsk,
  });

  final ForgeronColorPalette fc;
  final VoidCallback onPickStep;
  final ValueChanged<String> onAsk;

  static const _suggestions = [
    'Quel est l\'état de la machine ?',
    'Analyse le programme chargé et signale les risques.',
    'Fais un diagnostic complet avant usinage.',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fc.primary.withValues(alpha: .12),
                  border: Border.all(color: fc.primary.withValues(alpha: .35)),
                ),
                child: Icon(Icons.auto_awesome, color: fc.primary, size: 23),
              ),
              const SizedBox(height: 16),
              Text(
                'Du fichier STEP au G-code',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: fc.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Charge une pièce : l\'agent l\'analyse, génère le programme et '
                'ouvre l\'aperçu 3D. Chaque étape s\'affiche ici pendant qu\'elle '
                'se fait.',
                textAlign: TextAlign.center,
                style: TextStyle(color: fc.textSecondary, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 20),
              fluent.FilledButton(
                onPressed: onPickStep,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Charger un fichier STEP'),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'OU DEMANDE-LUI',
                style: TextStyle(
                  color: fc.textDisabled,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              for (final s in _suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: fluent.Button(
                      onPressed: () => onAsk(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(s, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
