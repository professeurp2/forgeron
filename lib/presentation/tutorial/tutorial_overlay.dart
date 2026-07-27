import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/responsive_layout.dart';
import 'tutorial_controller.dart';
import 'tutorial_highlight_painter.dart';
import 'tutorial_tooltip_card.dart';
import 'tutorial_step.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const TutorialOverlay({super.key, required this.child});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorialState = ref.watch(tutorialProvider);
    if (!tutorialState.isActive) return widget.child;

    // Auto-correction : le parcours dépend de la mise en page RÉELLE au moment
    // où l'on peint, pas d'un drapeau figé au démarrage. Sans ça, un mobile
    // pouvait se voir servir les 33 étapes desktop (barre latérale, pied de
    // page…) qui ne surlignent rien ici. Doit utiliser le MÊME critère que
    // ResponsiveLayout (côté le plus court) : un simple `width < 600` bascule
    // à tort vers le parcours desktop sur un téléphone en paysage (largeur
    // ~800 mais mise en page mobile bel et bien affichée), et le tutoriel se
    // retrouve à viser des widgets desktop qui n'existent pas ici.
    final isMobile = ResponsiveLayout.isMobile(context);
    if (isMobile != tutorialState.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(tutorialProvider.notifier).setLayout(isMobile: isMobile);
        }
      });
    }

    // Tant que la correction n'est pas appliquée, on borne l'index pour ne pas
    // sortir de la liste courante.
    final steps = tutorialState.steps;
    final index = tutorialState.currentStepIndex.clamp(0, steps.length - 1);
    final step = steps[index];

    return Stack(
      children: [
        widget.child,
        _buildOverlay(step, tutorialState),
      ],
    );
  }

  Widget _buildOverlay(TutorialStep step, TutorialState state) {
    return LayoutBuilder(
      key: ValueKey(step.id),
      builder: (context, constraints) {
        Rect? targetRect;
        if (step.targetKey != null) {
          final renderBox =
              step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final offset = renderBox.localToGlobal(Offset.zero);
            targetRect = offset & renderBox.size;
          }
        }

        return Stack(
          children: [
            // Dark Background with hole
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: TutorialHighlightPainter(
                    spotlightRect: targetRect,
                    glowOpacity: 0.2 + (_pulseController.value * 0.4),
                    accentColor: step.accentColor,
                  ),
                );
              },
            ),
            
            // Tooltip positioning
            _buildTooltip(step, targetRect, constraints, state),
            
            // Fermeture — sous la barre de statut, pas dessous.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: Material(
                type: MaterialType.transparency,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  tooltip: 'Quitter la visite',
                  onPressed: () => ref.read(tutorialProvider.notifier).skip(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTooltip(TutorialStep step, Rect? targetRect,
      BoxConstraints constraints, TutorialState state) {
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;

    // La carte s'adapte à l'écran (elle faisait 340 px en dur).
    const cardH = 250.0;
    final cardW = math.min(340.0, maxW - 32);

    // Un écran étroit n'a pas la place de poser la carte à gauche ou à droite
    // de la cible : on bascule au-dessus ou en dessous selon où elle se trouve.
    final narrow = maxW < 500;
    var pos = step.tooltipPosition;
    if (narrow &&
        (pos == TooltipPosition.left || pos == TooltipPosition.right)) {
      pos = (targetRect != null && targetRect.center.dy > maxH / 2)
          ? TooltipPosition.top
          : TooltipPosition.bottom;
    }

    Offset offset;
    if (targetRect == null || pos == TooltipPosition.center) {
      offset = Offset((maxW - cardW) / 2, (maxH - cardH) / 2);
    } else {
      offset = switch (pos) {
        TooltipPosition.bottom =>
          Offset(targetRect.center.dx - cardW / 2, targetRect.bottom + 16),
        TooltipPosition.top =>
          Offset(targetRect.center.dx - cardW / 2, targetRect.top - cardH - 16),
        TooltipPosition.left =>
          Offset(targetRect.left - cardW - 16, targetRect.center.dy - 100),
        TooltipPosition.right =>
          Offset(targetRect.right + 16, targetRect.center.dy - 100),
        _ => Offset((maxW - cardW) / 2, (maxH - cardH) / 2),
      };
    }

    // Bornes sûres : sur un écran étroit, `maxW - 340` pouvait passer SOUS la
    // borne basse, et clamp() lève alors une assertion (lowerBound > upperBound).
    final maxX = math.max(16.0, maxW - cardW - 16);
    final maxY = math.max(16.0, maxH - cardH - 16);
    final x = offset.dx.clamp(16.0, maxX);
    final y = offset.dy.clamp(16.0, maxY);

    return Positioned(
      left: x,
      top: y,
      child: Material(
        type: MaterialType.transparency,
        child: TutorialTooltipCard(
          step: step,
          currentIndex: state.currentStepIndex,
          totalSteps: state.totalSteps,
          onNext: () => ref.read(tutorialProvider.notifier).next(),
          onPrevious: () => ref.read(tutorialProvider.notifier).previous(),
          onSkip: () => ref.read(tutorialProvider.notifier).skip(),
        ),
      ),
    );
  }
}
