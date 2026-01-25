import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/security/presentation/logic/security_controller.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';

class MockSecurityRepository extends Mock implements SecurityRepository {}

void main() {
  late SecurityController controller;
  late MockSecurityRepository mockRepository;

  setUp(() {
    mockRepository = MockSecurityRepository();
    controller = SecurityController(mockRepository);
  });

  group('SecurityController Audit', () {
    test('Initial state should be correct', () {
      expect(controller.state.status, SecurityStatus.initial);
      expect(controller.state.lockedUntil, isNull);
    });

    test('setupPin success flow', () async {
      when(() => mockRepository.setupPin('123456')).thenAnswer((_) async {});

      final future = controller.setupPin('123456');
      expect(controller.state.status, SecurityStatus.loading);

      await future;
      expect(controller.state.status, SecurityStatus.success);
    });

    test('setupPin error flow', () async {
      when(
        () => mockRepository.setupPin(any()),
      ).thenThrow(Exception('Network Error'));

      await controller.setupPin('123456');
      expect(controller.state.status, SecurityStatus.error);
      expect(controller.state.errorMessage, contains('Network Error'));
    });

    test('verifyPin success flow', () async {
      when(() => mockRepository.verifyPin('123456')).thenAnswer((_) async {});

      final result = await controller.verifyPin('123456');
      expect(result, isTrue);
      expect(controller.state.status, SecurityStatus.success);
    });

    test('verifyPin should detect Server-Side Lockout (423)', () async {
      // Simulate Exception from Repository that contains 'locked'
      when(
        () => mockRepository.verifyPin('000000'),
      ).thenThrow(Exception('Account locked. Try again in 300 seconds.'));

      final result = await controller.verifyPin('000000');

      expect(result, isFalse);
      expect(controller.state.status, SecurityStatus.locked);
      expect(controller.state.errorMessage, contains('Account locked'));
    });

    test('verifyPin should handle normal auth failure', () async {
      when(
        () => mockRepository.verifyPin('000000'),
      ).thenThrow(Exception('Invalid PIN'));

      final result = await controller.verifyPin('000000');

      expect(result, isFalse);
      expect(controller.state.status, SecurityStatus.error);
      expect(controller.state.errorMessage, 'Incorrect PIN');
    });
  });
}
