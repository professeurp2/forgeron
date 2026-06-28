import 'dart:io';

void main() async {
  final files = [
    'lib/core/widgets/glass_panel.dart',
    'lib/presentation/screens/diagnostics_screen.dart',
    'lib/presentation/screens/file_manager_screen.dart',
    'lib/presentation/screens/main_scaffold.dart',
    'lib/presentation/screens/mobile_dashboard_screen.dart',
    'lib/presentation/screens/mobile_screens.dart',
    'lib/presentation/tutorial/tutorial_step.dart',
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart'
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();
    
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const EdgeInsets.', 'EdgeInsets.');
    content = content.replaceAll('const EdgeInsets(', 'EdgeInsets(');
    content = content.replaceAll('const SizedBox(', 'SizedBox(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const BoxShadow(', 'BoxShadow(');
    content = content.replaceAll('const Expanded(', 'Expanded(');
    content = content.replaceAll('const Container(', 'Container(');
    content = content.replaceAll('const Center(', 'Center(');
    content = content.replaceAll('const Column(', 'Column(');
    content = content.replaceAll('const Row(', 'Row(');
    content = content.replaceAll('const ListView(', 'ListView(');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const LinearProgressIndicator(', 'LinearProgressIndicator(');
    content = content.replaceAll('const CircularProgressIndicator(', 'CircularProgressIndicator(');
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const Tooltip(', 'Tooltip(');
    content = content.replaceAll('const FractionalOffset(', 'FractionalOffset(');
    content = content.replaceAll('const Alignment(', 'Alignment(');
    content = content.replaceAll('const NetworkImage(', 'NetworkImage(');
    
    // Default params
    if (f.endsWith('glass_panel.dart')) {
      content = content.replaceAll('this.borderColor = AppColors.surfaceBorder', 'this.borderColor = Colors.grey');
      content = content.replaceAll('this.backgroundColor = AppColors.surface', 'this.backgroundColor = Colors.black');
    }

    file.writeAsStringSync(content);
    print('Fixed consts in \$f');
  }
}
