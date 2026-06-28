import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../application/providers/machine_provider.dart';
import '../../../application/providers/gcode_provider.dart';
import '../../../core/utils/file_picker_service.dart';
import '../../../core/utils/gcode_highlighter.dart';
import '../../tutorial/tutorial_keys.dart';

class GCodeConsolePanel extends ConsumerWidget {
  const GCodeConsolePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gcodeState = ref.watch(gcodeProvider);
    final scrollController = ref.watch(gcodeScrollControllerProvider);
    final machineState = ref.watch(machineStateProvider).valueOrNull;
    final currentIndex = machineState?.activeLineIndex ?? 0;

    ref.listen(machineStateProvider, (previous, next) {
      final oldIndex = previous?.valueOrNull?.activeLineIndex ?? 0;
      final newIndex = next.valueOrNull?.activeLineIndex ?? 0;
      if (newIndex != oldIndex && scrollController.hasClients) {
        final targetOffset = (newIndex * 24.0) - 100;
        scrollController.animateTo(
          targetOffset > 0 ? targetOffset : 0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });

    if (gcodeState.isLoading) {
      return GlassPanel(
        key: TutorialKeys.gcodeConsole,
        title: 'FLUX G-CODE INDUSTRIEL',
        expand: true,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Traitement du G-Code...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (gcodeState.allLines.isEmpty) {
      return GlassPanel(
        key: TutorialKeys.gcodeConsole,
        title: 'FLUX G-CODE INDUSTRIEL',
        expand: true,
        titleTrailing: IconButton(
          icon: const Icon(Icons.file_open, color: AppColors.primary, size: 14),
          onPressed: () => _pickFile(ref),
          tooltip: 'Charger un fichier G-Code',
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AUCUN PROGRAMME CHARGÉ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Importez un fichier G-Code (.nc, .gcode) pour visualiser le parcours d\'outil et piloter la machine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _pickFile(ref),
                  icon: const Icon(Icons.file_open, size: 14),
                  label: const Text(
                    'CHARGER UN FICHIER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GlassPanel(
      key: TutorialKeys.gcodeConsole,
      title: 'FLUX G-CODE INDUSTRIEL',
      expand: true,
      titleTrailing: IconButton(
        icon: const Icon(Icons.file_open, color: AppColors.primary, size: 14),
        onPressed: () => _pickFile(ref),
        tooltip: 'Charger un fichier G-Code',
      ),
      child: ListView.builder(
        controller: scrollController,
        itemCount: gcodeState.allLines.length,
        itemExtent: 24, // Virtualisation haute performance
        itemBuilder: (ctx, i) {
          final isCurrent = i == currentIndex;
          return Container(
            decoration: isCurrent
                ? BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    border: const Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  )
                : null,
            padding: EdgeInsets.only(
              left: isCurrent ? 13.0 : 16.0,
              right: 16.0,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 45,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: isCurrent ? AppColors.primary : AppColors.textDisabled,
                      fontSize: 9,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                      children: GCodeHighlighter.buildSpans(gcodeState.allLines[i], isCurrent),
                    ),
                  ),
                ),
                if (isCurrent)
                  const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                    size: 14,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFile(WidgetRef ref) async {
    final content = await FilePickerService.pickGCodeContent();
    if (content != null) {
      await ref.read(gcodeProvider.notifier).loadFile(content);
    }
  }
}
