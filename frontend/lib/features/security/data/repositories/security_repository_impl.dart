import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/security_repository.dart';
import '../datasources/crypto_service.dart';
import '../datasources/secure_storage_service.dart';
import '../datasources/security_remote_data_source.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  final SecurityRemoteDataSource _remoteDataSource;
  final CryptoService _cryptoService;
  final SecureStorageService _secureStorage;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final Uuid _uuidSource;

  SecurityRepositoryImpl({
    required SecurityRemoteDataSource remoteDataSource,
    required CryptoService cryptoService,
    required SecureStorageService secureStorage,
    DeviceInfoPlugin? deviceInfoPlugin,
    Uuid? uuidSource,
  }) : _remoteDataSource = remoteDataSource,
       _cryptoService = cryptoService,
       _secureStorage = secureStorage,
       _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
       _uuidSource = uuidSource ?? const Uuid();

  static const _kDeviceIdKey = 'device_binding_id';
  static const _kPrivateKeySeedKey = 'device_private_key_seed';

  @override
  Future<void> setupPin(String pin) async {
    await _remoteDataSource.setupPin(pin);
  }

  @override
  Future<void> bindCurrentDevice() async {
    // ... (Existing Logic) ...
    // 1. Ensure Stable Device ID
    String? deviceId = await _secureStorage.read(_kDeviceIdKey);
    if (deviceId == null) {
      deviceId = _uuidSource.v4();
      await _secureStorage.write(_kDeviceIdKey, deviceId);
    }

    // 2. Generate Cryptographic Identity
    final keyPair = await _cryptoService.generateKeyPair();
    final privateKeySeed = await _cryptoService.getPrivateKeyBytes(keyPair);
    final publicKeyBase64 = await _cryptoService.getPublicKeyBase64(keyPair);

    // 3. Store Private Key Securely (Biometric Gated)
    await _secureStorage.write(
      _kPrivateKeySeedKey,
      base64Encode(privateKeySeed),
    );

    // 4. Get Device Metadata
    String deviceName = 'Unknown Device';
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceName = iosInfo.name;
      }
    } catch (e) {
      deviceName = 'Mobile App';
    }

    // 5. Send to Server (Bind call itself is usually not signed by the key being created,
    // strictly speaking, but authenticated by User Token).
    await _remoteDataSource.bindDevice(
      publicKey: publicKeyBase64,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }

  /// Helper to generate headers with signature for critical actions.
  Future<Map<String, String>> _generateSignatureHeaders(String payload) async {
    final deviceId = await _secureStorage.read(_kDeviceIdKey);
    final privateKeyB64 = await _secureStorage.read(_kPrivateKeySeedKey);

    if (deviceId == null || privateKeyB64 == null) {
      throw Exception('Device not bound. Cannot sign request.');
    }

    final seed = base64Decode(privateKeyB64);
    final keyPair = await _cryptoService.keyPairFromSeed(seed);

    // Signature format: Base64(Sign(Message))
    // Message usually includes Timestamp + Nonce + Payload to prevent replay.
    // For MVP, we stick to Payload Sign.
    final signature = await _cryptoService.signPayload(keyPair, payload);

    return {'X-Device-Id': deviceId, 'X-Device-Signature': signature};
  }

  @override
  Future<void> verifyPin(String pin) async {
    // We sign the PIN payload to prove it came from bound device.
    // Ensure body matches exactly what is sent to invoke(),
    // usually RemoteDataSource handles encoding.
    // We might need to coordinate payload string construction.
    // Ideally, RemoteDataSource takes care of JSON, so we just sign the "content".
    // Let's assume for now we sign the raw value or a deterministic representation.
    // A better approach is to sign the PIN string itself if the body is simple.

    final headers = await _generateSignatureHeaders(pin);
    await _remoteDataSource.verifyPin(pin, headers: headers);
  }

  @override
  Future<void> initiatePinReset({required String challengeAnswer}) async {
    final headers = await _generateSignatureHeaders(challengeAnswer);
    await _remoteDataSource.initiatePinReset(
      answer: challengeAnswer,
      headers: headers,
    );
  }

  @override
  Future<bool> isDeviceBound() async {
    // ... (Existing Logic)
    final deviceId = await _secureStorage.read(_kDeviceIdKey);
    final privateKey = await _secureStorage.read(_kPrivateKeySeedKey);

    if (deviceId == null || privateKey == null) {
      return false;
    }

    try {
      return await _remoteDataSource.isDeviceBound(deviceId);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasPin() async {
    try {
      final status = await _remoteDataSource.getProfileStatus();
      return status?['has_pin'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
