import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Contrôleur de texte spécialisé pour le G-Code.
/// Applique une colorimétrie syntaxique temps-réel (G-Code Highlighting).
class GCodeEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    
    // Regex pour les différents éléments du G-Code
    final commentRegex = RegExp(r'(;.*)|(\(.*\))');
    final gCodeRegex = RegExp(r'[GM][0-9]+(\.[0-9]+)?');
    final coordinateRegex = RegExp(r'[XYZACFSIJRKHLP](-?[0-9]*\.?[0-9]+)');
    final lineNumberRegex = RegExp(r'^N[0-9]+', multiLine: true);
    final stringRegex = RegExp(r'".*"');

    text.splitMapJoin(
      RegExp('${commentRegex.pattern}|${gCodeRegex.pattern}|${coordinateRegex.pattern}|${lineNumberRegex.pattern}|${stringRegex.pattern}'),
      onMatch: (Match match) {
        final matchText = match[0]!;
        Color color = AppColors.textPrimary;
        FontWeight weight = FontWeight.normal;

        if (commentRegex.hasMatch(matchText)) {
          color = AppColors.textDisabled; // Commentaires en gris/foncé
        } else if (gCodeRegex.hasMatch(matchText)) {
          color = AppColors.primary; // G/M codes en bleu/néon
          weight = FontWeight.bold;
        } else if (coordinateRegex.hasMatch(matchText)) {
          if (matchText.startsWith('X')) color = AppColors.axisX;
          else if (matchText.startsWith('Y')) color = AppColors.axisY;
          else if (matchText.startsWith('Z')) color = AppColors.axisZ;
          else if (matchText.startsWith('A')) color = AppColors.axisA;
          else if (matchText.startsWith('C')) color = AppColors.axisC;
          else if (matchText.startsWith('F')) color = AppColors.success; // Avance
          else if (matchText.startsWith('S')) color = AppColors.warning; // Broche
          else color = AppColors.secondary;
        } else if (lineNumberRegex.hasMatch(matchText)) {
          color = AppColors.textSecondary.withOpacity(0.5);
        } else if (stringRegex.hasMatch(matchText)) {
          color = AppColors.warning;
        }

        children.add(TextSpan(
          text: matchText,
          style: style?.copyWith(color: color, fontWeight: weight),
        ));
        return matchText;
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: style));
        return nonMatch;
      },
    );

    return TextSpan(style: style, children: children);
  }
}
