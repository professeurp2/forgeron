import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons, SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../application/providers/ai_agent_provider.dart';
import '../../../application/providers/ai_agent_settings_provider.dart';
import '../../../application/providers/ai_model_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../application/providers/machine_params_provider.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/services/ai_agent_tools.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../core/theme/forgeron_fluent_theme.dart';
import '../../../core/utils/voice_locale.dart';
import '../../widgets/trunnion_visualizer.dart';

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
  final _picker = ImagePicker();

  // Image en attente d'envoi (multimodal) — même mécanisme que l'écran
  // mobile (ai_assistant_screen.dart) : sendUserMessage(text, imageBytes:,
  // imageMime:). Ne PAS réinventer un second canal d'envoi d'image.
  Uint8List? _pendingImage;
  String? _pendingImageMime;

  // Voix — même mécanisme que l'écran mobile (dictée + lecture des réponses),
  // oublié lors de la refonte desktop initiale. Ne pas réinventer un second
  // système : mêmes packages, même logique de correspondance de locale.
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _listening = false;
  String? _sttLocaleId;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.5);
    _applyVoiceLanguage();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _speech.stop();
    _tts.stop();
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
        await fluent.displayInfoBar(context, builder: (ctx, close) {
          return fluent.InfoBar(
            title: const Text('Reconnaissance vocale indisponible'),
            content: const Text('Aucun micro détecté sur cet appareil.'),
            severity: fluent.InfoBarSeverity.warning,
            onClose: close,
          );
        });
      }
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
      final match = bestVoiceLocale(_wantedVoiceTag, available, fallbacks: const ['fr-FR', 'en-US']);
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
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  /// Sélection d'image depuis un fichier — pas de caméra ici :
  /// `image_picker_windows` (voir sa source) lève un `StateError` sur
  /// `ImageSource.camera` faute de `cameraDelegate` configuré. La capture
  /// photo reste une action mobile ; le desktop travaille depuis des fichiers
  /// (export CAO, capture d'écran, photo déjà transférée).
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
        if (mounted) {
          await fluent.displayInfoBar(context, builder: (ctx, close) {
            return fluent.InfoBar(
              title: const Text('Image trop lourde'),
              content: const Text('8 Mo maximum.'),
              severity: fluent.InfoBarSeverity.warning,
              onClose: close,
            );
          });
        }
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
          const SizedBox(width: 10),
          Builder(builder: (context) {
            final ttsOn = ref.watch(aiTtsEnabledProvider);
            return fluent.Tooltip(
              message: ttsOn ? 'Lecture vocale activée' : 'Lecture vocale',
              child: fluent.IconButton(
                icon: Icon(
                  ttsOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: ttsOn ? fc.primary : fc.textSecondary,
                  size: 16,
                ),
                onPressed: () => ref.read(aiTtsEnabledProvider.notifier).state = !ttsOn,
              ),
            );
          }),
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

/// Une procédure — une ou plusieurs exécutions d'outils consécutives —
/// affichée comme une pile de lignes repliables (une par étape), plutôt
/// qu'un fil de nœuds verticaux : la personne qui utilise cet écran n'est
/// ni développeuse ni machiniste, une ligne « Génération du G-code — ✓
/// terminé » se lit d'un coup d'œil, un JSON brut non.
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
    final done = steps.where((s) => s.result != null && !s.result!.startsWith('Erreur')).length;

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
                Text('ÉTAPES DE L\'AGENT',
                    style: TextStyle(
                        color: fc.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        letterSpacing: .08 * 11.5)),
                const Spacer(),
                Text(
                  '$done/${steps.length}',
                  style: TextStyle(color: fc.success, fontSize: 10.5, fontFamily: 'JetBrainsMono'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                for (final step in steps) _StepRow(fc: fc, step: step),
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

/// Traduit un nom d'outil technique en une phrase compréhensible sans savoir
/// coder ni usiner. Les outils absents de cette liste retombent sur une
/// mise en forme générique (underscores → espaces) — jamais un plantage,
/// juste un libellé moins soigné en attendant de l'ajouter ici.
const _toolLabels = <String, String>{
  'run_step_pipeline': 'Génération du G-code depuis le fichier STEP',
  'run_gcode_program': 'Chargement du programme dans l\'espace de travail',
  'analyze_gcode': 'Analyse du programme G-code',
  'get_machine_state': 'Lecture de l\'état de la machine',
  'get_diagnostics': 'Vérification de la machine',
  'home': 'Prise d\'origine (homing)',
  'probe': 'Palpage de la pièce',
  'jog_axis': 'Déplacement manuel d\'un axe',
  'goto_position': 'Déplacement vers une position',
  'set_work_zero': 'Réglage du zéro pièce',
  'send_gcode': 'Envoi d\'une commande à la machine',
  'run_program': 'Lancement de l\'usinage',
  'stop_program': 'Arrêt de l\'usinage',
  'pause': 'Mise en pause',
  'resume': 'Reprise de l\'usinage',
  'emergency_stop': 'Arrêt d\'urgence',
  'unlock_alarm': 'Déblocage de l\'alarme',
  'get_camera_snapshot': 'Photo de la caméra atelier',
  'list_workspace_files': 'Liste des fichiers de l\'espace de travail',
  'read_workspace_file': 'Lecture d\'un fichier',
  'write_workspace_file': 'Écriture d\'un fichier',
  'show_popup': 'Message de l\'agent',
  'open_chart_window': 'Ouverture d\'un graphique',
  'open_gcode_window': 'Ouverture du G-code dans une fenêtre',
};

String _friendlyToolLabel(String toolName) {
  return _toolLabels[toolName] ??
      toolName.replaceAll('_', ' ').replaceFirstMapped(
          RegExp('^.'), (m) => m.group(0)!.toUpperCase());
}

/// Résumé court d'un résultat d'outil, pour l'en-tête de la ligne repliée.
/// `run_step_pipeline` répond en JSON : on en tire une phrase plutôt que
/// d'afficher les accolades brutes — le détail complet reste disponible en
/// dépliant la ligne, pour qui veut vérifier.
String _resultSummary(String toolName, String result) {
  if (result.startsWith('Erreur')) return result;
  if (toolName == 'run_step_pipeline') {
    try {
      final data = jsonDecode(result) as Map<String, dynamic>;
      final pipeline = data['pipeline'] == 'freecad_prismatique'
          ? 'pièce prismatique (FreeCAD)'
          : 'pièce de révolution';
      final ops = (data['operations'] as List?)?.length;
      final lignes = data['lignes_gcode'];
      final parts = <String>[pipeline];
      if (ops != null) parts.add('$ops opération(s)');
      if (lignes != null) parts.add('$lignes lignes de G-code');
      return parts.join(' · ');
    } catch (_) {
      // Pas du JSON (ex: message d'erreur) → on laisse tel quel.
    }
  }
  return result.length > 90 ? '${result.substring(0, 90)}…' : result;
}

/// Chemin du G-code produit par `run_step_pipeline`, si le résultat est un
/// succès JSON qui en porte un — `null` sinon (échec, ou un autre outil).
String? _gcodePathFrom(String toolName, String result) {
  if (toolName != 'run_step_pipeline' || result.startsWith('Erreur')) return null;
  try {
    final data = jsonDecode(result) as Map<String, dynamic>;
    return data['gcode_path'] as String?;
  } catch (_) {
    return null;
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.fc, required this.step});
  final ForgeronColorPalette fc;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final running = step.result == null;
    final failed = !running && step.result!.startsWith('Erreur');
    final color = running ? fc.primary : (failed ? fc.danger : fc.success);
    final label = _friendlyToolLabel(step.name);
    final gcodePath = running ? null : _gcodePathFrom(step.name, step.result!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: fluent.Expander(
        headerBackgroundColor: WidgetStatePropertyAll(fc.surface),
        contentBackgroundColor: fc.surface,
        leading: Container(
          width: 22,
          height: 22,
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
        header: Text(
          label,
          style: TextStyle(color: fc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
        trailing: Text(
          running ? 'en cours…' : _resultSummary(step.name, step.result!),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: running ? fc.textDisabled : (failed ? fc.danger : fc.textSecondary),
            fontSize: 11,
          ),
        ),
        initiallyExpanded: gcodePath != null,
        content: running
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gcodePath != null) ...[
                    _GcodePreview(fc: fc, path: gcodePath),
                    const SizedBox(height: 10),
                  ],
                  SelectableText(
                    step.result!,
                    style: TextStyle(
                        color: fc.textSecondary, fontSize: 11.5, fontFamily: 'JetBrainsMono'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Aperçu 3D du G-code généré, directement dans le fil de discussion —
/// réutilise le visualiseur déjà présent dans l'app (TrunnionVisualizer +
/// gcodeProvider), pas un second moteur de rendu. Charge le fichier une
/// seule fois au premier affichage.
class _GcodePreview extends ConsumerStatefulWidget {
  const _GcodePreview({required this.fc, required this.path});
  final ForgeronColorPalette fc;
  final String path;

  @override
  ConsumerState<_GcodePreview> createState() => _GcodePreviewState();
}

class _GcodePreviewState extends ConsumerState<_GcodePreview> {
  Object? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content = await File(widget.path).readAsString();
      if (!mounted) return;
      await ref.read(gcodeProvider.notifier).loadFile(content);
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    if (_error != null) {
      return Text('Aperçu indisponible : $_error',
          style: TextStyle(color: fc.danger, fontSize: 11.5));
    }
    if (!_loaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: fluent.ProgressRing(strokeWidth: 1.8)),
          const SizedBox(width: 8),
          Text('Ouverture du parcours…', style: TextStyle(color: fc.textSecondary, fontSize: 11.5)),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 260,
        child: TrunnionVisualizer(
          mPos: ref.watch(renderMPosProvider),
          toolpath: ref.watch(renderToolpathProvider),
          machineLimits: ref.watch(machineTravelProvider),
        ),
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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: fc.surface,
        border: Border(top: BorderSide(color: fc.surfaceBorder)),
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
                    child: Image.memory(pendingImage!, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Text('Image jointe', style: TextStyle(color: fc.textSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  fluent.IconButton(
                    icon: Icon(Icons.close, color: fc.textDisabled, size: 16),
                    onPressed: onRemoveImage,
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              fluent.Tooltip(
                message: 'Charger un fichier STEP (pièce de révolution)',
                child: fluent.IconButton(
                  icon: Icon(fluent.FluentIcons.attach, color: fc.textSecondary, size: 16),
                  onPressed: onAttachStep,
                ),
              ),
              fluent.Tooltip(
                message: 'Joindre une image',
                child: fluent.IconButton(
                  icon: Icon(Icons.photo_camera_rounded, color: fc.textSecondary, size: 16),
                  onPressed: onAttachImage,
                ),
              ),
              fluent.Tooltip(
                message: listening ? 'Arrêter la dictée' : 'Dicter',
                child: fluent.IconButton(
                  icon: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: listening ? fc.danger : fc.textSecondary,
                    size: 16,
                  ),
                  onPressed: onToggleListen,
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
