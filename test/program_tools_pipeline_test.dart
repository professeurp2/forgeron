import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/application/providers/gcode_provider.dart';

/// Régression : « 0 outils » après le chargement d'un programme.
///
/// L'extraction tournait sur `allLines`, c'est-à-dire le G-code **adapté**.
/// Or l'adaptateur convertit chaque `T.. M6` en pause `M0` : ni le mot `T` ni
/// le `M6` n'y subsistent, donc l'extracteur ne trouvait jamais rien.
///
/// Les outils sont désormais extraits du contenu d'origine, à l'ouverture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Extrait fidèle d'une sortie SolidWorks CAM : numérotation N, commentaires
  // descriptifs avant le changement, et fins de ligne Windows.
  const sourceCrLf = 'O0001\r\n'
      'N1 G21\r\n'
      'N2 G91 G28 X0 Y0 Z0\r\n'
      '\r\n'
      'N3 ( Fraisage debauche1 )\r\n'
      'N4 (6MM CRB 2FL 19 LOC)\r\n'
      'N5 T01 M06\r\n'
      'N6 S12000 M03\r\n'
      'N7 G90 G54 G00 X4.25 Y4.5\r\n'
      'N8 G01 Z-2.75 F518.16\r\n';

  test('un programme chargé expose ses outils', () async {
    final notifier = GCodeNotifier();
    await notifier.loadFile(sourceCrLf);

    final tools = notifier.state.tools;
    expect(tools, hasLength(1), reason: 'le programme appelle T01');
    expect(tools.first.number, 1);
    expect(tools.first.diameterMm, 6.0);
    expect(tools.first.flutes, 2);
    expect(tools.first.spindleSpeed, 12000);
  });

  test('les fins de ligne Windows ne cassent pas l\'extraction', () async {
    // Un découpage sur \n seul laisserait un \r collé à « M06 ».
    final crlf = GCodeNotifier();
    await crlf.loadFile(sourceCrLf);

    final lf = GCodeNotifier();
    await lf.loadFile(sourceCrLf.replaceAll('\r\n', '\n'));

    expect(crlf.state.tools.length, lf.state.tools.length);
    expect(crlf.state.tools.first.description,
        lf.state.tools.first.description);
  });

  test('le G-code adapté ne contient plus de M6 — d\'où le bug d\'origine',
      () async {
    final notifier = GCodeNotifier();
    await notifier.loadFile(sourceCrLf);

    final adapted = notifier.state.allLines.join('\n').toUpperCase();

    // C'est le cœur du problème : chercher les outils ici est sans espoir.
    expect(adapted, isNot(contains('M06')));
    expect(adapted, contains('M0 (CHANGEMENT OUTIL'),
        reason: 'l\'adaptateur a bien converti le changement en pause');

    // Et pourtant les outils sont connus, parce qu'ils viennent de la source.
    expect(notifier.state.tools, isNotEmpty);
  });

  test('sans programme, aucun outil', () {
    expect(GCodeNotifier().state.tools, isEmpty);
  });
}
