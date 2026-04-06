import 'package:flutter_test/flutter_test.dart';
import 'package:wasle/app/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const WasleApp());
    expect(find.byType(WasleApp), findsOneWidget);
  });
}
