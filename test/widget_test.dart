import 'package:flutter_test/flutter_test.dart';
import 'package:forgeron/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const ForgeronApp());
    expect(find.text('FORGERONS'), findsOneWidget);
  });
}
