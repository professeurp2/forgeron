import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/ai_artifacts_provider.dart';
import '../../application/providers/gcode_provider.dart';
import '../../application/services/ai_window_channel.dart';
import '../../core/theme/forgeron_colors.dart';
import '../widgets/trunnion_visualizer.dart';
import '../widgets/viewer_scene.dart';

/// Les deux fenêtres 3D détachées de l'agent IA.
///
/// Pourquoi des fenêtres OS plutôt qu'un panneau dans l'écran de discussion :
/// le premier essai nichait le visualiseur dans un `Expander` animé au sein
/// d'une liste défilante. Un contrôle WebView natif n'y survit pas — il est
/// découpé au clip, redimensionné à chaque image, et n'émet jamais son signal
/// « prêt ». Une fenêtre lui donne un cadre fixe, plein, non animé ; et
/// l'opérateur peut la garder ouverte sur un second écran pendant que l'agent
/// continue à répondre.

/// Cadre commun : une vue 3D plein cadre, une bande d'informations en bas.
class _ViewerFrame extends StatelessWidget {
  const _ViewerFrame({
    required this.title,
    required this.info,
    required this.child,
    this.subtitle,
    this.dockAs,
  });

  final String title;
  final String? subtitle;
  final Map<String, dynamic> info;
  final Widget child;

  /// L'aperçu que la fenêtre principale doit accueillir si on lui rend la
  /// main. `null` = cette fenêtre ne sait pas rentrer (rien à afficher).
  final AiDockedViewer? dockAs;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final fc = context.fc;
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: fc.background, child: child)),
                if (dockAs != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _DockButton(fc: fc, viewer: dockAs!),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: fc.surface,
              border: Border(top: BorderSide(color: fc.surfaceBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.typography.bodyStrong),
                      if (subtitle != null)
                        Text(subtitle!, style: theme.typography.caption),
                    ],
                  ),
                ),
                for (final entry in info.entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: _InfoChip(label: entry.key, value: '${entry.value}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Ouvrir dans la fenêtre principale » — le chemin du retour.
///
/// Une fenêtre détachée est confortable sur deux écrans et encombrante sur
/// un seul : elle recouvre la discussion. Elle sait donc rentrer.
///
/// Elle ne renvoie PAS l'aperçu, seulement lequel montrer : la fenêtre
/// principale possède déjà la pièce et le programme. Et elle ne se referme que
/// si la fenêtre principale a accepté — sinon elle serait le dernier endroit
/// où cet aperçu existe encore.
class _DockButton extends StatefulWidget {
  const _DockButton({required this.fc, required this.viewer});

  final ForgeronColorPalette fc;
  final AiDockedViewer viewer;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _busy = false;

  Future<void> _dock() async {
    setState(() => _busy = true);
    final accepted = await AiWindowChannel.requestDock(widget.viewer.wire);
    if (accepted) {
      await AiWindowChannel.closeThisWindow();
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await displayInfoBar(context, builder: (ctx, close) {
      return InfoBar(
        title: const Text('Retour impossible'),
        content: const Text(
          'La fenêtre principale n\'a plus cette pièce en mémoire '
          '(discussion changée ou effacée). Cette fenêtre reste ouverte.',
        ),
        severity: InfoBarSeverity.warning,
        onClose: close,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    return Tooltip(
      message: 'Ouvrir dans la fenêtre principale',
      child: Button(
        onPressed: _busy ? null : _dock,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
              fc.surface.withValues(alpha: .85)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const SizedBox(
                  width: 12, height: 12, child: ProgressRing(strokeWidth: 1.6))
            else
              Icon(Icons.open_in_browser_rounded, size: 14, color: fc.textSecondary),
            const SizedBox(width: 8),
            const Text('Fenêtre principale', style: TextStyle(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: fc.textDisabled,
            fontSize: 9.5,
            letterSpacing: .8,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: fc.lcdText,
            fontFamily: 'JetBrainsMono',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Aperçu 3D d'une pièce STEP : le maillage seul, sans portique ni brut, pour
/// que la pièce remplisse le cadre quelle que soit sa taille.
class StepPreviewWindow extends StatelessWidget {
  const StepPreviewWindow({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final mesh = (payload['mesh'] as Map?)?.cast<String, dynamic>();
    final info = ((payload['info'] as Map?) ?? const {}).cast<String, dynamic>();
    final title = payload['title'] as String? ?? 'Aperçu de la pièce';

    if (mesh == null || (mesh['vertices'] as List?)?.isEmpty != false) {
      return _ViewerFrame(
        title: title,
        info: const {},
        child: const Center(child: Text('Aucun maillage à afficher.')),
      );
    }

    return _ViewerFrame(
      title: title,
      subtitle: payload['source'] as String?,
      info: info,
      dockAs: AiDockedViewer.step,
      child: TrunnionVisualizer(
        mPos: const [0, 0, 0, 0, 0],
        partMesh: mesh,
        scene: ViewerScene.partOnly,
      ),
    );
  }
}

/// Parcours d'outil en 3D, chargé depuis un `.nc`.
///
/// Le fichier est lu et analysé ici, par le parseur de l'app : même
/// adaptation FluidNC, même cinématique, donc exactement le tracé que l'écran
/// principal afficherait.
///
/// **Le tracé seul, sans la pièce.** Un parcours se lit à ses trajets et à ses
/// niveaux ; un solide posé dessous les masque précisément là où il faut les
/// voir, puisque le parcours épouse la surface. La pièce a sa propre fenêtre.
class ToolpathWindow extends ConsumerStatefulWidget {
  const ToolpathWindow({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  ConsumerState<ToolpathWindow> createState() => _ToolpathWindowState();
}

class _ToolpathWindowState extends ConsumerState<ToolpathWindow> {
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.payload['gcodePath'] as String?;
    try {
      final content = path != null
          ? await File(path).readAsString()
          : (widget.payload['content'] as String? ?? '');
      if (content.trim().isEmpty) {
        throw const FileSystemException('programme vide');
      }
      await ref.read(gcodeProvider.notifier).loadFile(content);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.payload['title'] as String? ?? 'Parcours d\'outil';
    final info = ((widget.payload['info'] as Map?) ?? const {}).cast<String, dynamic>();

    if (_error != null) {
      return _ViewerFrame(
        title: title,
        info: const {},
        child: Center(child: Text('Parcours illisible : $_error')),
      );
    }
    if (_loading) {
      return _ViewerFrame(
        title: title,
        subtitle: 'Analyse du programme…',
        info: const {},
        child: const Center(child: ProgressRing()),
      );
    }

    final toolpath = ref.watch(renderToolpathProvider);
    return _ViewerFrame(
      title: title,
      subtitle: widget.payload['gcodePath'] as String?,
      info: {'points': toolpath.length, ...info},
      dockAs: AiDockedViewer.toolpath,
      child: TrunnionVisualizer(
        mPos: const [0, 0, 0, 0, 0],
        toolpath: toolpath,
        // Les courses ne sont pas connues ici : la fenêtre détachée ne parle
        // pas à la machine. Pas d'enveloppe plutôt qu'une boîte inventée.
        scene: ViewerScene.toolpathOnly,
      ),
    );
  }
}
