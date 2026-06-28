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

    // Remplacements simples
    content = content.replaceAll('AppColors.', 'context.colors.');
    content = content.replaceAll('AppTextStyles.', 'context.typography.');

    if (content != originalContent) {
      file.writeAsStringSync(content);
      print('Updated: ${file.path}');
    }
  }
}
