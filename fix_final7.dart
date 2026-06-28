import 'dart:io';

void main() {
  // Fix 1: glass_panel.dart line 24
  var f1 = File('lib/core/widgets/glass_panel.dart');
  var lines = f1.readAsLinesSync();
  lines[23] = '    this.padding = const EdgeInsets.all(16),';
  f1.writeAsStringSync(lines.join('\n'));

  // Fix 2: file_manager_screen.dart line 80
  var f2 = File('lib/presentation/screens/file_manager_screen.dart');
  lines = f2.readAsLinesSync();
  // let's just strip 'const ' from line 80
  lines[79] = lines[79].replaceAll('const ', '');
  f2.writeAsStringSync(lines.join('\n'));

  // Fix 3: main_scaffold.dart line 588
  var f3 = File('lib/presentation/screens/main_scaffold.dart');
  lines = f3.readAsLinesSync();
  lines[587] = lines[587].replaceAll('const ', '');
  f3.writeAsStringSync(lines.join('\n'));

  // Fix 4: mobile_dashboard_screen.dart line 769
  var f4 = File('lib/presentation/screens/mobile_dashboard_screen.dart');
  lines = f4.readAsLinesSync();
  lines[768] = lines[768].replaceAll('const ', '');
  f4.writeAsStringSync(lines.join('\n'));

  // Fix 5: mobile_screens.dart line 1369
  var f5 = File('lib/presentation/screens/mobile_screens.dart');
  lines = f5.readAsLinesSync();
  lines[1368] = lines[1368].replaceAll('const ', '');
  f5.writeAsStringSync(lines.join('\n'));

  // Fix 6: tutorial_step.dart
  var f6 = File('lib/presentation/tutorial/tutorial_step.dart');
  var txt = f6.readAsStringSync();
  txt = txt.replaceAll('this.color = AppColors.primary', 'this.color = const Color(0xFF2196F3)');
  f6.writeAsStringSync(txt);

  // Fix 7 & 8: trunnion_visualizer_*.dart
  for (final path in ['lib/presentation/widgets/trunnion_visualizer_web.dart', 'lib/presentation/widgets/trunnion_visualizer_windows.dart']) {
    var f7 = File(path);
    if (!f7.existsSync()) continue;
    txt = f7.readAsStringSync();
    txt = txt.replaceAll('this.color = AppColors.axisA', 'this.color = const Color(0xFFFF9800)');
    txt = txt.replaceAll('this.color = AppColors.axisC', 'this.color = const Color(0xFF00BCD4)');
    f7.writeAsStringSync(txt);
  }
}
