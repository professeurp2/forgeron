import 'dart:io';

void main() {
  final files = [
    'lib/presentation/screens/mdi_terminal_screen.dart',
    'lib/presentation/screens/mobile_screens.dart',
    'lib/presentation/screens/mobile_dashboard_screen.dart',
    'lib/presentation/tutorial/tutorial_highlight_painter.dart',
    'lib/presentation/tutorial/tutorial_step.dart',
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart'
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();

    // 1. Convert `static const _xxx = [` to `static get _xxx => [`
    content = content.replaceAll(RegExp(r'static\s+const\s+(_[a-zA-Z0-9_]+)\s*=\s*\['), r'static get $1 => [');
    // also for const [
    content = content.replaceAll(RegExp(r'static\s+const\s+(_[a-zA-Z0-9_]+)\s*=\s*const\s*\['), r'static get $1 => [');
    
    // 2. Fix the specific default parameters
    if (f.endsWith('tutorial_highlight_painter.dart')) {
      content = content.replaceAll('Color highlightColor = AppColors.primary', 'Color highlightColor = Colors.blue');
      content = content.replaceAll('Color overlayColor = AppColors.surfaceHigh', 'Color overlayColor = Colors.grey');
    }
    else if (f.endsWith('tutorial_step.dart')) {
      content = content.replaceAll('this.color = AppColors.primary', 'this.color = Colors.blue');
    }
    else if (f.endsWith('trunnion_visualizer_web.dart') || f.endsWith('trunnion_visualizer_windows.dart')) {
      content = content.replaceAll('this.color = AppColors.axisA', 'this.color = Colors.orange');
      content = content.replaceAll('this.color = AppColors.axisC', 'this.color = Colors.cyan');
    }

    file.writeAsStringSync(content);
  }
}
