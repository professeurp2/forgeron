// Met à l'échelle les DIMENSIONS d'un fichier G-code.
//
// Multiplie par [echelle] les adresses linéaires (X Y Z I J K R Q). Laisse
// INTACTS : angles (A C), avance (F), broche (S), tempo (P), numéros (T H D N O)
// et le contenu des commentaires ( ... ) et ; ...  (ex. « 10MM X 90DEG »).
// Encodage Latin-1 préservé (accents SolidWorks).
//
// Lancer : dart run tool/scale_gcode.dart "<entree>" <echelle> ["<sortie>"]

import 'dart:convert';
import 'dart:io';

const _scaleAddresses = {'X', 'Y', 'Z', 'I', 'J', 'K', 'R', 'Q'};
final _word = RegExp(r'([A-Za-z])([-+]?[0-9]*\.?[0-9]+)');

String _fmt(double v) {
  var s = v.toStringAsFixed(5);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

String _scaleCode(String seg, double scale) =>
    seg.replaceAllMapped(_word, (m) {
      final letter = m.group(1)!;
      if (_scaleAddresses.contains(letter.toUpperCase())) {
        return '$letter${_fmt(double.parse(m.group(2)!) * scale)}';
      }
      return m.group(0)!;
    });

/// N'échelle que les segments de CODE ; recopie verbatim les commentaires
/// `( ... )` et `; ...`.
String _scaleLine(String line, double scale) {
  final out = StringBuffer();
  var i = 0;
  while (i < line.length) {
    var open = -1;
    var isSemi = false;
    for (var j = i; j < line.length; j++) {
      final ch = line[j];
      if (ch == '(') {
        open = j;
        break;
      }
      if (ch == ';') {
        open = j;
        isSemi = true;
        break;
      }
    }
    if (open < 0) {
      out.write(_scaleCode(line.substring(i), scale));
      break;
    }
    out.write(_scaleCode(line.substring(i, open), scale));
    if (isSemi) {
      out.write(line.substring(open));
      break;
    }
    final close = line.indexOf(')', open);
    if (close < 0) {
      out.write(line.substring(open));
      break;
    }
    out.write(line.substring(open, close + 1));
    i = close + 1;
  }
  return out.toString();
}

String _defaultOut(String p, double s) {
  final dot = p.lastIndexOf('.');
  final tag = '_x$s';
  return dot < 0 ? '$p$tag' : '${p.substring(0, dot)}$tag${p.substring(dot)}';
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/scale_gcode.dart "<entree>" <echelle> '
        '["<sortie>"]');
    exit(2);
  }
  final inPath = args[0];
  final scale = double.parse(args[1]);
  final outPath = args.length >= 3 ? args[2] : _defaultOut(inPath, scale);

  final lines = File(inPath).readAsStringSync(encoding: latin1).split('\n');
  final scaled = lines.map((l) => _scaleLine(l, scale)).join('\n');
  File(outPath).writeAsStringSync(scaled, encoding: latin1);

  stdout.writeln('OK  echelle=$scale');
  stdout.writeln('  entree : $inPath (${lines.length} lignes)');
  stdout.writeln('  sortie : $outPath');
}
