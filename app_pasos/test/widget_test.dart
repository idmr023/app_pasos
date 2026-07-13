import 'package:flutter_test/flutter_test.dart';
import 'package:app_pasos/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AppPasosApp());
    expect(find.text('APP PASOS'), findsOneWidget);
  });
}
