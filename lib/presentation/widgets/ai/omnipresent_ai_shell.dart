import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/ai_agent_provider.dart';
import '../../../application/providers/ai_inbox_provider.dart';
import '../../../application/providers/controller_memory_provider.dart';
import '../../../application/providers/di_providers.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/services/demo_benchmark_runner.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../domain/models/demo_benchmark_catalog.dart';
import '../../../domain/models/machine_state.dart';
import '../demo/feature_handson_modal.dart';

/// Modes d'ancrage du Chatbot Omniprésent de Forgeron.
enum AiDockMode {
  /// Fenêtre flottante déplaçable librement (HUD Picture-in-Picture).
  floating,

  /// Console ancrée en bas de l'écran courant.
  bottom,

  /// Panneau latéral ancré à droite de l'écran courant (Split-View).
  right,
}

class AiDockState {
  final AiDockMode mode;
  final bool isOpen;
  final Offset floatingOffset;
  final double rightWidth;
  final double bottomHeight;

  const AiDockState({
    this.mode = AiDockMode.right,
    this.isOpen = false,
    this.floatingOffset = const Offset(24, 80),
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
        .clamp(8.0, (bounds.width - 360).clamp(8.0, 2000.0));
    final nextY = (state.floatingOffset.dy + delta.dy)
        .clamp(8.0, (bounds.height - 420).clamp(8.0, 2000.0));
    state = state.copyWith(floatingOffset: Offset(nextX, nextY));
  }
}

final aiDockProvider =
    StateNotifierProvider<AiDockNotifier, AiDockState>((ref) => AiDockNotifier());

/// Enveloppe globale rendant le Chatbot IA (« Mémoire du Contrôleur »)
/// accessible depuis **n'importe quelle fenêtre** en mode Flottant, Bas ou Droite.
///
/// S'ouvre aussi automatiquement dès qu'une alarme GRBL (`ALARM:1..18`) ou un
/// redémarrage de la carte ESP32 (`Esp32RebootEvent`) est détecté en temps réel.
class OmnipresentAiShell extends ConsumerStatefulWidget {
  final Widget child;
  final bool isMobile;
  final void Function(int screenIndex)? onNavigateToScreen;

  const OmnipresentAiShell({
    super.key,
    required this.child,
    this.isMobile = false,
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

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPrompt(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputCtrl.clear();
    ref.read(aiDockProvider.notifier).open();
    await ref
        .read(aiAgentControllerProvider.notifier)
        .sendUserMessage(trimmed);
    _scrollToBottom();
  }

  Future<void> _executeSuggestion(SuggestedNextAction s) async {
    ref.read(aiDockProvider.notifier).open();
    if (s.demoSampleId != null) {
      final sample = DemoBenchmarkCatalog.sampleById(s.demoSampleId);
      if (sample != null) {
        await DemoBenchmarkRunner.runSample(ref, sample);
        _scrollToBottom();
        return;
      }
    }
    if (s.directGcode != null && s.directGcode!.isNotEmpty) {
      try {
        await ref.read(machineRepositoryProvider).sendGCode(s.directGcode!);
      } catch (_) {}
    }
    if (s.id == 'handson_tour' || s.id == 'start_handson_demo') {
      if (!mounted) return;
      await FeatureHandsOnModal.show(
        context,
        onNavigateToScreen: widget.onNavigateToScreen,
      );
      return;
    }
    await _sendPrompt(s.prompt);
  }

  @override
  Widget build(BuildContext context) {
    // Ouverture automatique du Chatbot sur toute fenêtre en cas d'Alarme ou de Reboot ESP32
    ref.listen<ControllerMemoryState>(controllerMemoryProvider, (prev, next) {
      final newReboot = next.esp32RebootCount > _lastSeenRebootCount;
      final newAlarm = next.activeDiagnosis?.alarmCode != null &&
          next.activeDiagnosis?.alarmCode != _lastSeenAlarmCode;

      if (newReboot || newAlarm) {
        _lastSeenRebootCount = next.esp32RebootCount;
        _lastSeenAlarmCode = next.activeDiagnosis?.alarmCode;
        ref.read(aiDockProvider.notifier).open();
        ref.read(aiInboxProvider.notifier).markRead();

        final diag = next.activeDiagnosis;
        if (diag != null) {
          ref
              .read(aiAgentControllerProvider.notifier)
              .postProactiveAssistantMessage(
                '🚨 **INTERPRÉTATION TEMPS RÉEL — ${diag.headline}**\n\n'
                '• **Cause matérielle identifiée** : ${diag.probableHardwareCause}\n'
                '• **Câblage GPIO ESP32 concerné** : ${diag.gpioPinDetail}\n'
                '• **Procédure immédiate** : ${diag.immediateOperatorSteps}',
              );
          _scrollToBottom();
        }
      } else if (next.activeDiagnosis == null) {
        _lastSeenAlarmCode = null;
      }
    });

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
                    width: dock.rightWidth.clamp(320.0, size.width * 0.48),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFF1E293B), width: 1.5),
                      ),
                    ),
                    child: _buildChatPanel(context, memory, effectiveMode),
                  ),
                ],
              )
            else if (dock.isOpen && effectiveMode == AiDockMode.bottom)
              Column(
                children: [
                  Expanded(child: widget.child),
                  Container(
                    height: dock.bottomHeight.clamp(220.0, size.height * 0.55),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
                      ),
                    ),
                    child: _buildChatPanel(context, memory, effectiveMode),
                  ),
                ],
              )
            else
              widget.child,

            // ── Mode Flottant (HUD déplaçable) ───────────────────────────
            if (dock.isOpen && effectiveMode == AiDockMode.floating)
              Positioned(
                left: dock.floatingOffset.dx
                    .clamp(8.0, (size.width - 380).clamp(8.0, 2000.0)),
                top: dock.floatingOffset.dy
                    .clamp(8.0, (size.height - 460).clamp(8.0, 2000.0)),
                width: widget.isMobile
                    ? (size.width - 20).clamp(280.0, 420.0)
                    : 400,
                height: widget.isMobile ? 430 : 500,
                child: Material(
                  color: Colors.transparent,
                  elevation: 20,
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _buildChatPanel(
                      context,
                      memory,
                      effectiveMode,
                      onDragUpdate: (d) => ref
                          .read(aiDockProvider.notifier)
                          .updateFloatingOffset(d.delta, size),
                    ),
                  ),
                ),
              ),

            // ── Pilule Flottante d'Accès Rapide (quand le panneau est replié) ──
            if (!dock.isOpen)
              Positioned(
                right: 16,
                bottom: widget.isMobile ? 74 : 16,
                child: _buildCollapsedLauncherPill(context, memory),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCollapsedLauncherPill(
      BuildContext context, ControllerMemoryState memory) {
    final hasAlert = memory.activeDiagnosis != null;
    final unread = ref.watch(aiInboxProvider).unread;
    final topSuggestion = memory.nextSuggestions.isNotEmpty
        ? memory.nextSuggestions.first
        : null;

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Puce de suggestion rapide post-opération visible même Chatbot replié
          if (topSuggestion != null && !widget.isMobile)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                backgroundColor: const Color(0xFF111827).withValues(alpha: 0.94),
                side: BorderSide(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.55),
                ),
                avatar: Text(topSuggestion.emoji,
                    style: const TextStyle(fontSize: 13)),
                label: Text(
                  'Suggestion : ${topSuggestion.label}',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => _executeSuggestion(topSuggestion),
              ),
            ),

          // Bouton principal d'ouverture du Copilote Omniprésent
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              ref.read(aiInboxProvider.notifier).markRead();
              ref.read(aiDockProvider.notifier).open();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasAlert
                      ? const [Color(0xFFDC2626), Color(0xFF991B1B)]
                      : const [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (hasAlert
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasAlert
                        ? Icons.warning_amber_rounded
                        : Icons.smart_toy_rounded,
                    color: hasAlert ? Colors.white : Colors.black,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasAlert
                        ? tr('ALERTE ESP32 / ALARME')
                        : tr('Copilote IA & Démo'),
                    style: TextStyle(
                      color: hasAlert ? Colors.white : Colors.black,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(
    BuildContext context,
    ControllerMemoryState memory,
    AiDockMode currentMode, {
    void Function(DragUpdateDetails)? onDragUpdate,
  }) {
    final chat = ref.watch(aiAgentControllerProvider);
    final uiLang = ref.watch(appLanguageProvider);
    final diag = memory.activeDiagnosis;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F17),
        border: currentMode == AiDockMode.floating
            ? Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        children: [
          // ── 1. Barre de titre & Sélecteur d'ancrage (Flottant / Bas / Droite) ──
          GestureDetector(
            onPanUpdate: onDragUpdate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded,
                      color: Color(0xFFF59E0B), size: 19),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tr('COPILOTE IA • MÉMOIRE CONTRÔLEUR'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            if (memory.esp32RebootCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFEF4444)),
                                ),
                                child: Text(
                                  'ESP32 Reboots: ${memory.esp32RebootCount}',
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '📍 ${memory.activeWindowName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF06B6D4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sélecteur rapide de langue (UI & Agent IA)
                  PopupMenuButton<AppLanguage>(
                    tooltip: tr('Langue de l\'Agent IA & de l\'interface'),
                    color: const Color(0xFF1E293B),
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
                                    ? const Color(0xFFF59E0B)
                                    : Colors.white54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.label,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
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
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate_rounded,
                              size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            uiLang.id.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Boutons de bascule d'ancrage : Flottant | Bas | Droite
                  _buildDockModeIcon(
                    mode: AiDockMode.floating,
                    active: currentMode == AiDockMode.floating,
                    icon: Icons.picture_in_picture_alt_rounded,
                    tooltip: tr('Mode Flottant (HUD déplaçable)'),
                  ),
                  _buildDockModeIcon(
                    mode: AiDockMode.bottom,
                    active: currentMode == AiDockMode.bottom,
                    icon: Icons.dock_rounded,
                    tooltip: tr('Ancrer en Bas'),
                  ),
                  if (!widget.isMobile)
                    _buildDockModeIcon(
                      mode: AiDockMode.right,
                      active: currentMode == AiDockMode.right,
                      icon: Icons.vertical_split_rounded,
                      tooltip: tr('Ancrer à Droite'),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Replier le Chatbot'),
                    onPressed: () => ref.read(aiDockProvider.notifier).close(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Barre d'actions Démo (Prises en main + STEP Manufacturing & Médecine) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickDemoBtn(
                    icon: Icons.ondemand_video_rounded,
                    label: tr('Prises en main (Image+Vidéo)'),
                    color: const Color(0xFFF59E0B),
                    onTap: () => FeatureHandsOnModal.show(
                      context,
                      onNavigateToScreen: widget.onNavigateToScreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildQuickDemoBtn(
                    icon: Icons.precision_manufacturing_rounded,
                    label: tr('STEP Manufacturing (Turbine)'),
                    color: const Color(0xFF06B6D4),
                    onTap: () {
                      final sample = DemoBenchmarkCatalog.sampleById(
                          'manufacturing_impeller');
                      if (sample != null) {
                        DemoBenchmarkRunner.runSample(ref, sample);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildQuickDemoBtn(
                    icon: Icons.medical_services_rounded,
                    label: tr('STEP Médecine (Implant crânien)'),
                    color: const Color(0xFF10B981),
                    onTap: () {
                      final sample = DemoBenchmarkCatalog.sampleById(
                          'medicine_cranial_implant');
                      if (sample != null) {
                        DemoBenchmarkRunner.runSample(ref, sample);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Carte de Diagnostic Temps Réel (Alarme GRBL ou Reboot ESP32) ──
          if (diag != null) _buildLiveHardwareDiagnosisBanner(diag),

          // ── 4. Fil de conversation de l'Agent IA ────────────────────────
          Expanded(
            child: chat.messages.isEmpty
                ? _buildEmptyMemoryWelcome(memory)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(10),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final m = chat.messages[index];
                      return _buildMessageBubble(m);
                    },
                  ),
          ),

          // ── 5. Bandeau de Suggestions Dynamiques Post-Opération ─────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${tr('SUGGESTIONS APRÈS')} : ${memory.lastOperationSummary}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in memory.nextSuggestions)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _executeSuggestion(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF06B6D4)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(s.emoji,
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text(
                                    s.label,
                                    style: const TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 6. Zone de saisie ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            color: const Color(0xFF111827),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    onSubmitted: _sendPrompt,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: tr(
                        'Posez une question ou dépannage (alarme, STEP, G-code, ESP32)…',
                      ),
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 11.5),
                      filled: true,
                      fillColor: const Color(0xFF0B0F17),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (chat.isProcessing)
                  IconButton(
                    tooltip: tr('Arrêter la réponse'),
                    onPressed: () => ref
                        .read(aiAgentControllerProvider.notifier)
                        .stopGeneration(),
                    icon: const Icon(Icons.stop_circle_rounded,
                        color: Color(0xFFEF4444)),
                  )
                else
                  IconButton(
                    tooltip: tr('Envoyer'),
                    onPressed: () => _sendPrompt(_inputCtrl.text),
                    icon: const Icon(Icons.send_rounded,
                        color: Color(0xFFF59E0B)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockModeIcon({
    required AiDockMode mode,
    required bool active,
    required IconData icon,
    required String tooltip,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: () => ref.read(aiDockProvider.notifier).setMode(mode),
      icon: Icon(
        icon,
        size: 16,
        color: active ? const Color(0xFFF59E0B) : Colors.white54,
      ),
    );
  }

  Widget _buildQuickDemoBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveHardwareDiagnosisBanner(dynamic diag) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF450A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFCA5A5), size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  diag.headline as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            diag.probableHardwareCause as String,
            style: const TextStyle(color: Color(0xFFFECACA), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            '🔌 ${diag.gpioPinDetail}',
            style: const TextStyle(
              color: Color(0xFFFDE047),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF991B1B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      act.label as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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

  Widget _buildEmptyMemoryWelcome(ControllerMemoryState memory) {
    final machine =
        ref.watch(machineStateProvider).valueOrNull ?? const MachineState();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.memory_rounded,
                        color: Color(0xFF06B6D4), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      tr('MÉMOIRE TEMPS RÉEL DU CONTRÔLEUR'),
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Fenêtre active : ${memory.activeWindowName}\n'
                  '• Statut FluidNC : ${machine.status.name.toUpperCase()}'
                  '${machine.alarmCode != null ? " (ALARM:${machine.alarmCode})" : ""}\n'
                  '• Position WPos : X=${machine.wPos[0].toStringAsFixed(1)} '
                  'Y=${machine.wPos[1].toStringAsFixed(1)} '
                  'Z=${machine.wPos[2].toStringAsFixed(1)} '
                  'A=${machine.wPos[3].toStringAsFixed(1)}° '
                  'C=${machine.wPos[4].toStringAsFixed(1)}°\n'
                  '• Santé ESP32 : ${memory.esp32RebootCount} redémarrage(s) détecté(s)\n'
                  '• Fichier CAO/FAO : ${memory.activeFilePath ?? "Aucun fichier chargé"}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11.5,
                    height: 1.45,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr(
              'Je vous accompagne depuis n\'importe quelle fenêtre : lancez une prise en main vidéo, testez un fichier STEP (Manufacturing ou Médecine) ou demandez un diagnostic matériel.',
            ),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage m) {
    final isUser = m.role == 'user';
    final isTool = m.isTool;

    if (isTool) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Icon(
              m.isRunningTool
                  ? Icons.sync_rounded
                  : (m.toolFailed
                      ? Icons.error_outline
                      : Icons.check_circle_outline),
              size: 14,
              color: m.toolFailed
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Outil : ${m.toolName ?? m.text}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E293B) : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUser
                ? const Color(0xFF334155)
                : const Color(0xFFF59E0B).withValues(alpha: 0.35),
          ),
        ),
        child: SelectableText(
          m.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
