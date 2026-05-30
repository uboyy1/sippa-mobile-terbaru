import 'package:flutter_test/flutter_test.dart';

import 'package:sippa_mobile/main.dart';

void main() {
  testWidgets('SIPPA app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SippaApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('SIPPA'), findsOneWidget);
  });
}
