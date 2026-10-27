import 'package:flutter_test/flutter_test.dart';
import 'package:braillepad_frontend/main.dart';

void main() {
  testWidgets('App renders welcome screen correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const BraillepadApp());

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Explore Dashboard'), findsOneWidget);
  });
}
