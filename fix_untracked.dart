import 'dart:io';

void main() {
  final file = File('lib/presentation/widgets/dashboard/gauge_widgets.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('context.colors.', 'AppColors.');
  content = content.replaceAll('context.typography.', 'AppTextStyles.');
  file.writeAsStringSync(content);
  print('Fixed gauge_widgets.dart');
}
