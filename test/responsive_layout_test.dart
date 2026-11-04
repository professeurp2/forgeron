import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/core/widgets/responsive_layout.dart';

Future<String> _layoutAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(
    home: ResponsiveLayout(
      mobile: Text('mobile'),
      tablet: Text('tablet'),
      desktop: Text('desktop'),
    ),
  ));
  for (final k in ['mobile', 'tablet', 'desktop']) {
    if (find.text(k).evaluate().isNotEmpty) return k;
  }
  return 'aucun';
}

void main() {
  group('téléphone (Android)', () {
    testWidgets('portrait et paysage restent mobiles', (tester) async {
      expect(await _layoutAt(tester, const Size(390, 844)), 'mobile');
      expect(await _layoutAt(tester, const Size(844, 390)), 'mobile');
    });

    testWidgets('tablette : barre latérale repliée', (tester) async {
      expect(await _layoutAt(tester, const Size(800, 1280)), 'tablet');
    });
  });

  group('PC (Windows)', () {
    testWidgets('un portable 1536×864 maximisé a la mise en page desktop',
        (tester) async {
      expect(await _layoutAt(tester, const Size(1488, 830)), 'desktop');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('une fenêtre basse ou étroite n\'affiche jamais le mobile',
        (tester) async {
      expect(await _layoutAt(tester, const Size(1488, 500)), 'desktop');
      expect(await _layoutAt(tester, const Size(960, 600)), 'tablet');
      expect(await _layoutAt(tester, const Size(500, 400)), 'tablet');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
