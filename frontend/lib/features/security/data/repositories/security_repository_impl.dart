import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  static const _kLocalPinHashKey = 'local_pin_hash';
  static const _kLocalPinSaltKey = 'local_pin_salt';
  static const _kDevicesCacheKey = 'linked_devices_cache';

  // ⚡ Lightning-Fast Cache: In-memory storage to skip Disk I/O & Reconstruction
  String? _cachedDeviceId;
  SimpleKeyPair? _cachedKeyPair;
  List<Map<String, dynamic>>? _devicesCache;

  // ⚡ Security Fast-Path: Memory-cached local hash for instant PIN entry
  String? _cachedLocalHash;
  List<int>? _cachedLocalSalt;

  Future<void> _updateLocalPinHash(String pin) async {
    try {
      final salt = _cryptoService.generateSalt();
      // ⚡ Move to Isolate for UI smoothness
      final hash = await compute(CryptoService.computePinHashStatic, {
        'pin': pin,
        'salt': salt,
      });

      // Update Memory Cache
      _cachedLocalHash = hash;
      _cachedLocalSalt = salt;

      // Persist to Disk
      await _secureStorage.write(
        _kLocalPinSaltKey,
        base64Encode(salt),
        strict: true,
      );
      await _secureStorage.write(_kLocalPinHashKey, hash, strict: true);

      debugPrint('✅ [Cache] Local PIN hash updated & cached in memory.');
    } catch (e) {
      debugPrint('❌ [Cache] Failed to update local PIN hash: $e');
    }
  }

  @override
  Future<void> setupPin(String pin) async {
    // 1. Optimistic: Store locally first
    await _updateLocalPinHash(pin);
    // 2. Sync with Server
    await _remoteDataSource.setupPin(pin);
  }

  @override
  Future<void> bindCurrentDevice() async {
    // 1. Ensure Stable Device ID (Relaxed read)
    String? deviceId = await _secureStorage.read(_kDeviceIdKey, strict: false);
    if (deviceId == null) {
      deviceId = _uuidSource.v4();
      await _secureStorage.write(_kDeviceIdKey, deviceId, strict: false);
      debugPrint('🆕 [Bind] Generated new DeviceID: $deviceId');
    }

    // 2. Generate Cryptographic Identity
    final keyPair = await _cryptoService.generateKeyPair();
    final privateKeySeed = await _cryptoService.getPrivateKeyBytes(keyPair);
    final publicKeyBase64 = await _cryptoService.getPublicKeyBase64(keyPair);

    // 🔬 DEBUG: Print public key prefix for tracing
    debugPrint('🔑 [Bind] DeviceID: $deviceId');
    debugPrint(
      '🔑 [Bind] PubKey Prefix: ${publicKeyBase64.substring(0, 10)}...',
    );

    // 3. Store Private Key Securely (Biometric Gated)
    await _secureStorage.write(
      _kPrivateKeySeedKey,
      base64Encode(privateKeySeed),
      strict: true,
    );

    // 4. Get Device Metadata
    String deviceName = 'Unknown Device';
    String osType = 'web'; // Default fallback that satisfies constraint
    Map<String, dynamic> metadata = {};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        osType = 'android';
        metadata = {
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'product': androidInfo.product,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceName = iosInfo.name;
        osType = 'ios';
        metadata = {
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'model': iosInfo.model,
          'localizedModel': iosInfo.localizedModel,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
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
      osType: osType,
      metadata: metadata,
      trustScore: 100,
    );

    // ⚡ Post-Bind Cache Update: Immediate availability for PIN entry
    _cachedDeviceId = deviceId;
    _cachedKeyPair = keyPair;
  }

  /// Helper to generate headers with signature for critical actions.
  Future<Map<String, String>> _generateSignatureHeaders(String payload) async {
    // ⚡ Lightning-Fast Check (In-Memory)
    if (_cachedDeviceId != null && _cachedKeyPair != null) {
      final signature = await _cryptoService.signPayload(
        _cachedKeyPair!,
        payload,
      );
      // 🔬 DEBUG: Print what we're sending
      final pubKeyB64 = await _cryptoService.getPublicKeyBase64(
        _cachedKeyPair!,
      );
      debugPrint('🔑 [Verify] Using CACHED key. DeviceID: $_cachedDeviceId');
      debugPrint('🔑 [Verify] PubKey Prefix: ${pubKeyB64.substring(0, 10)}...');
      return {'X-Device-Id': _cachedDeviceId!, 'X-Device-Signature': signature};
    }

    // Fallback: Slow Path (SecureStorage + Key Reconstruction)
    final deviceId = await _secureStorage.read(_kDeviceIdKey, strict: false);
    final privateKeyB64 = await _secureStorage.read(
      _kPrivateKeySeedKey,
      strict: true,
    );

    if (deviceId == null || privateKeyB64 == null) {
      throw Exception('Device not bound. Cannot sign request.');
    }

    final seed = base64Decode(privateKeyB64);
    final keyPair = await _cryptoService.keyPairFromSeed(seed);

    // ⚡ Update Cache for next time
    _cachedDeviceId = deviceId;
    _cachedKeyPair = keyPair;

    final signature = await _cryptoService.signPayload(keyPair, payload);
    return {'X-Device-Id': deviceId, 'X-Device-Signature': signature};
  }

  /// 🛡️ Universal Self-Healing Wrapper
  /// If an action fails because the device is "not recognized",
  /// it proactively re-binds the device and retries the action once.
  /// Added Recursion Guard to prevent infinite death loops.
  Future<T> _withDeviceSelfHealing<T>(
    Future<T> Function() action, {
    int retryCount = 0,
  }) async {
    try {
      return await action();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      // 🛡️ Enhanced Detection: Check both string and internal details for robustness
      bool isBindingError =
          errorStr.contains('device not recognized') ||
          errorStr.contains('device signature verification failed') ||
          errorStr.contains('device not bound') ||
          errorStr.contains('device authorization missing');

      // If it's a Supabase FunctionException, check details map
      if (!isBindingError && e is FunctionException) {
        final details = e.details;
        if (details is Map) {
          final detailError = details['error']?.toString().toLowerCase() ?? '';
          if (detailError.contains('device not recognized') ||
              detailError.contains('device signature verification failed') ||
              detailError.contains('device authorization missing')) {
            isBindingError = true;
          }
        }
      }

      final shouldSelfHeal = isBindingError && retryCount < 1;

      if (shouldSelfHeal) {
        debugPrint(
          '🛡️ [Self-Healing] Sync issue detected (Attempt ${retryCount + 1}). Attempting Re-Bind...',
        );
        try {
          // 1. Re-sync device identity to DB
          await bindCurrentDevice();
          debugPrint(
            '🛡️ [Self-Healing] Re-Bind successful. Retrying original action...',
          );
          // 2. Retry the original action (Increment count to prevent loop)
          return await _withDeviceSelfHealing(
            action,
            retryCount: retryCount + 1,
          );
        } catch (rebindError) {
          debugPrint('🛡️ [Self-Healing] Re-Bind failed: $rebindError');
          rethrow;
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> verifyPin(String pin) async {
    // ⚡ 1. Optimistic Local Verification (Argon2id)
    bool isOptimisticSuccess = false;
    try {
      // 🚀 Fast Lane: Use Memory Cache first
      String? localHash = _cachedLocalHash;
      List<int>? localSalt = _cachedLocalSalt;

      // Warm up from Disk if memory cache is empty
      if (localHash == null || localSalt == null) {
        final diskHash = await _secureStorage.read(
          _kLocalPinHashKey,
          strict: true,
        );
        final diskSaltB64 = await _secureStorage.read(
          _kLocalPinSaltKey,
          strict: true,
        );

        if (diskHash != null && diskSaltB64 != null) {
          localHash = diskHash;
          localSalt = base64Decode(diskSaltB64);
          // populate memory for next time
          _cachedLocalHash = localHash;
          _cachedLocalSalt = localSalt;
          debugPrint('📂 [Cache] Local hash loaded from Disk into Memory.');
        }
      }

      if (localHash != null && localSalt != null) {
        // ⚡ Hashing in Isolate to keep UI 60/120 FPS
        final computedHash = await compute(CryptoService.computePinHashStatic, {
          'pin': pin,
          'salt': localSalt,
        });

        final isValid = computedHash == localHash;

        if (isValid) {
          isOptimisticSuccess = true;
          debugPrint(
            '✅ [Verify] Optimistic Local Check PASSED (World-Class Speed)',
          );
        } else {
          debugPrint('❌ [Verify] Optimistic Local Check FAILED');
          // If local hash exists but fails, it's a WRONG PIN.
          throw Exception('Invalid PIN (Local)');
        }
      } else {
        debugPrint(
          '⚠️ [Verify] No local hash found. Skipping optimistic check.',
        );
      }
    } catch (e) {
      if (e.toString().contains('Invalid PIN')) rethrow;
      debugPrint('⚠️ [Verify] Local check error: $e');
    }

    if (isOptimisticSuccess) {
      // 🚀 Return immediately! But verify on server in background.
      _backgroundServerVerify(pin);
      return;
    }

    // 🐢 2. Fallback: Server Verification
    await _withDeviceSelfHealing(() async {
      final headers = await _generateSignatureHeaders(pin);
      await _remoteDataSource.verifyPin(pin, headers: headers);

      // If we reached here, Server said OK. Self-Heal local hash.
      await _updateLocalPinHash(pin);
    });
  }

  Future<void> _backgroundServerVerify(String pin) async {
    try {
      await _withDeviceSelfHealing(() async {
        final headers = await _generateSignatureHeaders(pin);
        await _remoteDataSource.verifyPin(pin, headers: headers);
      });
      debugPrint('✅ [Background-Verify] Server confirmed PIN.');
    } catch (e) {
      debugPrint('❌ [Background-Verify] Server REJECTED PIN (Sync Issue!): $e');
    }
  }

  @override
  Future<void> initiatePinReset({required String challengeAnswer}) async {
    await _withDeviceSelfHealing(() async {
      final headers = await _generateSignatureHeaders(challengeAnswer);
      await _remoteDataSource.initiatePinReset(
        answer: challengeAnswer,
        headers: headers,
      );
    });
  }

  @override
  Future<bool> isDeviceBound() async {
    final deviceId = await _secureStorage.read(_kDeviceIdKey, strict: false);
    final privateKey = await _secureStorage.read(
      _kPrivateKeySeedKey,
      strict: true,
    );

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

  @override
  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    await _withDeviceSelfHealing(() async {
      final headers = await _generateSignatureHeaders(newPin);
      await _remoteDataSource.changePin(
        oldPin: oldPin,
        newPin: newPin,
        headers: headers,
      );
      // Update local hash ONLY after server confirms change
      await _updateLocalPinHash(newPin);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getLinkedDevices({
    bool forceRefresh = false,
  }) async {
    // ⚡ 1. Memory Fast-Path: Zero Latency
    if (_devicesCache != null && !forceRefresh) {
      debugPrint('⚡ [SecurityRepo] Serving from Memory Cache');
      return _devicesCache!;
    }

    // ⚡ 2. Disk Fast-Path: Cold-Start Zero Latency
    if (_devicesCache == null) {
      final json = await _secureStorage.read(_kDevicesCacheKey, strict: false);
      if (json != null) {
        try {
          final List<dynamic> decoded = jsonDecode(json);
          _devicesCache = List<Map<String, dynamic>>.from(decoded);
          debugPrint('⚡ [SecurityRepo] Serving from Disk Cache');
          if (!forceRefresh) return _devicesCache!;
        } catch (e) {
          debugPrint('⚠️ [SecurityRepo] Cache corrupt or outdated: $e');
        }
      }
    }

    // 🐢 3. Network Path: Ground Truth
    final devices = await _remoteDataSource.getLinkedDevices();
    _devicesCache = devices;
    // Persist for next cold start
    await _secureStorage.write(
      _kDevicesCacheKey,
      jsonEncode(devices),
      strict: false,
    );
    return devices;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchLinkedDevices() {
    return _remoteDataSource.watchLinkedDevices().map((devices) {
      // 📡 Side-Effect: Keep local cache synced with Real-time push
      _devicesCache = devices;
      _secureStorage
          .write(_kDevicesCacheKey, jsonEncode(devices), strict: false)
          .ignore();
      return devices;
    });
  }

  @override
  Future<void> revokeDevice(String deviceId, {String? reason}) async {
    await _remoteDataSource.revokeDevice(deviceId, reason: reason);
  }

  @override
  Future<String?> getCurrentDeviceId() async {
    return await _secureStorage.read(_kDeviceIdKey, strict: false);
  }
}
