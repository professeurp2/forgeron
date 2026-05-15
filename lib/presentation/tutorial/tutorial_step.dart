import 'package:flutter/material.dart';

enum SpotlightShape { circle, roundedRect, none }
enum TooltipPosition { top, bottom, left, right, center }

class TutorialStep {
  final String id;
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final String page;
  final SpotlightShape spotlightShape;
  final TooltipPosition tooltipPosition;
  final IconData icon;
  final Color accentColor;
  final String? action;

  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    this.targetKey,
    required this.page,
    this.spotlightShape = SpotlightShape.roundedRect,
    this.tooltipPosition = TooltipPosition.bottom,
    required this.icon,
    this.accentColor = const Color(0xFF6C63FF),
    this.action,
  });
}
