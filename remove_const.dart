import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('core\\theme') || file.path.contains('core/theme')) {
      continue;
    }
    
    var content = file.readAsStringSync();
    var originalContent = content;

    // Remove const in front of widgets that use AppColors or AppTextStyles
    // A simple approach is to just remove 'const ' from specific constructors globally
    // This is safe because Dart doesn't mandate const, it just recommends it for performance.
    final regexes = [
      RegExp(r'const\s+TextStyle\('),
      RegExp(r'const\s+Icon\('),
      RegExp(r'const\s+BorderSide\('),
      RegExp(r'const\s+Border\('),
      RegExp(r'const\s+BoxDecoration\('),
      RegExp(r'const\s+Divider\('),
      RegExp(r'const\s+LinearProgressIndicator\('),
      RegExp(r'const\s+Color\('),
      RegExp(r'const\s+Padding\('),
      RegExp(r'const\s+Text\('),
      RegExp(r'const\s+SizedBox\('),
      RegExp(r'const\s+Center\('),
      RegExp(r'const\s+Row\('),
      RegExp(r'const\s+Column\('),
    ];

    // For better precision, only remove 'const' if the line contains AppColors or AppTextStyles.
    // Wait, it can be multiline. So let's just blindly remove 'const ' for these widgets everywhere.
    for (final r in regexes) {
      content = content.replaceAll(r, r.pattern.replaceAll(r'const\s+', '').replaceAll(r'\(', '('));
    }

    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const Border(', 'Border(');
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const Divider(', 'Divider(');
    content = content.replaceAll('const LinearProgressIndicator(', 'LinearProgressIndicator(');
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const Text(', 'Text(');

    // Also fix withOpacity
    content = content.replaceAllMapped(RegExp(r'\.withOpacity\((.*?)\)'), (m) => '.withValues(alpha: ${m[1]})');

    if (content != originalContent) {
      file.writeAsStringSync(content);
      print('Fixed consts in: ${file.path}');
    }
  }
}
