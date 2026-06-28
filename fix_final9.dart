import 'dart:io';

void main() {
  // Fix 1: InputDecoration consts
  for (final path in [
    'lib/presentation/screens/mobile_screens.dart',
    'lib/presentation/screens/mobile_dashboard_screen.dart'
  ]) {
    var f = File(path);
    if (!f.existsSync()) continue;
    var txt = f.readAsStringSync();
    txt = txt.replaceAll('const InputDecoration(', 'InputDecoration(');
    f.writeAsStringSync(txt);
  }

  // Fix 2: SnackBar
  var f = File('lib/presentation/screens/file_manager_screen.dart');
  var txt = f.readAsStringSync();
  txt = txt.replaceAll('const SnackBar(', 'SnackBar(');
  f.writeAsStringSync(txt);

  // Fix 3: trunnion_visualizer lists
  for (final path in [
    'lib/presentation/widgets/trunnion_visualizer_web.dart',
    'lib/presentation/widgets/trunnion_visualizer_windows.dart'
  ]) {
    var f2 = File(path);
    if (!f2.existsSync()) continue;
    var text = f2.readAsStringSync();
    text = text.replaceAll('this.machineLimits = [200.0, 300.0, 150.0],', 'this.machineLimits = const [200.0, 300.0, 150.0],');
    f2.writeAsStringSync(text);
  }

  // Fix 4: tutorial_step default Color
  var f3 = File('lib/presentation/tutorial/tutorial_step.dart');
  var text = f3.readAsStringSync();
  text = text.replaceAll('this.accentColor = Color(0xFF6C63FF),', 'this.accentColor = const Color(0xFF6C63FF),');
  f3.writeAsStringSync(text);
}
