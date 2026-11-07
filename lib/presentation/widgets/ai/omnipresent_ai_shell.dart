import 'package:forgeron/application/providers/ai_prompt_draft_provider.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../application/providers/ai_agent_provider.dart';
import '../../../application/providers/ai_artifacts_provider.dart';
import '../../../application/providers/ai_inbox_provider.dart';
import '../../../application/providers/controller_memory_provider.dart';
import '../../../application/providers/di_providers.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import 'translation_note.dart';
import '../../../core/i18n/waxal_voice_engine.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../core/utils/chat_markdown.dart';
import '../../../core/utils/voice_locale.dart';
import '../../screens/desktop/ai_console_timeline.dart' show friendlyToolLabel;

/// Modes d'ancrage de la fenêtre **Forgeron IA**.
enum AiDockMode {
  /// Fenêtre flottante déplaçable librement.
  floating,

  /// Panneau ancré en bas de l'écran courant.
  bottom,

  /// Panneau latéral ancré à droite de l'écran courant.
  right,
}

class AiDockState {
  final AiDockMode mode;
  final bool isOpen;
  final Offset floatingOffset;
  final double rightWidth;
  final double bottomHeight;

  const AiDockState({
    this.mode = AiDockMode.floating,
    this.isOpen = false,
    this.floatingOffset = const Offset(28, 72),
    this.rightWidth = 390,
    this.bottomHeight = 310,
  });

  AiDockState copyWith({
    AiDockMode? mode,
    bool? isOpen,
    Offset? floatingOffset,
    double? rightWidth,
    double? bottomHeight,
  }) {
    return AiDockState(
      mode: mode ?? this.mode,
      isOpen: isOpen ?? this.isOpen,
      floatingOffset: floatingOffset ?? this.floatingOffset,
      rightWidth: rightWidth ?? this.rightWidth,
      bottomHeight: bottomHeight ?? this.bottomHeight,
    );
  }
}

class AiDockNotifier extends StateNotifier<AiDockState> {
  AiDockNotifier() : super(const AiDockState());

  void toggleOpen() => state = state.copyWith(isOpen: !state.isOpen);
  void open() => state = state.copyWith(isOpen: true);
  void close() => state = state.copyWith(isOpen: false);

  void setMode(AiDockMode mode) =>
      state = state.copyWith(mode: mode, isOpen: true);

  void updateFloatingOffset(Offset delta, Size bounds) {
    final nextX = (state.floatingOffset.dx + delta.dx)
        .clamp(12.0, (bounds.width - 392).clamp(12.0, 2400.0));
    final nextY = (state.floatingOffset.dy + delta.dy)
        .clamp(12.0, (bounds.height - 460).clamp(12.0, 2400.0));
    state = state.copyWith(floatingOffset: Offset(nextX, nextY));
  }
}

final aiDockProvider =
    StateNotifierProvider<AiDockNotifier, AiDockState>((ref) => AiDockNotifier());

/// Enveloppe rendant **Forgeron IA** accessible depuis les écrans métier
/// (Tableau de bord, Palpage, Outils, Espace de travail, MDI, Diagnostics)
/// en mode flottant, bas ou droite.
///
/// Automatiquement masquée sur la page **Agent IA** ([hideOverlay] = `true`),
/// puisqu'il s'agit de la même discussion.
class OmnipresentAiShell extends ConsumerStatefulWidget {
  final Widget child;
  final bool isMobile;

  /// `true` lorsque l'écran actif est déjà la page Agent IA : ni la fenêtre
  /// secondaire ni le bouton flottant ne doivent alors s'afficher.
  final bool hideOverlay;
  final void Function(int screenIndex)? onNavigateToScreen;

  const OmnipresentAiShell({
    super.key,
    required this.child,
    this.isMobile = false,
    this.hideOverlay = false,
    this.onNavigateToScreen,
  });

  @override
  ConsumerState<OmnipresentAiShell> createState() => _OmnipresentAiShellState();
}

class _OmnipresentAiShellState extends ConsumerState<OmnipresentAiShell> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _lastSeenRebootCount = 0;
  int? _lastSeenAlarmCode;

  // Défilement automatique et détection "Revenir en bas"
  bool _atBottom = true;

  // Multimodal & Pièces jointes
  Uint8List? _pendingImage;
  String? _pendingImageMime;
  String? _pendingFilePath;
  String? _pendingFileName;

  // Audio (STT & TTS — propulsé par WaxalVoiceEngine)
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _listening = false;
  String? _sttLocaleId;
  List<String> _availableTtsVoices = const [];

  @override
  void initState() {
    super.initState();
    final initialDraft = ref.read(aiPromptDraftProvider);
    if (initialDraft.isNotEmpty) {
      _inputCtrl.text = initialDraft;
    }
    _inputCtrl.addListener(_onInputChanged);
    _scrollCtrl.addListener(_onScroll);
    _tts.setSpeechRate(0.5);
    _applyVoiceLanguage();
  }

  void _onInputChanged() {
    ref.read(aiPromptDraftProvider.notifier).updateDraft(_inputCtrl.text);
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onInputChanged);
    _scrollCtrl.removeListener(_onScroll);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 60;
    if (atBottom != _atBottom && mounted) {
      setState(() => _atBottom = atBottom);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Saut instantané au dernier message (utilisé dès l'ouverture).
  void _snapToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        if (mounted) setState(() => _atBottom = true);
      }
    });
  }

  String get _wantedVoiceTag {
    final language = ref.read(effectiveAiLanguageProvider);
    if (!language.isAuto) return language.voiceTag;
    return WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
  }

  Future<void> _applyVoiceLanguage() async {
    _sttLocaleId = null;
    try {
      final raw = await _tts.getLanguages;
      _availableTtsVoices =
          (raw as List).map((e) => e.toString()).toList(growable: false);
      final match = bestVoiceLocale(
        _wantedVoiceTag,
        _availableTtsVoices,
        fallbacks: const ['fr-FR', 'en-US'],
      );
      if (match != null) await _tts.setLanguage(match);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    final lang = ref.read(effectiveAiLanguageProvider);
    if (_availableTtsVoices.isEmpty) {
      try {
        final raw = await _tts.getLanguages;
        _availableTtsVoices =
            (raw as List).map((e) => e.toString()).toList(growable: false);
      } catch (_) {}
    }
    final prep = WaxalVoiceEngine.prepareForTts(
      text,
      preferredLanguageId: lang.id,
      availableVoices: _availableTtsVoices,
    );
    if (prep.spokenText.isEmpty) return;
    await _tts.stop();
    try {
      if (prep.selectedVoiceLocale != null) {
        await _tts.setLanguage(prep.selectedVoiceLocale!);
      }
      await _tts.setSpeechRate(prep.speechRate);
    } catch (_) {}
    await _tts.speak(prep.spokenText);
  }

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
    if (!ok) return;
    setState(() => _listening = true);
    try {
      _sttLocaleId ??= bestVoiceLocale(
        _wantedVoiceTag,
        (await _speech.locales()).map((l) => l.localeId),
        fallbacks: const ['fr-FR', 'en-US'],
      );
      final lang = ref.read(effectiveAiLanguageProvider);
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) {
          if (!mounted) return;
          final normalized = WaxalVoiceEngine.normalizeSttInput(
            r.recognizedWords,
            activeLanguageId: lang.id,
          );
          setState(() => _inputCtrl.text = normalized);
          ref.read(aiPromptDraftProvider.notifier).updateDraft(normalized);
        },
        listenOptions: SpeechListenOptions(
          localeId: _sttLocaleId,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) return;
      if (!mounted) return;
      setState(() {
        _pendingImage = bytes;
        _pendingImageMime = _mimeFromName(file.name);
      });
    } catch (_) {}
  }

  static String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['step', 'stp', 'stl', 'nc', 'gcode', 'ngc', 'tap'],
        dialogTitle: tr('Charger une pièce ou un programme'),
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final name = result!.files.single.name;
      ref.read(aiArtifactsProvider.notifier).pickNewPart(path);
      if (!mounted) return;
      setState(() {
        _pendingFilePath = path;
        _pendingFileName = name;
      });
    } catch (_) {}
  }

  Future<void> _sendPrompt(String text) async {
    var trimmed = text.trim();
    if (trimmed.isEmpty && _pendingImage == null && _pendingFilePath == null) {
      return;
    }

    if (_pendingFilePath != null && _pendingFileName != null) {
      if (trimmed.isEmpty) {
        trimmed =
            'Charge et analyse ce fichier ($_pendingFileName) : $_pendingFilePath';
      } else {
        trimmed =
            '$trimmed\n\nFichier associé ($_pendingFileName) : $_pendingFilePath';
      }
    }

    _inputCtrl.clear();
    ref.read(aiPromptDraftProvider.notifier).clear();
    final image = _pendingImage;
    final mime = _pendingImageMime;

    setState(() {
      _pendingImage = null;
      _pendingImageMime = null;
      _pendingFilePath = null;
      _pendingFileName = null;
      _atBottom = true;
    });

    if (!widget.hideOverlay) {
      ref.read(aiDockProvider.notifier).open();
    }
    await ref.read(aiAgentControllerProvider.notifier).sendUserMessage(
          trimmed,
          imageBytes: image,
          imageMime: mime,
        );
    _scrollToBottom();
  }

  Future<void> _executeSuggestion(SuggestedNextAction s) async {
    if (!widget.hideOverlay) {
      ref.read(aiDockProvider.notifier).open();
    }
    if (s.directGcode != null && s.directGcode!.isNotEmpty) {
      try {
        await ref.read(machineRepositoryProvider).sendGCode(s.directGcode!);
      } catch (_) {}
    }
    await _sendPrompt(s.prompt);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(aiPromptDraftProvider, (previous, next) {
      if (_inputCtrl.text != next) {
        _inputCtrl.value = _inputCtrl.value.copyWith(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
          composing: TextRange.empty,
        );
      }
    });
    // Alarme GRBL ou redémarrage ESP32 en direct : consigne l'alerte dans le
    // fil et n'ouvre le panneau secondaire que si l'opérateur n'est pas déjà
    // sur la page Agent IA.
    ref.listen<ControllerMemoryState>(controllerMemoryProvider, (prev, next) {
      final newReboot = next.esp32RebootCount > _lastSeenRebootCount;
      final newAlarm = next.activeDiagnosis?.alarmCode != null &&
          next.activeDiagnosis?.alarmCode != _lastSeenAlarmCode;

      if (newReboot || newAlarm) {
        _lastSeenRebootCount = next.esp32RebootCount;
        _lastSeenAlarmCode = next.activeDiagnosis?.alarmCode;
        if (!widget.hideOverlay) {
          ref.read(aiDockProvider.notifier).open();
          ref.read(aiInboxProvider.notifier).markRead();
          _snapToEnd();
        }

        final diag = next.activeDiagnosis;
        if (diag != null) {
          ref
              .read(aiAgentControllerProvider.notifier)
              .postProactiveAssistantMessage(
                '**${diag.headline}**\n\n'
                '- **Cause probable** : ${diag.probableHardwareCause}\n'
                '- **Entrée / broche** : ${diag.gpioPinDetail}\n'
                '- **À faire** : ${diag.immediateOperatorSteps}',
              );
          _scrollToBottom();
        }
      } else if (next.activeDiagnosis == null) {
        _lastSeenAlarmCode = null;
      }
    });

    // Dès l'ouverture de la fenêtre IA : se positionner immédiatement sur le dernier message
    ref.listen<AiDockState>(aiDockProvider, (prev, next) {
      if (prev?.isOpen != true && next.isOpen) {
        _snapToEnd();
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted) _snapToEnd();
        });
      }
    });

    // Écoute de l'agent IA : scroll automatique si on était en bas, lecture TTS
    ref.listen<AiChatState>(aiAgentControllerProvider, (prev, next) {
      final msgChanged = prev?.messages.length != next.messages.length;
      final streamChanged = prev?.streamingText != next.streamingText;
      if (msgChanged || streamChanged) {
        if (_atBottom) {
          _scrollToBottom();
        }
      }
      final grew = (prev?.messages.length ?? 0) < next.messages.length;
      if (grew && next.messages.isNotEmpty) {
        final last = next.messages.last;
        if (last.role == 'assistant' && ref.read(aiTtsEnabledProvider)) {
          _speak(last.text);
        }
      }
    });

    ref.listen<bool>(aiTtsEnabledProvider, (prev, next) {
      if (next == false) _tts.stop();
    });

    ref.listen<AppLanguage>(effectiveAiLanguageProvider, (prev, next) {
      if (prev?.id != next.id) _applyVoiceLanguage();
    });

    // Sur la page Agent IA, on n'affiche jamais de seconde fenêtre IA.
    if (widget.hideOverlay) {
      return widget.child;
    }

    final fc = context.fc;
    final dock = ref.watch(aiDockProvider);
    final memory = ref.watch(controllerMemoryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final effectiveMode = widget.isMobile && dock.mode == AiDockMode.right
            ? AiDockMode.bottom
            : dock.mode;

        return Stack(
          children: [
            // ── Disposition principale selon le mode d'ancrage ────────────
            if (dock.isOpen && effectiveMode == AiDockMode.right)
              Row(
                children: [
                  Expanded(child: widget.child),
                  Container(
                    width: dock.rightWidth.clamp(320.0, size.width * 0.45),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: fc.surfaceBorder),
                      ),
                    ),
                    child: _buildChatPanel(context, fc, memory, effectiveMode),
                  ),
                ],
              )
            else if (dock.isOpen && effectiveMode == AiDockMode.bottom)
              Column(
                children: [
                  Expanded(child: widget.child),
                  Container(
                    height: dock.bottomHeight.clamp(220.0, size.height * 0.52),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: fc.surfaceBorder),
                      ),
                    ),
                    child: _buildChatPanel(context, fc, memory, effectiveMode),
                  ),
                ],
              )
            else
              widget.child,

            // ── Mode Flottant déplaçable ─────────────────────────────────
            if (dock.isOpen && effectiveMode == AiDockMode.floating)
              Positioned(
                left: dock.floatingOffset.dx
                    .clamp(12.0, (size.width - 392).clamp(12.0, 2400.0)),
                top: dock.floatingOffset.dy
                    .clamp(12.0, (size.height - 460).clamp(12.0, 2400.0)),
                width: widget.isMobile
                    ? (size.width - 24).clamp(280.0, 410.0)
                    : 380,
                height: widget.isMobile
                    ? 420
                    : 480.0.clamp(300.0, (size.height - 24).clamp(300.0, 560.0)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildChatPanel(
                      context,
                      fc,
                      memory,
                      effectiveMode,
                      onDragUpdate: (d) => ref
                          .read(aiDockProvider.notifier)
                          .updateFloatingOffset(d.delta, size),
                    ),
                  ),
                ),
              ),

            // ── Bouton replié d'accès rapide « Forgeron IA » ─────────────
            if (!dock.isOpen)
              Positioned(
                right: 16,
                bottom: widget.isMobile ? 74 : 16,
                child: _buildCollapsedLauncher(fc, memory),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCollapsedLauncher(
      ForgeronColorPalette fc, ControllerMemoryState memory) {
    final hasAlert = memory.activeDiagnosis != null;
    final unread = ref.watch(aiInboxProvider).unread;

    final bgColor = hasAlert ? fc.danger : fc.surfaceBright;
    final fgColor = hasAlert ? Colors.white : fc.textPrimary;
    final borderColor =
        hasAlert ? fc.danger : fc.primary.withValues(alpha: 0.45);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          ref.read(aiInboxProvider.notifier).markRead();
          ref.read(aiDockProvider.notifier).open();
          _snapToEnd();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (hasAlert ? fc.danger : Colors.black)
                    .withValues(alpha: hasAlert ? 0.35 : 0.22),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasAlert
                      ? null
                      : LinearGradient(
                          colors: [fc.primaryLight, fc.primary, fc.primaryDim],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: hasAlert ? Colors.white.withValues(alpha: 0.2) : null,
                ),
                child: Icon(
                  hasAlert
                      ? Icons.warning_amber_rounded
                      : Icons.auto_awesome,
                  color: hasAlert ? Colors.white : fc.background,
                  size: 14,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                hasAlert ? tr('Alerte machine') : 'Forgeron IA',
                style: TextStyle(
                  color: fgColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasAlert ? Colors.white : fc.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: TextStyle(
                      color: hasAlert ? fc.danger : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPanel(
    BuildContext context,
    ForgeronColorPalette fc,
    ControllerMemoryState memory,
    AiDockMode currentMode, {
    void Function(DragUpdateDetails)? onDragUpdate,
  }) {
    final chat = ref.watch(aiAgentControllerProvider);
    final uiLang = ref.watch(appLanguageProvider);
    final ttsOn = ref.watch(aiTtsEnabledProvider);
    final diag = memory.activeDiagnosis;
    final streaming =
        chat.streamingText != null && chat.streamingText!.isNotEmpty;
    final thinking =
        chat.isProcessing && chat.pendingConfirmation == null && !streaming;

    return Material(
      color: fc.background,
      child: Container(
        decoration: BoxDecoration(
          color: fc.background,
          border: currentMode == AiDockMode.floating
              ? Border.all(color: fc.surfaceBorder)
              : null,
          borderRadius: currentMode == AiDockMode.floating
              ? BorderRadius.circular(12)
              : null,
        ),
        child: Column(
          children: [
            // ── 1. En-tête Forgeron IA (glissable en mode flottant) ──────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: onDragUpdate,
              child: MouseRegion(
                cursor: onDragUpdate != null
                    ? SystemMouseCursors.move
                    : MouseCursor.defer,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: fc.surfaceBright,
                    border: Border(
                      bottom: BorderSide(color: fc.surfaceBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              fc.primaryLight,
                              fc.primary,
                              fc.primaryDim,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.auto_awesome,
                            size: 13, color: fc.background),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Forgeron IA',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: fc.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (memory.esp32RebootCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: fc.danger.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: fc.danger.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      'ESP32 ×${memory.esp32RebootCount}',
                                      style: TextStyle(
                                        color: fc.danger,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              tr(memory.activeWindowName.toUpperCase()).isNotEmpty &&
                                      tr(memory.activeWindowName.toUpperCase()) !=
                                          memory.activeWindowName.toUpperCase()
                                  ? tr(memory.activeWindowName.toUpperCase())
                                  : tr(memory.activeWindowName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fc.textDisabled,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bouton Lecture vocale (TTS)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: ttsOn
                            ? tr('Lecture vocale activée')
                            : tr('Lecture vocale'),
                        icon: Icon(
                          ttsOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: ttsOn ? fc.primary : fc.textSecondary,
                          size: 16,
                        ),
                        onPressed: () => ref
                            .read(aiTtsEnabledProvider.notifier)
                            .state = !ttsOn,
                      ),
                      const SizedBox(width: 2),

                      // Sélecteur discret de langue
                      PopupMenuButton<AppLanguage>(
                        tooltip: tr('Langue'),
                        color: fc.surface,
                        onSelected: (lang) {
                          ref.read(appLanguageProvider.notifier).select(lang);
                        },
                        itemBuilder: (_) => [
                          for (final l in kAppLanguages)
                            PopupMenuItem<AppLanguage>(
                              value: l,
                              child: Row(
                                children: [
                                  Icon(
                                    l.id == uiLang.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 15,
                                    color: l.id == uiLang.id
                                        ? fc.primary
                                        : fc.textDisabled,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l.label,
                                      style: TextStyle(
                                          color: fc.textPrimary, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: fc.surfaceHigh,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: fc.surfaceBorder),
                          ),
                          child: Text(
                            uiLang.id.toUpperCase(),
                            style: TextStyle(
                              color: fc.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // Bascule d'ancrage : Flottant | Bas | Droite
                      _buildDockModeIcon(
                        fc: fc,
                        mode: AiDockMode.floating,
                        active: currentMode == AiDockMode.floating,
                        icon: Icons.picture_in_picture_alt_rounded,
                        tooltip: tr('Fenêtre flottante'),
                      ),
                      _buildDockModeIcon(
                        fc: fc,
                        mode: AiDockMode.bottom,
                        active: currentMode == AiDockMode.bottom,
                        icon: Icons.dock_rounded,
                        tooltip: tr('Ancrer en bas'),
                      ),
                      if (!widget.isMobile)
                        _buildDockModeIcon(
                          fc: fc,
                          mode: AiDockMode.right,
                          active: currentMode == AiDockMode.right,
                          icon: Icons.vertical_split_rounded,
                          tooltip: tr('Ancrer à droite'),
                        ),
                      if (widget.onNavigateToScreen != null && !widget.isMobile)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          tooltip: tr('Ouvrir la page Agent IA'),
                          onPressed: () => widget.onNavigateToScreen!(6),
                          icon: Icon(
                            Icons.open_in_full_rounded,
                            color: fc.textSecondary,
                            size: 14,
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: tr('Fermer'),
                        onPressed: () =>
                            ref.read(aiDockProvider.notifier).close(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: fc.textSecondary,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Bandeau d'alerte matérielle (uniquement en cas d'alarme / reboot) ──
            if (diag != null) _buildLiveHardwareDiagnosisBanner(fc, diag),

            // ── 3. Fil de discussion avec bouton "Revenir en bas" ────────
            Expanded(
              child: chat.messages.isEmpty && !streaming && !thinking
                  ? _buildEmptyState(fc, memory)
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: chat.messages.length +
                              (streaming ? 1 : 0) +
                              (thinking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= chat.messages.length) {
                              if (streaming && index == chat.messages.length) {
                                return _buildAssistantMessage(
                                  fc,
                                  chat.streamingText!,
                                );
                              }
                              return _buildThinkingRow(fc, chat.runningTool);
                            }
                            return _buildMessageItem(fc, chat.messages[index]);
                          },
                        ),
                        // Bouton Flèche "Revenir en bas"
                        if (!_atBottom)
                          Positioned(
                            right: 14,
                            bottom: 10,
                            child: Tooltip(
                              message: tr('Revenir en bas'),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setState(() => _atBottom = true);
                                  _scrollToBottom();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: fc.surfaceHigh,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: fc.surfaceBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.28),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: fc.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // ── 4. Confirmation d'action / erreur éventuelle ─────────────
            if (chat.pendingConfirmation != null)
              _buildConfirmationBar(fc, chat.pendingConfirmation!),
            if (chat.error != null) _buildErrorBar(fc, chat),

            // ── 5. Pistes contextuelles discrètes (quand discussion déjà ouverte) ──
            if (chat.messages.isNotEmpty &&
                memory.nextSuggestions.isNotEmpty &&
                !chat.isProcessing)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: fc.surface,
                  border: Border(top: BorderSide(color: fc.surfaceBorder)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in memory.nextSuggestions)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _executeSuggestion(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: fc.surfaceBright,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: fc.surfaceBorder),
                              ),
                              child: Text(
                                s.localizedLabel,
                                style: TextStyle(
                                  color: fc.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── 6. Zone de saisie avec FilePicker, ImagePicker & Micro ────
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: fc.surface,
                border: Border(top: BorderSide(color: fc.surfaceBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Aperçu des pièces jointes en attente (Image ou Fichier STEP/G-code)
                  if (_pendingImage != null || _pendingFileName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (_pendingImage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: fc.surfaceBright,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: fc.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      _pendingImage!,
                                      width: 26,
                                      height: 26,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('Image jointe'),
                                    style: TextStyle(
                                      color: fc.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    onTap: () => setState(() {
                                      _pendingImage = null;
                                      _pendingImageMime = null;
                                    }),
                                    child: Icon(Icons.close_rounded,
                                        size: 15, color: fc.textDisabled),
                                  ),
                                ],
                              ),
                            ),
                          if (_pendingFileName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: fc.surfaceBright,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: fc.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.insert_drive_file_outlined,
                                      size: 15, color: fc.secondary),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      _pendingFileName!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: fc.textPrimary,
                                        fontSize: 11,
                                        fontFamily: 'JetBrainsMono',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    onTap: () => setState(() {
                                      _pendingFilePath = null;
                                      _pendingFileName = null;
                                    }),
                                    child: Icon(Icons.close_rounded,
                                        size: 15, color: fc.textDisabled),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      // Bouton FilePicker (STEP, STL, G-code)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: tr(
                            'Charger une pièce ou un programme (STEP, STL, NC)'),
                        icon: Icon(Icons.attach_file_rounded,
                            size: 18, color: fc.textSecondary),
                        onPressed: _pickFile,
                      ),

                      // Bouton ImagePicker (Photos, Captures d'usinage)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: tr('Joindre une image'),
                        icon: Icon(Icons.image_outlined,
                            size: 18, color: fc.textSecondary),
                        onPressed: _pickImage,
                      ),

                      // Bouton Dictée vocale (Micro STT)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: _listening
                            ? tr('Arrêter la dictée')
                            : tr('Dictée vocale'),
                        icon: Icon(
                          _listening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          size: 18,
                          color: _listening ? fc.danger : fc.textSecondary,
                        ),
                        onPressed: _toggleListen,
                      ),
                      const SizedBox(width: 4),

                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          style:
                              TextStyle(color: fc.textPrimary, fontSize: 12.5),
                          onSubmitted: _sendPrompt,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: _listening
                                ? tr('Dictée en cours…')
                                : tr('Écrire à Forgeron IA…'),
                            hintStyle:
                                TextStyle(color: fc.textDisabled, fontSize: 12),
                            filled: true,
                            fillColor: fc.surfaceBright,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.surfaceBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.surfaceBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fc.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      if (chat.isProcessing)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: tr('Interrompre'),
                          onPressed: () => ref
                              .read(aiAgentControllerProvider.notifier)
                              .stopGeneration(),
                          icon: Icon(Icons.stop_circle_outlined,
                              color: fc.danger, size: 20),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: tr('Envoyer'),
                          onPressed: () => _sendPrompt(_inputCtrl.text),
                          icon: Icon(Icons.send_rounded,
                              color: fc.primary, size: 19),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockModeIcon({
    required ForgeronColorPalette fc,
    required AiDockMode mode,
    required bool active,
    required IconData icon,
    required String tooltip,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: tooltip,
      onPressed: () => ref.read(aiDockProvider.notifier).setMode(mode),
      icon: Icon(
        icon,
        size: 15,
        color: active ? fc.primary : fc.textSecondary,
      ),
    );
  }

  Widget _buildLiveHardwareDiagnosisBanner(
      ForgeronColorPalette fc, dynamic diag) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fc.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fc.danger.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: fc.danger, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  diag.headline as String,
                  style: TextStyle(
                    color: fc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            diag.probableHardwareCause as String,
            style: TextStyle(color: fc.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            diag.gpioPinDetail as String,
            style: TextStyle(
              color: fc.primary,
              fontSize: 10.5,
              fontFamily: 'JetBrainsMono',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final act in (diag.quickActions as List))
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () async {
                    if (act.gcodeCommand != null) {
                      try {
                        await ref
                            .read(machineRepositoryProvider)
                            .sendGCode(act.gcodeCommand as String);
                      } catch (_) {}
                    }
                    if (act.aiFollowUpPrompt != null) {
                      await _sendPrompt(act.aiFollowUpPrompt as String);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: fc.surfaceBright,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: fc.surfaceBorder),
                    ),
                    child: Text(
                      act.label as String,
                      style: TextStyle(
                        color: fc.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      ForgeronColorPalette fc, ControllerMemoryState memory) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fc.primary.withValues(alpha: 0.12),
                border: Border.all(color: fc.primary.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.auto_awesome, color: fc.primary, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'Forgeron IA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fc.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Assistance usinage, programmes G-code et diagnostic machine depuis l\'écran en cours.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fc.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (memory.nextSuggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final s in memory.nextSuggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _executeSuggestion(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: fc.surfaceBright,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fc.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.localizedLabel,
                                style: TextStyle(
                                  color: fc.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: fc.textDisabled,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingRow(ForgeronColorPalette fc, String? runningTool) {
    final label = runningTool != null
        ? friendlyToolLabel(runningTool)
        : tr('Réflexion…');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: fc.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fc.textSecondary, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationBar(
      ForgeronColorPalette fc, AiPendingToolCall pending) {
    final controller = ref.read(aiAgentControllerProvider.notifier);
    final label = pending.lexicon?.label ??
        tr('Confirmer : {}', [friendlyToolLabel(pending.toolName)]);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fc.warning.withValues(alpha: 0.10),
        border: Border.all(color: fc.warning.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: fc.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fc.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.rejectPendingAction,
            child: Text(tr('Refuser'),
                style: TextStyle(color: fc.textSecondary, fontSize: 11.5)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: fc.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: controller.confirmPendingAction,
            child:
                Text(tr('Confirmer'), style: const TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBar(ForgeronColorPalette fc, AiChatState chat) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fc.danger.withValues(alpha: 0.10),
        border: Border.all(color: fc.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chat.error ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fc.danger, fontSize: 11.5),
            ),
          ),
          if (chat.retryable)
            TextButton(
              onPressed: () =>
                  ref.read(aiAgentControllerProvider.notifier).retryNow(),
              child: Text(tr('Réessayer'),
                  style: TextStyle(color: fc.primary, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ForgeronColorPalette fc, AiChatMessage m) {
    if (m.isTool) {
      final label = friendlyToolLabel(m.toolName ?? m.text);
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fc.surfaceBright,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fc.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(
              m.isRunningTool
                  ? Icons.sync_rounded
                  : (m.toolFailed
                      ? Icons.error_outline
                      : Icons.check_circle_outline),
              size: 13,
              color: m.toolFailed
                  ? fc.danger
                  : (m.isRunningTool ? fc.primary : fc.success),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fc.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (m.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.fromLTRB(36, 4, 0, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: fc.surfaceHigh,
            border: Border.all(color: fc.surfaceBorder),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.imageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 180, maxWidth: 260),
                      child: Image.memory(m.imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              SelectableText(
                m.text,
                style: TextStyle(
                  color: fc.textPrimary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildAssistantMessage(fc, m.text,
        interrupted: m.interrupted, sourceText: m.sourceText);
  }

  Widget _buildAssistantMessage(
    ForgeronColorPalette fc,
    String text, {
    bool interrupted = false,
    String? sourceText,
  }) {
    final codeStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 11.5,
      color: fc.secondary,
    );
    final blocks = parseChatBlocks(text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2, right: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fc.primary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.auto_awesome, size: 10, color: fc.primary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < blocks.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  if (blocks[i].isCode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: fc.terminalBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: fc.surfaceBorder),
                      ),
                      child: SelectableText(
                        blocks[i].text.trimRight(),
                        style: codeStyle,
                      ),
                    )
                  else
                    SelectableText.rich(
                      TextSpan(
                        style: TextStyle(
                          color: fc.textPrimary,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                        children: chatProseSpans(
                          blocks[i].text.trim(),
                          codeStyle: codeStyle,
                        ),
                      ),
                    ),
                ],
                if (sourceText != null)
                  TranslationNote(fc: fc, source: sourceText),
                if (interrupted)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tr('Réponse interrompue.'),
                      style: TextStyle(color: fc.warning, fontSize: 10.5),
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
