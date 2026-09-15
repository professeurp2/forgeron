import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/forgeron_colors.dart';
import 'tutorial_step.dart';
import '../../core/i18n/app_localizations.dart';

class TutorialTooltipCard extends StatelessWidget {
  final TutorialStep step;
  final int currentIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const TutorialTooltipCard({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (value * 0.05),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        // 340 px en dur touchait les deux bords d'un écran de 360 dp
        // (Galaxy A03s) : on garde 16 px de marge de chaque côté.
        width: math.min(340.0, MediaQuery.sizeOf(context).width - 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Neon Glow based on accent color
            BoxShadow(
              color: step.accentColor.withValues(alpha: 0.25),
              blurRadius: 32,
              spreadRadius: 4,
            ),
            // Deep ambient industrial shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF161D36).withValues(alpha: 0.85),
                    Color(0xFF0D1224).withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: step.accentColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Top inner subtle glass reflection highlight
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Cyberpunk side accent indicator bar
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: step.accentColor,
                        boxShadow: [
                          BoxShadow(
                            color: step.accentColor,
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Main content padding
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            // Glowing Icon Container
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: step.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: step.accentColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                step.icon,
                                color: step.accentColor,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Step indicator badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: step.accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tr('ÉTAPE {} / {}', [currentIndex + 1, totalSteps]),
                                      style: TextStyle(
                                        color: step.accentColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'JetBrains Mono',
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    tr(step.title),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),

                        // Description
                        Text(
                          tr(step.description),
                          style: TextStyle(
                            color: Color(0xFFB4BACD),
                            fontSize: 12,
                            height: 1.5,
                            letterSpacing: 0.2,
                          ),
                        ),

                        // Action Button (Optional)
                        if (step.action != null) ...[
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [
                                  step.accentColor.withValues(alpha: 0.2),
                                  step.accentColor.withValues(alpha: 0.05),
                                ],
                              ),
                              border: Border.all(
                                color: step.accentColor.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: onNext,
                              borderRadius: BorderRadius.circular(8),
                              child: Center(
                                child: Text(
                                  tr(step.action!),
                                  style: TextStyle(
                                    color: step.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 20),

                        // Footer Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Skip or Previous button
                            SizedBox(
                              height: 32,
                              child: TextButton(
                                onPressed: currentIndex == 0 ? onSkip : onPrevious,
                                style: TextButton.styleFrom(
                                  foregroundColor: context.fc.textDisabled,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                ),
                                child: Text(
                                  currentIndex == 0 ? 'PASSER' : '← PRÉC.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            // Dynamic smooth animated dots
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                5,
                                (index) {
                                  final dotIndex = (currentIndex - 2 + index)
                                      .clamp(0, totalSteps - 1);
                                  final isActive = dotIndex == currentIndex;
                                  
                                  // Don't duplicate start/end dots visually if at limits
                                  if (index > 0) {
                                    final prevDotIndex = (currentIndex - 2 + (index - 1))
                                        .clamp(0, totalSteps - 1);
                                    if (dotIndex == prevDotIndex) return const SizedBox.shrink();
                                  }

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutQuart,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: isActive ? 16 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: isActive
                                          ? step.accentColor
                                          : (dotIndex < currentIndex
                                              ? context.fc.success.withValues(alpha: 0.5)
                                              : Color(0xFF2A3050)),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: step.accentColor.withValues(alpha: 0.5),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Next or Finish button
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: onNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: step.accentColor,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  currentIndex == totalSteps - 1 ? 'FINIR' : 'SUIV.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
