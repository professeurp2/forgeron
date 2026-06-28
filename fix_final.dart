import 'dart:io';

void main() {
  var files = [
    'lib/presentation/screens/mobile_screens.dart',
    'lib/presentation/screens/probing_screen.dart',
    'lib/presentation/tutorial/tutorial_highlight_painter.dart',
    'lib/presentation/tutorial/tutorial_step.dart',
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart'
  ];
  
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();

    if (f.endsWith('mobile_screens.dart')) {
      // Fix tools const list
      content = content.replaceAll('static const _tools = [', 'static final _tools = [');
      content = content.replaceAll('static const _tools = const [', 'static final _tools = [');
      content = content.replaceAll('AppColors.success', 'Colors.green');
      content = content.replaceAll('AppColors.warning', 'Colors.orange');
      content = content.replaceAll('AppColors.error', 'Colors.red');
      content = content.replaceAll('AppColors.info', 'Colors.blue');
      
      // Fix CircularProgressIndicator inside MobileToolTableScreen
      content = content.replaceAll(
          'const CircularProgressIndicator(\n                                    value: 0.68,\n                                    strokeWidth: 8,\n                                    backgroundColor: AppColors.surfaceBright,\n                                    color: Colors.green)',
          'const CircularProgressIndicator(\n                                    value: 0.68,\n                                    strokeWidth: 8,\n                                    backgroundColor: Colors.grey,\n                                    color: Colors.green)'
      );
      // Fallback
      content = content.replaceAll('backgroundColor: AppColors.surfaceBright', 'backgroundColor: Colors.grey');
    }
    else if (f.endsWith('probing_screen.dart')) {
      content = content.replaceAll('static const _axisColors = [', 'static final _axisColors = [');
    }
    else if (f.endsWith('tutorial_highlight_painter.dart')) {
      content = content.replaceAll('late final Color overlayColor;\n  late final Color overlayColor;', 'late final Color overlayColor;');
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
