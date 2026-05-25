import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/security/data/repositories/security_repository_impl.dart';
import 'package:frontend/features/security/data/datasources/security_remote_data_source.dart';
import 'package:frontend/features/security/data/datasources/crypto_service.dart';
import 'package:frontend/features/security/data/datasources/secure_storage_service.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

// Mocks
class MockSecurityRemoteDataSource extends Mock
    implements SecurityRemoteDataSource {}

class MockCryptoService extends Mock implements CryptoService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late SecurityRepositoryImpl repository;
  late MockSecurityRemoteDataSource mockRemoteDataSource;
  late MockCryptoService mockCryptoService;
  late MockSecureStorageService mockSecureStorage;
  late SimpleKeyPair mockKeyPair;

  setUp(() async {
    mockRemoteDataSource = MockSecurityRemoteDataSource();
    mockCryptoService = MockCryptoService();
    mockSecureStorage = MockSecureStorageService();

    // Crypto Setup
    final algorithm = Ed25519();
    mockKeyPair = await algorithm.newKeyPair();

    repository = SecurityRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      cryptoService: mockCryptoService,
      secureStorage: mockSecureStorage,
    );
  });

  group('Signature Integration Audit', () {
    test('verifyPin should sign payload and attach headers', () async {
      // Arrange
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => 'mock_device_uuid');
      when(
        () => mockSecureStorage.read('device_private_key_seed'),
      ).thenAnswer((_) async => base64Encode([1, 2, 3])); // dummy seed b64

      when(
        () => mockCryptoService.keyPairFromSeed(any()),
      ).thenAnswer((_) async => mockKeyPair);
      when(
        () => mockCryptoService.signPayload(mockKeyPair, '123456'),
      ).thenAnswer((_) async => 'mock_signature_b64');

      when(
        () => mockRemoteDataSource.verifyPin(
          any(),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await repository.verifyPin('123456');

      // Assert
      verify(
        () => mockRemoteDataSource.verifyPin(
          '123456',
          headers: {
            'X-Device-Id': 'mock_device_uuid',
            'X-Device-Signature': 'mock_signature_b64',
          },
        ),
      ).called(1);
    });

    test('initiatePinReset should sign payload and attach headers', () async {
      // Arrange
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => 'mock_device_uuid');
      when(
        () => mockSecureStorage.read('device_private_key_seed'),
      ).thenAnswer((_) async => base64Encode([1, 2, 3]));

      when(
        () => mockCryptoService.keyPairFromSeed(any()),
      ).thenAnswer((_) async => mockKeyPair);
      when(
        () => mockCryptoService.signPayload(mockKeyPair, '9999'),
      ).thenAnswer((_) async => 'mock_reset_signature');

      when(
        () => mockRemoteDataSource.initiatePinReset(
          answer: any(named: 'answer'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await repository.initiatePinReset(challengeAnswer: '9999');

      // Assert
      verify(
        () => mockRemoteDataSource.initiatePinReset(
          answer: '9999',
          headers: {
            'X-Device-Id': 'mock_device_uuid',
            'X-Device-Signature': 'mock_reset_signature',
          },
        ),
      ).called(1);
    });

    test('Should throw error if device not bound when signing', () async {
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => null);
      when(
        () => mockSecureStorage.read('device_private_key_seed'),
      ).thenAnswer((_) async => null);

      try {
        await repository.verifyPin('1234');
        fail('Should have thrown Exception');
      } catch (e) {
        expect(e.toString(), contains('Device not bound'));
      }
    });
  });
}
