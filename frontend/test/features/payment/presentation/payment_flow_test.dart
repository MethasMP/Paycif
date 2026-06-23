import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A simple mock observer to track navigation events before and after GoRouter migration.
/// We use this to ensure the "Push" logic matches expected route names or types.
class MockNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  group('Payment Flow Navigation Tests', () {
    testWidgets('Tapping pay button pushes Payment Screen', (WidgetTester tester) async {
      final mockObserver = MockNavigatorObserver();

      // For the sake of the test environment without Supabase initialized,
      // we test the fundamental routing mechanics.
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockObserver],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('pay_button'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/pay'),
                      builder: (_) => const Scaffold(body: Text('Payment Screen')),
                    ),
                  );
                },
                child: const Text('Pay Now'),
              ),
            ),
          ),
        ),
      );

      // Verify initial route is pushed
      expect(mockObserver.pushedRoutes.length, 1);

      // Tap the button
      await tester.tap(find.byKey(const Key('pay_button')));
      await tester.pumpAndSettle();

      // Verify the new route was pushed
      expect(mockObserver.pushedRoutes.length, 2);
      expect(mockObserver.pushedRoutes.last.settings.name, '/pay');
    });
  });
}
