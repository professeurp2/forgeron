import 'package:flutter/material.dart';
import '../../core/theme/forgeron_colors.dart';
import '../../core/utils/gcode_tool_extractor.dart';

/// Photo d'un outil, choisie d'après la forme déduite du descriptif G-code.
///
/// Quand le programme ne dit pas de quel type d'outil il s'agit
/// ([ToolShape.unknown]), on affiche une silhouette neutre plutôt qu'une photo
/// par défaut : montrer une fraise là où un foret est monté tromperait
/// l'opérateur au pire moment, celui du changement d'outil.
///
/// Partagée par le magasin d'outils mobile et desktop — la photo doit être la
/// même des deux côtés.
class ToolPhoto extends StatelessWidget {
  const ToolPhoto({super.key, required this.shape, required this.size});

  final ToolShape shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final identified = shape != ToolShape.unknown;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fc.terminalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fc.surfaceBorder),
      ),
      child: identified
          ? Image.asset(shape.asset, fit: BoxFit.contain)
          : Icon(Icons.help_outline, color: fc.textDisabled, size: size * 0.45),
    );
  }
}
