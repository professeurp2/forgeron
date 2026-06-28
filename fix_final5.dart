import 'dart:io';

void main() {
  final files = [
    'lib/presentation/screens/mdi_terminal_screen.dart',
    'lib/presentation/screens/mobile_screens.dart',
    'lib/presentation/screens/mobile_dashboard_screen.dart',
    'lib/presentation/tutorial/tutorial_step.dart',
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart'
  ];

  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();

    // Fix static const variables initialized with arrays (lists) by converting them to static getters
    content = content.replaceAllMapped(
      RegExp(r'static\s+const\s+(_[a-zA-Z0-9_]+)\s*=\s*\['), 
      (match) => 'static get ${match.group(1)} => ['
    );
    // Same if there is `const [` after the `=`
    content = content.replaceAllMapped(
      RegExp(r'static\s+const\s+(_[a-zA-Z0-9_]+)\s*=\s*const\s*\['), 
      (match) => 'static get ${match.group(1)} => ['
    );
    // Replace all instances of AppColors in these UI config lists with dynamic evaluation or standard Material Colors 
    // Actually, making them a getter solves the `const` list literal evaluation issue, 
    // but wait! A getter returning `[` will STILL be a const literal if we didn't remove `const` inside it!
    // But `[` without `const` before it is NOT a const literal.
    
    // BUT what about `const` keywords throughout the UI tree in mobile_screens.dart?
    // Things like `const Icon(..., color: AppColors.primary)`
    // They will fail because AppColors.primary is not a constant anymore.
    // I will replace `AppColors.` inside ANY `const` declaration with standard Colors.
    // However, the easiest way to remove `const` from `const Icon(..., color: AppColors...` is to remove the word `const` entirely!
    
    content = content.replaceAll('const CircularProgressIndicator(', 'CircularProgressIndicator(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const SizedBox(', 'SizedBox(');
    content = content.replaceAll('const Divider(', 'Divider(');
    content = content.replaceAll('const OutlineInputBorder(', 'OutlineInputBorder(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const EdgeInsets.', 'EdgeInsets.');
    content = content.replaceAll('const TextStyle(', 'TextStyle(');

    // Fix the specific default parameters in the constructors
    if (f.endsWith('tutorial_step.dart')) {
      content = content.replaceAll('this.color = AppColors.primary', 'this.color = const Color(0xFF2196F3)');
    }
    else if (f.endsWith('trunnion_visualizer_web.dart') || f.endsWith('trunnion_visualizer_windows.dart')) {
      content = content.replaceAll('this.color = AppColors.axisA', 'this.color = const Color(0xFFFF9800)');
      content = content.replaceAll('this.color = AppColors.axisC', 'this.color = const Color(0xFF00BCD4)');
    }

    file.writeAsStringSync(content);
  }
}
