import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZapPayApp());

    // Verify that the Login Screen is displayed.
    // Check for the title "ZapPay"
    expect(find.text('ZapPay'), findsOneWidget);

    // Check for buttons
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsOneWidget);
  });
}
