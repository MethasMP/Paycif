import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:frontend/features/security/presentation/pages/recovery_screen.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';

class MockSecurityController extends Mock implements SecurityController {}

void main() {
  late MockSecurityController mockController;

  void _setTestSurfaceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  }

  setUp(() {
    mockController = MockSecurityController();
    when(() => mockController.state).thenReturn(const SecurityState());
  });

  Future<void> pumpWidget(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<SecurityController>.value(
          value: mockController,
          child: const RecoveryScreen(),
        ),
      ),
    );
  }

  group('RecoveryScreen Audit', () {
    testWidgets('Renders form correctly', (tester) async {
      _setTestSurfaceSize(tester);
      await pumpWidget(tester);

      expect(find.text('Identity Challenge'), findsOneWidget);
      expect(find.textContaining('To reset your PIN'), findsOneWidget);
      expect(find.text('Verify Identity'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('Validates input length', (tester) async {
      _setTestSurfaceSize(tester);
      await pumpWidget(tester);

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Verify Identity'));
      await tester.pump();

      expect(find.text('Requires 4 digits'), findsOneWidget);
    });

    testWidgets('Submits valid input', (tester) async {
      _setTestSurfaceSize(tester);
      when(
        () => mockController.initiatePinReset(any()),
      ).thenAnswer((_) async => true);

      await pumpWidget(tester);

      await tester.enterText(find.byType(TextFormField), '1234');
      await tester.tap(find.text('Verify Identity'));
      await tester.pump();

      verify(() => mockController.initiatePinReset('1234')).called(1);
    });

    testWidgets('Displays Lockout State', (tester) async {
      _setTestSurfaceSize(tester);
      when(() => mockController.state).thenReturn(
        const SecurityState(
          status: SecurityStatus.locked,
          errorMessage: 'Locked for 1 hour',
        ),
      );

      await pumpWidget(tester);
      await tester.pumpAndSettle();

      expect(find.text('Security Lockout'), findsOneWidget);
      expect(find.text('Locked for 1 hour'), findsOneWidget);
      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
      // Ensure form is NOT visible or replaced?
      // Our code replaces the whole body content.
      expect(find.byType(TextFormField), findsNothing);
    });
  });
}
