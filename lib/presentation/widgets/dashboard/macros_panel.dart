import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../domain/models/macro.dart';
import '../../tutorial/tutorial_keys.dart';
import '../../../application/providers/di_providers.dart';
import '../../../core/widgets/glass_panel.dart';

class MacrosPanel extends ConsumerWidget {
  const MacrosPanel({super.key});

  IconData _getIconData(String name) {
    switch (name) {
      case 'center_focus_strong': return Icons.center_focus_strong;
      case 'build': return Icons.build;
      case 'cleaning_services': return Icons.cleaning_services;
      case 'timer': return Icons.timer;
      case 'play_circle_filled': return Icons.play_circle_filled;
      default: return Icons.extension;
    }
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassPanel(
      key: TutorialKeys.macrosPanel,
      title: 'MACROS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, 
        children: [
          for (final m in defaultMacros)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  final repo = ref.read(machineRepositoryProvider);
                  if (m.gcode == 'EXEC_LOADED_GCODE') {
                    final gcodeState = ref.read(gcodeProvider);
                    if (gcodeState.allLines.isNotEmpty) {
                      repo.sendGCodeBatch(gcodeState.allLines);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('▶ Exécution du G-Code lancée'),
                        backgroundColor: AppColors.primary,
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('⚠️ Aucun G-Code chargé à exécuter'),
                        backgroundColor: AppColors.warning,
                      ));
                    }
                    return;
                  }
                  final lines = m.gcode.split('\n').where((l) => l.trim().isNotEmpty).toList();
                  for (int i = 0; i < lines.length; i++) {
                    Future.delayed(Duration(milliseconds: i * 200), () {
                      repo.sendGCode(lines[i].trim());
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _hexToColor(m.colorHex).withOpacity(0.1),
                    border: Border.all(color: _hexToColor(m.colorHex).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(children: [
                    Icon(_getIconData(m.iconName), color: _hexToColor(m.colorHex), size: 16),
                    const SizedBox(width: 12),
                    Expanded(child: Text(m.name, style: TextStyle(color: _hexToColor(m.colorHex), fontSize: 10, fontWeight: FontWeight.bold))),
                  ]),
                ),
              ),
            ),
        ]
      ),
    );
  }
}
