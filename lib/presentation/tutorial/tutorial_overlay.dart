import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tutorial_controller.dart';
import 'tutorial_highlight_painter.dart';
import 'tutorial_tooltip_card.dart';
import 'tutorial_data.dart';
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

    final step = tutorialSteps[tutorialState.currentStepIndex];
    
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
            
            // Close button
            Positioned(
              top: 40,
              right: 40,
              child: Material(
                type: MaterialType.transparency,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => ref.read(tutorialProvider.notifier).skip(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTooltip(TutorialStep step, Rect? targetRect, BoxConstraints constraints, TutorialState state) {
    Offset tooltipOffset;

    if (targetRect == null || step.tooltipPosition == TooltipPosition.center) {
      tooltipOffset = Offset(
        (constraints.maxWidth - 320) / 2,
        (constraints.maxHeight - 200) / 2,
      );
    } else {
      switch (step.tooltipPosition) {
        case TooltipPosition.bottom:
          tooltipOffset = Offset(
            targetRect.center.dx - 160,
            targetRect.bottom + 20,
          );
          break;
        case TooltipPosition.top:
          tooltipOffset = Offset(
            targetRect.center.dx - 160,
            targetRect.top - 250,
          );
          break;
        case TooltipPosition.left:
          tooltipOffset = Offset(
            targetRect.left - 340,
            targetRect.center.dy - 100,
          );
          break;
        case TooltipPosition.right:
          tooltipOffset = Offset(
            targetRect.right + 20,
            targetRect.center.dy - 100,
          );
          break;
        default:
          tooltipOffset = const Offset(100, 100);
      }
    }

    // Boundary check
    double x = tooltipOffset.dx.clamp(20, constraints.maxWidth - 340);
    double y = tooltipOffset.dy.clamp(20, constraints.maxHeight - 250);

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
