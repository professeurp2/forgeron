import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/forgeron_colors.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../application/providers/ui_state_provider.dart';
import '../trunnion_visualizer.dart';

/// Panneau du visualiseur 3D pour mobile — réutilise le même
/// [TrunnionVisualizer] que le Dashboard desktop.
///
/// [expand] = true : remplit l'espace disponible (onglet dédié « 3D »).
/// [expand] = false : carte de hauteur fixe (en tête de l'onglet Jog).
class MobileVisualizerPanel extends ConsumerWidget {
  final bool expand;
  const MobileVisualizerPanel({super.key, this.expand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fc = context.fc;
    final state = ref.watch(machineStateProvider).valueOrNull;
    final gcodeState = ref.watch(gcodeProvider);
    final showVectors = ref.watch(showVectorsProvider);
    // Pendant la rotation du cube, la WebView reste à plat (elle ne pivote pas
    // en 3D). On la couvre d'un panneau figé Flutter, qui lui pivote proprement.
    final transitioning = ref.watch(pageTransitioningProvider);
    final mPos = ref.watch(renderMPosProvider);

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
          TrunnionVisualizer(
            mPos: mPos,
            targetPos: state?.targetPos,
            toolpath: ref.watch(renderToolpathProvider),
            activeIndex:
                gcodeState.resolveToolpathIndex(state?.activeLineIndex ?? 0),
            showVectors: showVectors,
          ),
          // Couvre la WebView le temps de la transition (opaque → la WebView
          // figée dessous n'est pas visible ; ce panneau, lui, tourne).
          if (transitioning)
            Positioned.fill(
              child: ColoredBox(
                color: fc.terminalBg,
                child: Center(
                  child: Icon(Icons.view_in_ar,
                      size: 44,
                      color: fc.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );

    final header = Row(children: [
      Text('SIMULATEUR 3D',
          style: TextStyle(
              color: fc.textDisabled,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0)),
      const Spacer(),
      Text('VECTEURS', style: TextStyle(color: fc.textDisabled, fontSize: 9)),
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
      IconButton(
        icon: Icon(Icons.fullscreen, color: fc.textSecondary, size: 20),
        tooltip: 'Plein écran',
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const MobileVisualizerFullScreen(),
          ));
        },
      ),
    ]);

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

/// Version plein écran du visualiseur, poussée en route dédiée (mobile).
class MobileVisualizerFullScreen extends ConsumerWidget {
  const MobileVisualizerFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(machineStateProvider).valueOrNull;
    final gcodeState = ref.watch(gcodeProvider);
    final showVectors = ref.watch(showVectorsProvider);
    final mPos = ref.watch(renderMPosProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: TrunnionVisualizer(
              mPos: mPos,
              targetPos: state?.targetPos,
              toolpath: ref.watch(renderToolpathProvider),
              activeIndex:
                  gcodeState.resolveToolpathIndex(state?.activeLineIndex ?? 0),
              showVectors: showVectors,
            ),
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
