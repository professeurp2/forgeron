import 'dart:io';

void main() {
  final files = [
    'lib/presentation/screens/tool_table_screen.dart',
    'lib/presentation/tutorial/tutorial_highlight_painter.dart',
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart',
    'lib/presentation/widgets/dashboard/gcode_console_panel.dart',
    'lib/presentation/widgets/dashboard/macros_panel.dart'
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();
    
    if (f.endsWith('tool_table_screen.dart')) {
       // Remove const from `static const _tools = [`
       content = content.replaceAll('static const _tools = [', 'static final _tools = [');
       content = content.replaceAll('static const _tools = const [', 'static final _tools = [');
    }
    else if (f.endsWith('tutorial_highlight_painter.dart')) {
       // Fix duplicate definitions and fix the constructor
       content = content.replaceAll('Color? highlightColor;', 'late final Color highlightColor;');
       content = content.replaceAll('Color? overlayColor;', 'late final Color overlayColor;');
       // Clean up any double `late final`
       content = content.replaceAll('late final late final', 'late final');
       // The original was probably:
       // late final Color highlightColor;
       // late final Color overlayColor;
       // And my replace did it wrong. Let's just restore it cleanly.
       
       // I'll leave the duplicate cleanup to dart formatting or just do it by matching.
       // Actually let's just do a manual replacement for this small file:
       content = content.replaceAll(
'''class TutorialHighlightPainter extends CustomPainter {
  final Rect targetRect;
  final double progress;
  late final late final Color highlightColor;
  late final late final Color overlayColor;''',
'''class TutorialHighlightPainter extends CustomPainter {
  final Rect targetRect;
  final double progress;
  late final Color highlightColor;
  late final Color overlayColor;''');

      content = content.replaceAll('late final Color? highlightColor;', 'late final Color highlightColor;');
      content = content.replaceAll('late final Color? overlayColor;', 'late final Color overlayColor;');
      content = content.replaceAll('Color? Color? highlightColor', 'Color? highlightColor');
      content = content.replaceAll('Color? Color? overlayColor', 'Color? overlayColor');
    }
    else if (f.endsWith('trunnion_visualizer_web.dart') || f.endsWith('trunnion_visualizer_windows.dart')) {
       content = content.replaceAll('this.color = AppColors.axisA', 'this.color = Colors.orange');
       content = content.replaceAll('this.color = AppColors.axisC', 'this.color = Colors.cyan');
    }
    else if (f.endsWith('gcode_console_panel.dart') || f.endsWith('macros_panel.dart')) {
       // Remove `const [` that wraps AppColors.
       content = content.replaceAll('const [', '[');
    }
    
    file.writeAsStringSync(content);
  }
}
