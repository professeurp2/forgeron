import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GCodeHighlighter {
  GCodeHighlighter._();

  static List<InlineSpan> buildSpans(String line, bool isCurrent) {
    if (line.isEmpty) return [];

    final trimmed = line.trim();
    if (trimmed.startsWith(';')) {
      return [
        TextSpan(
          text: line,
          style: TextStyle(
            color: isCurrent 
                ? AppColors.textSecondary.withValues(alpha: 0.8) 
                : AppColors.textDisabled.withValues(alpha: 0.8),
            fontStyle: FontStyle.italic,
          ),
        )
      ];
    }

    final List<InlineSpan> spans = [];
    final RegExp regex = RegExp(
      r'(;.*)|(\([^\)]*\))|([GM]\d+(?:\.\d+)?)|([XYZAC][\-+]?\d*\.?\d*)|([FS][\-+]?\d*\.?\d*)|([NTPD][\-+]?\d*\.?\d*)',
      caseSensitive: false,
    );

    int lastIndex = 0;
    for (final Match match in regex.allMatches(line)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: line.substring(lastIndex, match.start),
          style: TextStyle(color: isCurrent ? Colors.white : AppColors.textSecondary),
        ));
      }

      final String token = match.group(0)!;
      Color color;
      FontWeight weight = FontWeight.normal;

      if (match.group(1) != null || match.group(2) != null) {
        color = isCurrent ? AppColors.textSecondary.withValues(alpha: 0.7) : AppColors.textDisabled;
      } else if (match.group(3) != null) {
        color = AppColors.primary;
        weight = FontWeight.bold;
      } else if (match.group(4) != null) {
        final axis = token[0].toUpperCase();
        switch (axis) {
          case 'X':
            color = AppColors.axisX;
            break;
          case 'Y':
            color = AppColors.axisY;
            break;
          case 'Z':
            color = AppColors.axisZ;
            break;
          case 'A':
            color = AppColors.axisA;
            break;
          case 'C':
            color = AppColors.axisC;
            break;
          default:
            color = Colors.white;
        }
      } else if (match.group(5) != null) {
        color = AppColors.warning;
        weight = FontWeight.bold;
      } else if (match.group(6) != null) {
        color = AppColors.secondary;
      } else {
        color = isCurrent ? Colors.white : AppColors.textPrimary;
      }

      spans.add(TextSpan(
        text: token,
        style: TextStyle(
          color: color,
          fontWeight: weight,
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastIndex),
        style: TextStyle(color: isCurrent ? Colors.white : AppColors.textSecondary),
      ));
    }

    return spans;
  }
}
