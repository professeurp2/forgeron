import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/gcode_provider.dart';
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
  });

  final String title;
  final String? subtitle;
  final Map<String, dynamic> info;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final fc = context.fc;
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          Expanded(
            child: Container(color: fc.background, child: child),
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
/// principal afficherait. La pièce, si son maillage accompagne la demande,
/// est dessinée dessous — c'est ce qui permet de juger si le parcours suit
/// bien la forme.
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
    final mesh = (widget.payload['mesh'] as Map?)?.cast<String, dynamic>();
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
      child: TrunnionVisualizer(
        mPos: const [0, 0, 0, 0, 0],
        toolpath: toolpath,
        partMesh: mesh,
        // Les courses ne sont pas connues ici : la fenêtre détachée ne parle
        // pas à la machine. Pas d'enveloppe plutôt qu'une boîte inventée.
        scene: ViewerScene.toolpathOnly,
      ),
    );
  }
}
