import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('app builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WasleDriverApp());
    expect(find.byType(WasleDriverApp), findsOneWidget);
  });
}
