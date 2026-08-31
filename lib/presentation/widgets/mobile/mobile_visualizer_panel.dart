import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/providers/camera_provider.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../trunnion_visualizer.dart';
import '../camera_view.dart';
import '../visualizer_mode_toggle.dart';
import '../../../core/i18n/app_localizations.dart';

/// Panneau du visualiseur pour mobile. Il porte deux vues qui occupent le même
/// emplacement : la **caméra** (ESP32-CAM, vue par défaut dès qu'elle est
/// configurée) et le **simulateur 3D** ([TrunnionVisualizer], partagé avec le
/// Dashboard desktop).
///
/// [expand] = true : remplit l'espace disponible (onglet dédié « 3D »).
/// [expand] = false : carte de hauteur fixe (en tête de l'onglet Jog).
class MobileVisualizerPanel extends ConsumerWidget {
  final bool expand;
  const MobileVisualizerPanel({super.key, this.expand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final mode = ref.watch(effectiveVisualizerModeProvider);
    final showVectors = ref.watch(showVectorsProvider);
    // Pendant la rotation du cube, la WebView reste à plat (elle ne pivote pas
    // en 3D). On la couvre d'un panneau figé Flutter, qui lui pivote proprement.
    final transitioning = ref.watch(pageTransitioningProvider);

    Widget viz = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fc.terminalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fc.surfaceBorder),
        boxShadow: [
          BoxShadow(
              color: fc.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -4),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mode == VisualizerMode.camera)
            const CameraView()
          else
            buildTrunnionView(ref, showVectors),

          // Couvre la WebView le temps de la transition (opaque → la WebView
          // figée dessous n'est pas visible ; ce panneau, lui, tourne). Inutile
          // pour la caméra, qui est un widget Flutter natif et pivote seul.
          if (transitioning && mode == VisualizerMode.simulation3d)
            Positioned.fill(
              child: ColoredBox(
                color: fc.terminalBg,
                child: Center(
                  child: Icon(Icons.view_in_ar,
                      size: 44, color: fc.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );

    final header = _Header(mode: mode);

    if (expand) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          const SizedBox(height: 8),
          Expanded(child: viz),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header,
      const SizedBox(height: 6),
      SizedBox(height: 260, child: viz),
    ]);
  }
}

/// Construit le visualiseur 3D. Extrait pour que les providers du G-code et de
/// la position ne soient lus — et donc écoutés — que lorsque la vue 3D est
/// réellement affichée : inutile de recalculer une cinématique directe à chaque
/// rapport d'état quand l'écran montre la caméra.
Widget buildTrunnionView(WidgetRef ref, bool showVectors) {
  final state = ref.watch(machineStateProvider).valueOrNull;
  final gcodeState = ref.watch(gcodeProvider);
  return TrunnionVisualizer(
    mPos: ref.watch(renderMPosProvider),
    targetPos: state?.targetPos,
    toolpath: ref.watch(renderToolpathProvider),
    activeIndex: gcodeState.resolveToolpathIndex(state?.activeLineIndex ?? 0),
    showVectors: showVectors,
  );
}

// ── En-tête ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.mode});

  final VisualizerMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final cameraEnabled = ref.watch(cameraEnabledProvider);
    final showVectors = ref.watch(showVectorsProvider);

    return Row(children: [
      // Sans caméra configurée, pas de sélecteur : un simple titre.
      if (cameraEnabled)
        const VisualizerModeToggle()
      else
        Text(tr('SIMULATEUR 3D'),
            style: TextStyle(
                color: fc.textDisabled,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0)),
      const Spacer(),

      // Réglage propre à la vue 3D.
      if (mode == VisualizerMode.simulation3d) ...[
        Text(tr('VECTEURS'), style: TextStyle(color: fc.textDisabled, fontSize: 9)),
        SizedBox(
          height: 24,
          child: Switch(
            value: showVectors,
            onChanged: (v) => ref.read(showVectorsProvider.notifier).state = v,
            activeThumbColor: fc.primary,
            activeTrackColor: fc.primary.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],

      IconButton(
        icon: Icon(Icons.fullscreen, color: fc.textSecondary, size: 20),
        tooltip: tr('Plein écran'),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const MobileVisualizerFullScreen(),
          ));
        },
      ),
    ]);
  }
}

// ── Plein écran ──────────────────────────────────────────────────────────────

/// Version plein écran du visualiseur, poussée en route dédiée (mobile).
/// Elle suit le mode choisi dans le panneau.
class MobileVisualizerFullScreen extends ConsumerWidget {
  const MobileVisualizerFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(effectiveVisualizerModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: mode == VisualizerMode.camera
                ? const CameraView()
                : buildTrunnionView(ref, ref.watch(showVectorsProvider)),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton.filled(
              icon: const Icon(Icons.fullscreen_exit, size: 26),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ]),
      ),
    );
  }
}
