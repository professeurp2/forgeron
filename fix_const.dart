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

    // 1. Enlever les "const" devant les widgets qui utilisent le contexte maintenant
    final regexes = [
      RegExp(r'const\s+TextStyle\('),
      RegExp(r'const\s+Icon\('),
      RegExp(r'const\s+BorderSide\('),
      RegExp(r'const\s+Border\('),
      RegExp(r'const\s+BoxDecoration\('),
      RegExp(r'const\s+Divider\('),
      RegExp(r'const\s+LinearProgressIndicator\('),
      RegExp(r'const\s+Color\('),
    ];

    for (final r in regexes) {
      // On remplace "const Widget(" par "Widget("
      // Mais attention, on ne doit le faire QUE si ça contient context.colors plus loin.
      // C'est un peu dur avec un simple regex, donc on le fait globalement (pas grave si certains TextStyle perdent leur const, le compilo s'en fout, ou on remettra avec dart fix).
      content = content.replaceAll(r, r.pattern.replaceAll(r'const\s+', '').replaceAll(r'\(', '('));
    }

    // "const TextStyle(" -> "TextStyle("
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const Border(', 'Border(');
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const Divider(', 'Divider(');
    content = content.replaceAll('const LinearProgressIndicator(', 'LinearProgressIndicator(');

    // 2. Réparer withOpacity -> withValues(alpha: ...)
    content = content.replaceAllMapped(RegExp(r'\.withOpacity\((.*?)\)'), (m) => '.withValues(alpha: ${m[1]})');

    // 3. Injecter context dans les méthodes d'aide qui n'en ont pas
    // C'est spécifique aux fichiers listés, on va faire des remplacements précis
    if (file.path.contains('workshop_layout.dart')) {
      content = content.replaceAll('Widget _axis(String name, double pos, Color color) {', 'Widget _axis(BuildContext context, String name, double pos, Color color) {');
      content = content.replaceAll('_axis(\'X\',', '_axis(context, \'X\',');
      content = content.replaceAll('_axis(\'Y\',', '_axis(context, \'Y\',');
      content = content.replaceAll('_axis(\'Z\',', '_axis(context, \'Z\',');
      
      content = content.replaceAll('Widget _miniAxis(String name, double pos, Color color) {', 'Widget _miniAxis(BuildContext context, String name, double pos, Color color) {');
      content = content.replaceAll('_miniAxis(\'A\',', '_miniAxis(context, \'A\',');
      content = content.replaceAll('_miniAxis(\'C\',', '_miniAxis(context, \'C\',');

      content = content.replaceAll('Widget _gaugeRow(String label, double val, double max, Color color, String unit) {', 'Widget _gaugeRow(BuildContext context, String label, double val, double max, Color color, String unit) {');
      content = content.replaceAll('_gaugeRow(\'AVANCE', '_gaugeRow(context, \'AVANCE');
      content = content.replaceAll('_gaugeRow(\'BROCHE', '_gaugeRow(context, \'BROCHE');

      content = content.replaceAll('Widget _hmiButton(IconData icon, String label, Color color, VoidCallback onTap, {bool isLarge = false}) {', 'Widget _hmiButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap, {bool isLarge = false}) {');
      content = content.replaceAll('_hmiButton(Icons', '_hmiButton(context, Icons');
    }

    if (file.path.contains('overrides_panel.dart')) {
      content = content.replaceAll('Widget _ovRow(String label, double val, Color color) {', 'Widget _ovRow(BuildContext context, String label, double val, Color color) {');
      content = content.replaceAll('_ovRow(\'AVANCE', '_ovRow(context, \'AVANCE');
      content = content.replaceAll('_ovRow(\'RAPIDE', '_ovRow(context, \'RAPIDE');
      content = content.replaceAll('_ovRow(\'BROCHE', '_ovRow(context, \'BROCHE');

      content = content.replaceAll('Widget _dynRow(String label, String value, Color color) {', 'Widget _dynRow(BuildContext context, String label, String value, Color color) {');
      content = content.replaceAll('_dynRow(\'AVANCE', '_dynRow(context, \'AVANCE');
      content = content.replaceAll('_dynRow(\'VITESSE', '_dynRow(context, \'VITESSE');

      content = content.replaceAll('Widget _modalRow(String label, String value, Color color) =>', 'Widget _modalRow(BuildContext context, String label, String value, Color color) =>');
      content = content.replaceAll('_modalRow(\'WCS', '_modalRow(context, \'WCS');
      content = content.replaceAll('_modalRow(\'OUTIL', '_modalRow(context, \'OUTIL');
    }

    if (file.path.contains('tool_preview.dart')) {
       // C'est un CustomPainter ! Il n'a pas accès à context. On doit lui passer les couleurs dans le constructeur.
       // On va juste faire un fallback : au lieu de context.colors, on utilise ForgeronTheme.dark (ou on le passera proprement plus tard)
       content = content.replaceAll('context.colors.', 'ForgeronTheme.dark.');
       content = content.replaceAll('context.typography.', 'AppTextStyles(ForgeronTheme.dark).');
    }

    if (content != originalContent) {
      file.writeAsStringSync(content);
      print('Fixed: ${file.path}');
    }
  }
}
