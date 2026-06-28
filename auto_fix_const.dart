import 'dart:io';

void main() async {
  print('Running dart analyze...');
  final result = await Process.run('dart', ['analyze']);
  final lines = result.stdout.toString().split('\n');
  final stderrLines = result.stderr.toString().split('\n');
  lines.addAll(stderrLines);

  final Map<String, List<int>> errorLines = {};
  final Map<String, List<int>> constListErrors = {};

  for (final line in lines) {
    if (line.contains('Invalid constant value') || line.contains('non_constant_default_value')) {
      final parts = line.split(' - ');
      if (parts.length >= 3) {
        final loc = parts[1].trim();
        final locParts = loc.split(':');
        if (locParts.length >= 3) {
          final file = locParts[0].trim();
          final lineNum = int.tryParse(locParts[1].trim());
          if (file.isNotEmpty && lineNum != null) {
            errorLines.putIfAbsent(file, () => []).add(lineNum);
          }
        }
      }
    }
    
    if (line.contains('non_constant_list_element') || line.contains('const_initialized_with_non_constant_value') || line.contains('non_constant_record_field')) {
      final parts = line.split(' - ');
      if (parts.length >= 3) {
        final loc = parts[1].trim();
        final locParts = loc.split(':');
        if (locParts.length >= 3) {
          final file = locParts[0].trim();
          final lineNum = int.tryParse(locParts[1].trim());
          if (file.isNotEmpty && lineNum != null) {
            constListErrors.putIfAbsent(file, () => []).add(lineNum);
          }
        }
      }
    }
  }

  for (final file in errorLines.keys) {
    final f = File(file);
    if (!f.existsSync()) continue;
    final content = f.readAsLinesSync();
    
    final linesToFix = errorLines[file]!;
    for (final l in linesToFix) {
      if (l - 1 < content.length) {
        // Just remove 'const ' from that line
        content[l - 1] = content[l - 1].replaceAll(RegExp(r'\bconst\s+'), '');
      }
    }
    f.writeAsStringSync(content.join('\n'));
    print('Fixed const in \$file');
  }

  for (final file in constListErrors.keys) {
    final f = File(file);
    if (!f.existsSync()) continue;
    var text = f.readAsStringSync();
    // Convert static const list to static get list
    text = text.replaceAllMapped(
      RegExp(r'static\s+const\s+(_[a-zA-Z0-9_]+)\s*=\s*\['), 
      (match) => 'static get ${match.group(1)} => ['
    );
    text = text.replaceAllMapped(
      RegExp(r'static\s+const\s+(_[a-zA-Z0-9_]+)\s*=\s*const\s*\['), 
      (match) => 'static get ${match.group(1)} => ['
    );
    f.writeAsStringSync(text);
    print('Fixed list in \$file');
  }
}
