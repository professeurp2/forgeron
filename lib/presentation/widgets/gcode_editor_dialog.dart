import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/gcode_provider.dart';
import '../../core/theme/forgeron_colors.dart';

class GCodeEditorDialog extends ConsumerStatefulWidget {
  const GCodeEditorDialog({super.key});

  @override
  ConsumerState<GCodeEditorDialog> createState() => _GCodeEditorDialogState();
}

class _GCodeEditorDialogState extends ConsumerState<GCodeEditorDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final gcodeState = ref.read(gcodeProvider);
    _controller = TextEditingController(text: gcodeState.allLines.join('\n'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.fc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ÉDITEUR G-CODE',
              style: TextStyle(
                color: context.fc.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  color: context.fc.primary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.fc.surfaceBright,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.fc.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.fc.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.fc.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'ANNULER',
                    style: TextStyle(color: context.fc.textDisabled),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.fc.primary,
                    foregroundColor: context.fc.surface,
                  ),
                  onPressed: () {
                    // Recharge le G-Code modifié dans le provider
                    ref.read(gcodeProvider.notifier).loadFile(_controller.text);
                    Navigator.of(context).pop();
                  },
                  child: const Text('APPLIQUER'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
