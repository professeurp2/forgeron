import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../application/providers/ai_agent_provider.dart';
import '../../../application/providers/ai_agent_settings_provider.dart';
import '../../../application/providers/ai_model_provider.dart';
import '../../../application/services/ai_agent_tools.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../core/theme/forgeron_fluent_theme.dart';

/// Écran Agent IA, refondu — desktop d'abord (voir PLAN-IA). Toute la
/// logique reste celle de [aiAgentControllerProvider] : cet écran ne change
/// que la présentation, pas l'orchestration (mêmes outils, même agent, même
/// historique que l'écran mobile).
///
/// La différence visible : une chaîne d'appels d'outils consécutifs se
/// regroupe en une seule « procédure » — un fil de nœuds done/en cours —
/// plutôt qu'une suite de messages plats indiscernables du reste du fil.
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

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(text);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  Future<void> _pickStepFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['step', 'stp'],
      dialogTitle: 'Charger une pièce (STEP)',
    );
    final path = result?.files.single.path;
    if (path == null) return; // annulé

    ref.read(aiAgentControllerProvider.notifier).sendUserMessage(
          'Charge ce fichier STEP et prépare le G-code de finition.\n\nFichier : $path',
        );
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
      if (previous?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    });

    final items = _groupTimeline(chat.messages);

    return fluent.ScaffoldPage(
      padding: EdgeInsets.zero,
      header: _Header(fc: fc),
      content: Column(
        children: [
          Expanded(
            child: items.isEmpty && chat.streamingText == null
                ? _EmptyState(fc: fc, onPickStep: _pickStepFile)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    itemCount: items.length + (chat.streamingText != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == items.length) {
                        return _StreamingBubble(fc: fc, text: chat.streamingText!);
                      }
                      final item = items[i];
                      if (item is List<AiChatMessage>) {
                        return _ProcedureCard(
                          fc: fc,
                          group: item,
                          runningTool: chat.isProcessing ? chat.runningTool : null,
                        );
                      }
                      return _ChatBubble(fc: fc, message: item as AiChatMessage);
                    },
                  ),
          ),
          if (chat.pendingConfirmation != null)
            _ConfirmationBar(fc: fc, pending: chat.pendingConfirmation!),
          if (chat.error != null) _ErrorBar(fc: fc, message: chat.error!),
          _Composer(
            fc: fc,
            controller: _input,
            busy: chat.isProcessing,
            onSend: _send,
            onStop: () => ref.read(aiAgentControllerProvider.notifier).stopGeneration(),
            onAttachStep: _pickStepFile,
          ),
        ],
      ),
    );
  }

  void _showPopup(BuildContext context, ForgeronColorPalette fc, AiPopupRequest req) {
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

/// Regroupe les messages `tool` consécutifs en une seule procédure. Le reste
/// (user/assistant) reste un élément à part — même ordre que dans le fil.
List<Object> _groupTimeline(List<AiChatMessage> messages) {
  final out = <Object>[];
  List<AiChatMessage>? current;
  for (final m in messages) {
    if (m.role == 'tool') {
      current ??= [];
      current.add(m);
    } else {
      if (current != null) {
        out.add(current);
        current = null;
      }
      out.add(m);
    }
  }
  if (current != null) out.add(current);
  return out;
}

class _Header extends ConsumerWidget {
  const _Header({required this.fc});
  final ForgeronColorPalette fc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiAgentSettingsProvider);
    final useLocal = settings.localBaseUrl.isNotEmpty;
    final modelLabel =
        useLocal ? settings.localModel : ref.watch(aiModelProvider).active.id;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [fc.primaryLight, fc.primary, fc.primaryDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text('🤖', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AGENT IA',
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: .03 * 15)),
                Text('pipeline CAM · outils machine',
                    style: TextStyle(color: fc.textDisabled, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: fc.lcdBackground,
              border: Border.all(color: fc.lcdBorder),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: fc.lcdText, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${useLocal ? "LOCAL" : "GEMINI"} · $modelLabel',
                  style: TextStyle(
                    color: fc.lcdText,
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.fc, required this.message});
  final ForgeronColorPalette fc;
  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: isUser ? fc.primary : fc.surface,
          border: isUser ? null : Border.all(color: fc.surfaceBorder),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 3),
            bottomRight: Radius.circular(isUser ? 3 : 12),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? fc.background : fc.textPrimary,
            fontWeight: isUser ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.fc, required this.text});
  final ForgeronColorPalette fc;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: fc.surface,
          border: Border.all(color: fc.secondary.withValues(alpha: .35)),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: fc.textPrimary, fontSize: 13.5, height: 1.5),
            children: [
              TextSpan(text: text),
              TextSpan(text: ' ▍', style: TextStyle(color: fc.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une procédure — une ou plusieurs exécutions d'outils consécutives — sous
/// forme de fil de nœuds : ✓ terminé, anneau de progression pour celui en
/// cours, croix rouge si le résultat commence par « Erreur ».
class _ProcedureCard extends StatelessWidget {
  const _ProcedureCard({required this.fc, required this.group, required this.runningTool});

  final ForgeronColorPalette fc;
  final List<AiChatMessage> group;
  final String? runningTool;

  @override
  Widget build(BuildContext context) {
    final steps = [
      for (final m in group) _splitToolMessage(m.text),
      if (runningTool != null) (name: runningTool!, result: null),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: fc.surfaceBright,
        border: Border.all(color: fc.surfaceBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: fc.surfaceHigh,
              border: Border(bottom: BorderSide(color: fc.surfaceBorder)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(fluent.FluentIcons.timeline, size: 13, color: fc.secondary),
                const SizedBox(width: 8),
                Text('PROCÉDURE',
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        letterSpacing: .08 * 11.5)),
                const Spacer(),
                Text(
                  '${group.length}/${steps.length}',
                  style: TextStyle(color: fc.success, fontSize: 10.5, fontFamily: 'JetBrainsMono'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _StepRow(fc: fc, step: steps[i], isLast: i == steps.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Step = ({String name, String? result});

_Step _splitToolMessage(String text) {
  final i = text.indexOf(' → ');
  if (i < 0) return (name: text, result: '');
  return (name: text.substring(0, i), result: text.substring(i + 3));
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.fc, required this.step, required this.isLast});
  final ForgeronColorPalette fc;
  final _Step step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final running = step.result == null;
    final failed = !running && step.result!.startsWith('Erreur');
    final color = running ? fc.primary : (failed ? fc.danger : fc.success);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: running
                    ? SizedBox(
                        width: 11,
                        height: 11,
                        child: fluent.ProgressRing(strokeWidth: 1.6, activeColor: color),
                      )
                    : Icon(
                        failed ? fluent.FluentIcons.clear : fluent.FluentIcons.check_mark,
                        size: 11,
                        color: color,
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: fc.surfaceBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.name,
                    style: TextStyle(
                      color: fc.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  if (step.result != null && step.result!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.result!,
                      style: TextStyle(
                        color: failed ? fc.danger : fc.lcdText,
                        fontSize: 11.5,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                  if (running) ...[
                    const SizedBox(height: 3),
                    Text('en cours…',
                        style: TextStyle(color: fc.textDisabled, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationBar extends ConsumerWidget {
  const _ConfirmationBar({required this.fc, required this.pending});
  final ForgeronColorPalette fc;
  final AiPendingToolCall pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
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
            child: Text(
              'Confirmation requise : ${pending.toolName}',
              style: TextStyle(color: fc.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          fluent.Button(
            child: const Text('Refuser'),
            onPressed: () => ref.read(aiAgentControllerProvider.notifier).rejectPendingAction(),
          ),
          const SizedBox(width: 8),
          fluent.FilledButton(
            child: const Text('Confirmer'),
            onPressed: () => ref.read(aiAgentControllerProvider.notifier).confirmPendingAction(),
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.fc, required this.message});
  final ForgeronColorPalette fc;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fc.danger.withValues(alpha: .1),
        border: Border.all(color: fc.danger.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: TextStyle(color: fc.danger, fontSize: 12.5)),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.fc,
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.onAttachStep,
  });

  final ForgeronColorPalette fc;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttachStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          fluent.Tooltip(
            message: 'Charger un fichier STEP (pièce de révolution)',
            child: fluent.IconButton(
              icon: Icon(fluent.FluentIcons.attach, color: fc.textSecondary, size: 16),
              onPressed: onAttachStep,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: fluent.TextBox(
              controller: controller,
              placeholder: 'Demander une action ou une analyse à l\'agent…',
              minLines: 1,
              maxLines: 5,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          busy
              ? fluent.IconButton(
                  icon: Icon(Icons.stop_circle_outlined, color: fc.danger),
                  onPressed: onStop,
                )
              : fluent.FilledButton(
                  onPressed: onSend,
                  child: const Icon(fluent.FluentIcons.send, size: 16),
                ),
        ],
      ),
    );
  }
}

/// Écran vide au premier lancement de la discussion : sans elle, l'agent
/// IA ressemble à un chat comme un autre — rien ne dit qu'il sait piloter le
/// pipeline STEP -> G-code. Le bouton fait exactement ce que fait le
/// trombone du composer, en plus visible.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.fc, required this.onPickStep});
  final ForgeronColorPalette fc;
  final VoidCallback onPickStep;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fc.primary.withValues(alpha: .12),
                border: Border.all(color: fc.primary.withValues(alpha: .35)),
              ),
              child: Icon(fluent.FluentIcons.processing, color: fc.primary, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              'Pièce de révolution → G-code',
              textAlign: TextAlign.center,
              style: TextStyle(color: fc.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Charge un fichier STEP : l\'agent détecte l\'axe, extrait le profil exact '
              'et génère le G-code — chaque étape s\'affiche ici en direct.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fc.textSecondary, fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 20),
            fluent.FilledButton(
              onPressed: onPickStep,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Charger un fichier STEP'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ou pose directement une question ci-dessous',
              style: TextStyle(color: fc.textDisabled, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
