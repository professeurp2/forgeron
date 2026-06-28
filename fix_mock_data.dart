import 'dart:io';

void main() {
  final files = [
    'lib/presentation/screens/tool_table_screen.dart',
    'lib/presentation/screens/probing_screen.dart',
    'lib/presentation/widgets/dashboard/macros_panel.dart'
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();
    
    // Replace AppColors inside lists with static Colors
    content = content.replaceAll('AppColors.success', 'Colors.green');
    content = content.replaceAll('AppColors.warning', 'Colors.orange');
    content = content.replaceAll('AppColors.error', 'Colors.red');
    content = content.replaceAll('AppColors.info', 'Colors.blue');
    content = content.replaceAll('AppColors.primary', 'Colors.deepOrange');
    content = content.replaceAll('AppColors.secondary', 'Colors.cyan');
    content = content.replaceAll('AppColors.textSecondary', 'Colors.grey');

    file.writeAsStringSync(content);
  }
}
