import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: isActive ? color : color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : color.withValues(alpha: 0.5),
              boxShadow: isActive ? [BoxShadow(color: color, blurRadius: 8)] : null,
            ),
          ),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              fontFamily: 'JetBrains Mono',
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
