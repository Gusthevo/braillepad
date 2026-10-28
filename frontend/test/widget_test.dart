import 'package:flutter_test/flutter_test.dart';
import 'package:braillepad_frontend/main.dart';

void main() {
  testWidgets('App renders login screen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const BraillepadApp());

    expect(find.text('BraillePad'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
