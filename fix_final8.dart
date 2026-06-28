import 'dart:io';

void main() {
  var f1 = File('lib/presentation/screens/file_manager_screen.dart');
  var txt = f1.readAsStringSync();
  txt = txt.replaceAll('const SnackBar(', 'SnackBar(');
  f1.writeAsStringSync(txt);

  var f2 = File('lib/presentation/screens/main_scaffold.dart');
  txt = f2.readAsStringSync();
  txt = txt.replaceAll('const CircleAvatar(', 'CircleAvatar(');
  f2.writeAsStringSync(txt);

  var f3 = File('lib/presentation/screens/mobile_dashboard_screen.dart');
  txt = f3.readAsStringSync();
  txt = txt.replaceAll('const Center(', 'Center(');
  txt = txt.replaceAll('const Text(', 'Text(');
  txt = txt.replaceAll('const Icon(', 'Icon(');
  f3.writeAsStringSync(txt);

  var f4 = File('lib/presentation/screens/mobile_screens.dart');
  txt = f4.readAsStringSync();
  txt = txt.replaceAll('const Padding(', 'Padding(');
  txt = txt.replaceAll('const Column(', 'Column(');
  txt = txt.replaceAll('const Text(', 'Text(');
  txt = txt.replaceAll('const Icon(', 'Icon(');
  txt = txt.replaceAll('const SizedBox(', 'SizedBox(');
  f4.writeAsStringSync(txt);

  var f5 = File('lib/presentation/tutorial/tutorial_step.dart');
  txt = f5.readAsStringSync();
  txt = txt.replaceAll('this.color = AppColors.primary', 'this.color = const Color(0xFF2196F3)');
  txt = txt.replaceAll('this.color = const AppColors.primary', 'this.color = const Color(0xFF2196F3)');
  f5.writeAsStringSync(txt);

  var f6 = File('lib/presentation/widgets/trunnion_visualizer_web.dart');
  txt = f6.readAsStringSync();
  txt = txt.replaceAll('this.color = AppColors.axisA', 'this.color = const Color(0xFFFF9800)');
  txt = txt.replaceAll('this.color = AppColors.axisC', 'this.color = const Color(0xFF00BCD4)');
  f6.writeAsStringSync(txt);

  var f7 = File('lib/presentation/widgets/trunnion_visualizer_windows.dart');
  txt = f7.readAsStringSync();
  txt = txt.replaceAll('this.color = AppColors.axisA', 'this.color = const Color(0xFFFF9800)');
  txt = txt.replaceAll('this.color = AppColors.axisC', 'this.color = const Color(0xFF00BCD4)');
  f7.writeAsStringSync(txt);
}
