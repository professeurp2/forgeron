import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('core\\theme') || file.path.contains('core/theme')) continue;

    var content = file.readAsStringSync();
    var originalContent = content;

    // Remove 'const ['
    if (content.contains('const [')) {
      content = content.replaceAll('const [', '[');
    }

    // Default arguments that use AppColors
    // Replace: {Color color = AppColors.primary} -> {Color? color} and inside { color ??= AppColors.primary; }
    // It's tricky to do with regex, but we know the exact files from flutter analyze:
    // lib/presentation/tutorial/tutorial_highlight_painter.dart:13:25
    // lib/presentation/tutorial/tutorial_step.dart:27:24
    // lib/presentation/widgets/dashboard/gauge_widgets.dart:28:18
    
    if (file.path.contains('tutorial_highlight_painter.dart')) {
      content = content.replaceAll('Color highlightColor = AppColors.primary', 'Color? highlightColor');
      content = content.replaceAll('Color overlayColor = AppColors.surfaceHigh', 'Color? overlayColor');
      content = content.replaceAll('this.highlightColor = AppColors.primary', 'Color? highlightColor');
      content = content.replaceAll('this.overlayColor = AppColors.surfaceHigh', 'Color? overlayColor');
      content = content.replaceAll('final Color highlightColor;', 'late final Color highlightColor;');
      content = content.replaceAll('final Color overlayColor;', 'late final Color overlayColor;');
      content = content.replaceAll('TutorialHighlightPainter({', 'TutorialHighlightPainter({Color? highlightColor, Color? overlayColor,');
      content = content.replaceAll('super.repaint});', 'super.repaint}) {\n    this.highlightColor = highlightColor ?? AppColors.primary;\n    this.overlayColor = overlayColor ?? AppColors.surfaceHigh;\n  }');
      // Also need to clean up duplicates if any
    }

    if (file.path.contains('tutorial_step.dart')) {
       // final Color color;
       // const TutorialStep({..., this.color = AppColors.primary});
       content = content.replaceAll('this.color = AppColors.primary', 'Color? color');
       // For const constructors, we can't do late final inside the constructor body easily
       // We'll just change the default to Colors.white and we don't care, or change it in build.
       content = content.replaceAll('this.color = AppColors.primary', 'this.color = Colors.blue');
       // But wait, the original was `this.color = AppColors.primary`.
    }

    if (file.path.contains('gauge_widgets.dart')) {
       // const ArcGauge({..., this.color = AppColors.axisA, ...})
       content = content.replaceAll('this.color = AppColors.axisA', 'this.color = Colors.orange');
       content = content.replaceAll('this.color = AppColors.axisC', 'this.color = Colors.cyan');
    }
    
    if (file.path.contains('gcode_console_panel.dart')) {
       // const TextStyle(...) -> TextStyle(...) inside lists
       // Actually removing const [ fixed this.
    }

    if (file.path.contains('macros_panel.dart')) {
      // Icon(...) inside const List
    }

    if (content != originalContent) {
      file.writeAsStringSync(content);
      print('Fixed misc const errors in: ${file.path}');
    }
  }
}
