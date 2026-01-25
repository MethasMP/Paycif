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
// We skip specific DeviceInfoPlugin mocking for simplicity, assuming fallback or we can mock it if needed.
// But SecurityRepositoryImpl handles the try-catch for platform channels.

void main() {
  late SecurityRepositoryImpl repository;
  late MockSecurityRemoteDataSource mockRemoteDataSource;
  late MockCryptoService mockCryptoService;
  late MockSecureStorageService mockSecureStorage;

  setUp(() {
    mockRemoteDataSource = MockSecurityRemoteDataSource();
    mockCryptoService = MockCryptoService();
    mockSecureStorage = MockSecureStorageService();

    repository = SecurityRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      cryptoService: mockCryptoService,
      secureStorage: mockSecureStorage,
      // Leaving deviceInfoPlugin null to trigger default or check fallback logic
    );
  });

  group('SecurityRepositoryImpl Audit', () {
    test(
      'bindCurrentDevice should orchestrate binding flow correctly',
      () async {
        // Arrange
        // 1. Storage returns no existing deviceId
        when(
          () => mockSecureStorage.read('device_binding_id'),
        ).thenAnswer((_) async => null);
        // 2. Storage write setup
        when(
          () => mockSecureStorage.write(any(), any()),
        ).thenAnswer((_) async {});

        // 3. Crypto Setup
        final algorithm = Ed25519();
        final keyPair = await algorithm.newKeyPair();
        when(
          () => mockCryptoService.generateKeyPair(),
        ).thenAnswer((_) async => keyPair);
        when(
          () => mockCryptoService.getPrivateKeyBytes(keyPair),
        ).thenAnswer((_) async => List.filled(32, 1));
        when(
          () => mockCryptoService.getPublicKeyBase64(keyPair),
        ).thenAnswer((_) async => 'mock_pub_key_base64');

        // 4. Remote call
        when(
          () => mockRemoteDataSource.bindDevice(
            publicKey: any(named: 'publicKey'),
            deviceId: any(named: 'deviceId'),
            deviceName: any(named: 'deviceName'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await repository.bindCurrentDevice();

        // Assert
        // 1. Should have generated and stored UUID
        verify(() => mockSecureStorage.read('device_binding_id')).called(1);
        verify(
          () => mockSecureStorage.write('device_binding_id', any()),
        ).called(1);

        // 2. Should have generated keypair and stored private key
        verify(() => mockCryptoService.generateKeyPair()).called(1);
        verify(
          () => mockSecureStorage.write('device_private_key_seed', any()),
        ).called(1);

        // 3. Should have called backend
        verify(
          () => mockRemoteDataSource.bindDevice(
            publicKey: 'mock_pub_key_base64',
            deviceId: any(named: 'deviceId'),
            deviceName: any(named: 'deviceName'),
          ),
        ).called(1);
      },
    );

    test('bindCurrentDevice should re-use existing deviceId', () async {
      // Arrange
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => 'existing_uuid');
      when(
        () => mockSecureStorage.write(any(), any()),
      ).thenAnswer((_) async {});

      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      when(
        () => mockCryptoService.generateKeyPair(),
      ).thenAnswer((_) async => keyPair);
      when(
        () => mockCryptoService.getPrivateKeyBytes(keyPair),
      ).thenAnswer((_) async => []);
      when(
        () => mockCryptoService.getPublicKeyBase64(keyPair),
      ).thenAnswer((_) async => 'pk');

      when(
        () => mockRemoteDataSource.bindDevice(
          publicKey: any(named: 'publicKey'),
          deviceId: 'existing_uuid',
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await repository.bindCurrentDevice();

      // Assert
      verify(() => mockSecureStorage.read('device_binding_id')).called(1);
      // Should NOT have written a new device id
      verifyNever(() => mockSecureStorage.write('device_binding_id', any()));
      // But should have written private key
      verify(
        () => mockSecureStorage.write('device_private_key_seed', any()),
      ).called(1);
    });

    test('verifyPin should delegate to remote source (with headers)', () async {
      // Arrange: Mock Binding Data
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => 'mock_uuid');
      when(
        () => mockSecureStorage.read('device_private_key_seed'),
      ).thenAnswer((_) async => base64Encode([1, 2, 3])); // Dummy seed

      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      when(
        () => mockCryptoService.keyPairFromSeed(any()),
      ).thenAnswer((_) async => keyPair);
      when(
        () => mockCryptoService.signPayload(keyPair, '123456'),
      ).thenAnswer((_) async => 'mock_sig');

      when(
        () => mockRemoteDataSource.verifyPin(
          '123456',
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async {});

      // Act
      await repository.verifyPin('123456');

      // Assert
      verify(
        () => mockRemoteDataSource.verifyPin(
          '123456',
          headers: any(named: 'headers'),
        ),
      ).called(1);
    });

    test('isDeviceBound should return false if local keys missing', () async {
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => null);
      when(
        () => mockSecureStorage.read('device_private_key_seed'),
      ).thenAnswer((_) async => 'some_key');

      final result = await repository.isDeviceBound();
      expect(result, isFalse);
    });

    test('isDeviceBound should delegate to remote if keys exist', () async {
      when(
        () => mockSecureStorage.read('device_binding_id'),
      ).thenAnswer((_) async => 'uuid');
      when(
        () => mockSecureStorage.read('device_private_key_seed'),
      ).thenAnswer((_) async => 'seed');
      when(
        () => mockRemoteDataSource.isDeviceBound('uuid'),
      ).thenAnswer((_) async => true);

      final result = await repository.isDeviceBound();
      expect(result, isTrue);
      verify(() => mockRemoteDataSource.isDeviceBound('uuid')).called(1);
    });
  });
}
