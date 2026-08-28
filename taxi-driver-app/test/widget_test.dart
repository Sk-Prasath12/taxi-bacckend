import 'package:flutter_test/flutter_test.dart';
import 'package:taxiapp/main.dart';

void main() {
  testWidgets('Loading page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the LoadingPage is displayed.
    // We can look for the '46%' text which indicates our page is loaded.
    expect(find.text('46%'), findsOneWidget);
  });
}
