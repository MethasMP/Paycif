import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/features/security/domain/repositories/security_repository.dart';
import 'package:frontend/features/security/data/datasources/crypto_service.dart';
import 'package:frontend/features/security/data/datasources/secure_storage_service.dart';
import 'package:frontend/features/security/data/datasources/security_remote_data_source.dart';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const _kDevicesCacheKey = 'linked_devices_cache';
  static const _kHasPinCacheKey = 'cache_has_pin_configured';
  static const _kIsHardwareKey = 'is_hardware_backed';

  // AES-256-GCM + PBKDF2-SHA256 PIN token (v2 suffix avoids collision with old Argon2id keys)
  static const _kPinEncryptedToken = 'pin_enc_token_v2';
  static const _kPinTokenSalt = 'pin_token_salt_v2';
  static const _kPinAttemptCount = 'pin_attempt_count';
  static const _kMaxLocalAttempts = 5;

  // Old Argon2id keys — read-only, used only for migration detection then deleted
  static const _kLegacyPinHashKey = 'local_pin_hash';
  static const _kLegacyPinSaltKey = 'local_pin_salt';

  // ⚡ Lightning-Fast Cache: In-memory storage to skip Disk I/O & Reconstruction
  List<Map<String, dynamic>>? _devicesCache;

  // ⚡ Derived PIN key cached in RAM for fast subsequent local verifications.
  // Lives only in process memory — cleared on app restart or clearAllPinData().
  List<int>? _cachedPinKey;

  // ⚡ Device credential cache — stable within a session
  String? _cachedDeviceId;
  bool? _cachedIsHardware;
  dynamic _cachedKeyPair; // reconstructed once, reused every sign

  /// Persists PIN as AES-256-GCM encrypted token (PBKDF2-SHA256 key derivation).
  /// Runs PBKDF2 in compute() isolate to keep UI smooth (~10ms).
  Future<void> _persistLocalPinToken(String pin) async {
    try {
      final salt = _cryptoService.randomBytes(32);
      final token = _cryptoService.randomBytes(32); // random verification marker

      final keyBytes = await compute(CryptoService.derivePinKey, {
        'pin': pin,
        'salt': salt,
      });

      _cachedPinKey = keyBytes;

      final encrypted = await _cryptoService.encryptPinToken(keyBytes, token);

      await Future.wait([
        _secureStorage.write(_kPinEncryptedToken, base64Encode(encrypted)),
        _secureStorage.write(_kPinTokenSalt, base64Encode(salt)),
        _secureStorage.write(_kPinAttemptCount, '0'),
        // Clean up legacy Argon2id keys if present
        _secureStorage.delete(_kLegacyPinHashKey),
        _secureStorage.delete(_kLegacyPinSaltKey),
      ]);

      debugPrint('✅ [PIN] Local AES-256-GCM token persisted.');
    } catch (e) {
      debugPrint('❌ [PIN] Failed to persist local PIN token: $e');
    }
  }

  @override
  Future<void> setupPin(String pin) async {
    // 1. Confirm with server first — throws if it fails, we propagate
    await _remoteDataSource.setupPin(pin);
    // 2. Server confirmed: persist local token and mark configured
    await Future.wait([
      _persistLocalPinToken(pin),
      _secureStorage.write(_kHasPinCacheKey, 'true'),
    ]);
  }

  @override
  Future<void> bindCurrentDevice() async {
    // 1. Ensure Stable Device ID
    String? deviceId = await _secureStorage.read(_kDeviceIdKey);
    if (deviceId == null) {
      deviceId = _uuidSource.v4();
      await _secureStorage.write(_kDeviceIdKey, deviceId);
    }

    // Check if biometric is enabled
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    String? publicKeyBase64;
    bool isHardware = false;

    if (biometricEnabled) {
      // 2. Generate Banking-Grade Cryptographic Identity (Secure Enclave / TEE)
      publicKeyBase64 = await _cryptoService.createHardwareIdentity();
      if (publicKeyBase64 != null) {
        isHardware = true;
      }
    }

    if (!isHardware) {
      // Software fallback
      final keyPair = await _cryptoService.generateKeyPair();
      final privateKeyBytes = await _cryptoService.getPrivateKeyBytes(keyPair);
      publicKeyBase64 = await _cryptoService.getPublicKeyBase64(keyPair);

      await _secureStorage.write(_kPrivateKeySeedKey, base64Encode(privateKeyBytes));
      await _secureStorage.write(_kIsHardwareKey, 'false');
    } else {
      // 3. Mark as Hardware Backed (No Private Key extraction!)
      await _secureStorage.write(_kIsHardwareKey, 'true');
      await _secureStorage.delete(_kPrivateKeySeedKey); // Wipe any old software seeds
    }

    // 🔬 DEBUG: Print public key prefix for tracing
    debugPrint('🔑 [Bind] DeviceID: $deviceId');
    debugPrint('🔑 [Bind] PubKey Prefix: ${publicKeyBase64!.substring(0, 10)}...');

    // 4. Get Device Metadata
    String deviceName = 'Unknown Device';
    String osType = 'web';
    Map<String, dynamic> metadata = {'security_level': isHardware ? 'hardware_enclave' : 'software_storage'};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        osType = 'android';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceName = iosInfo.name;
        osType = 'ios';
      }
    } catch (e) {
      deviceName = 'Mobile App';
    }

    // 5. Send to Server
    await _remoteDataSource.bindDevice(
      publicKey: publicKeyBase64,
      deviceId: deviceId,
      deviceName: deviceName,
      osType: osType,
      metadata: metadata,
      trustScore: isHardware ? 100 : 70, // Hardware-backed keys get full trust score
    );

    // ⚡ Post-Bind (No memory caching for hardware/secure keys)
  }

  /// Helper to generate headers with signature for critical actions.
  @override
  Future<Map<String, String>> generateSignatureHeaders(String payload) async {
    // ⚡ Warm device credential cache on first call (parallel reads)
    if (_cachedDeviceId == null || _cachedIsHardware == null) {
      final results = await Future.wait([
        _secureStorage.read(_kDeviceIdKey),
        _secureStorage.read(_kIsHardwareKey),
      ]);
      _cachedDeviceId = results[0];
      _cachedIsHardware = results[1] == 'true';
    }

    final deviceId = _cachedDeviceId;
    if (deviceId == null) throw Exception('Device not bound. Cannot sign request.');
    final isHardware = _cachedIsHardware!;

    // Nonce + minute bucket for replay protection — must match server: "PAYLOAD:NONCE:MINUTE"
    final nonce = _uuidSource.v4();
    final minuteBucket = (DateTime.now().millisecondsSinceEpoch ~/ 60000).toString();
    final signaturePayload = '$payload:$nonce:$minuteBucket';

    String signature;
    if (isHardware) {
      final sig = await _cryptoService.signWithHardware(payload: signaturePayload);
      if (sig == null) throw Exception('Biometric authentication failed.');
      signature = sig;
    } else {
      // ⚡ Cache reconstructed key pair — expensive operation, result is stable
      if (_cachedKeyPair == null) {
        final privateKeyB64 = await _secureStorage.read(_kPrivateKeySeedKey);
        if (privateKeyB64 == null) {
          throw Exception('Security credentials missing. Please re-bind device.');
        }
        _cachedKeyPair = await _cryptoService.keyPairFromSeed(base64Decode(privateKeyB64));
      }
      signature = await _cryptoService.signPayload(_cachedKeyPair, signaturePayload);
    }

    return {
      'X-Device-Id': deviceId,
      'X-Device-Signature': signature,
      'X-Nonce': nonce,
      'X-Timestamp-Bucket': minuteBucket,
    };
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
      final errorStr = e.toString();
      // 🛡️ Enhanced Self-Healing: Trigger re-bind on:
      // 1. "Device not recognized" (Missing Binding)
      // 2. "Device signature verification failed" (Key Mismatch / Rotated Key)
      final shouldSelfHeal =
          (errorStr.contains('Device not recognized') ||
              errorStr.contains('Device signature verification failed') ||
              errorStr.contains('Device not bound') ||
              errorStr.contains('credentials missing')) &&
          retryCount < 1;

      if (shouldSelfHeal) {
        debugPrint(
          '🛡️ [Self-Healing] Sync issue detected: "$errorStr" (Attempt ${retryCount + 1}). Attempting Re-Bind...',
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
  Future<void> verifyPin(String pin, {bool serverVerify = false}) async {
    // ── Attempt guard ──────────────────────────────────────────────────────────
    final attemptsStr = await _secureStorage.read(_kPinAttemptCount);
    final attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
    if (attempts >= _kMaxLocalAttempts) {
      await clearAllPinData();
      throw Exception('Too many incorrect attempts. PIN data wiped for security.');
    }

    // ── Local fast-fail via AES-256-GCM decryption ────────────────────────────
    // Wrong PIN → GCM auth tag fails → throws → skip network, save latency.
    // No hash to brute-force offline; attacker needs device + Keychain + PIN.
    try {
      if (_cachedPinKey != null) {
        // ⚡ Warm path: reuse derived key from memory (~0ms)
        final encB64 = await _secureStorage.read(_kPinEncryptedToken);
        if (encB64 != null) {
          await _cryptoService.decryptPinToken(_cachedPinKey!, base64Decode(encB64));
          debugPrint('✅ [PIN] Local token verified (warm cache).');
        }
      } else {
        // Cold path: parallel read salt + token, derive key (~10ms)
        final results = await Future.wait([
          _secureStorage.read(_kPinEncryptedToken),
          _secureStorage.read(_kPinTokenSalt),
        ]);
        final encB64 = results[0];
        final saltB64 = results[1];

        if (encB64 != null && saltB64 != null) {
          final keyBytes = await compute(CryptoService.derivePinKey, {
            'pin': pin,
            'salt': base64Decode(saltB64),
          });
          await _cryptoService.decryptPinToken(keyBytes, base64Decode(encB64));
          _cachedPinKey = keyBytes;
          debugPrint('✅ [PIN] Local token verified (cold path).');
        } else {
          debugPrint('⚠️ [PIN] No local token — proceeding to server-only path.');
        }
      }
    } catch (e) {
      // GCM auth failure = wrong PIN. Increment counter and block network call.
      final next = attempts + 1;
      await _secureStorage.write(_kPinAttemptCount, next.toString());
      _cachedPinKey = null;
      debugPrint('❌ [PIN] Wrong PIN — attempt $next/$_kMaxLocalAttempts.');
      throw Exception('Incorrect PIN');
    }

    // ── Server gate (payment only) ────────────────────────────────────────────
    // For app unlock, local AES-256-GCM is sufficient — skip the ~500ms Argon2id
    // server call. For payment confirmation, always hit the server.
    if (serverVerify) {
      await _withDeviceSelfHealing(() async {
        final headers = await generateSignatureHeaders(pin);
        await _remoteDataSource.verifyPin(pin, headers: headers);

        await Future.wait([
          _secureStorage.write(_kPinAttemptCount, '0'),
          if (_cachedPinKey == null) _persistLocalPinToken(pin),
        ]);
      });
    } else {
      // Local-only path: reset attempt counter on success
      await _secureStorage.write(_kPinAttemptCount, '0');
    }
  }

  @override
  Future<void> initiatePinReset({required String challengeAnswer}) async {
    await _withDeviceSelfHealing(() async {
      final headers = await generateSignatureHeaders(challengeAnswer);
      await _remoteDataSource.initiatePinReset(
        answer: challengeAnswer,
        headers: headers,
      );
    });
  }

  @override
  Future<bool> isDeviceBound() async {
    final deviceId = await _secureStorage.read(_kDeviceIdKey);
    if (deviceId == null) {
      return false;
    }

    final isHardware = await _secureStorage.read(_kIsHardwareKey) == 'true';
    if (!isHardware) {
      final privateKey = await _secureStorage.read(_kPrivateKeySeedKey);
      if (privateKey == null) {
        return false;
      }
    }

    try {
      return await _remoteDataSource.isDeviceBound(deviceId);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasPin() async {
    // ⚡ Fast-Path: Check Disk Cache first
    final cached = await _secureStorage.read(_kHasPinCacheKey);
    if (cached != null) return cached == 'true';

    try {
      final status = await _remoteDataSource.getProfileStatus();
      final hasPin = status?['has_pin'] ?? false;

      // 📡 Side-Effect: Warm up the cache
      _secureStorage.write(_kHasPinCacheKey, hasPin.toString()).ignore();

      return hasPin;
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
      final headers = await generateSignatureHeaders(oldPin);
      await _remoteDataSource.changePin(
        oldPin: oldPin,
        newPin: newPin,
        headers: headers,
      );
      // Update local token ONLY after server confirms change
      await _persistLocalPinToken(newPin);
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
      final json = await _secureStorage.read(_kDevicesCacheKey);
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
    await _secureStorage.write(_kDevicesCacheKey, jsonEncode(devices));
    return devices;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchLinkedDevices() {
    return _remoteDataSource.watchLinkedDevices().map((devices) {
      // 📡 Side-Effect: Keep local cache synced with Real-time push
      _devicesCache = devices;
      _secureStorage.write(_kDevicesCacheKey, jsonEncode(devices)).ignore();
      return devices;
    });
  }

  @override
  Future<void> revokeDevice(String deviceId, {String? reason}) async {
    await _remoteDataSource.revokeDevice(deviceId, reason: reason);
  }

  @override
  Future<String?> getCurrentDeviceId() async {
    return await _secureStorage.read(_kDeviceIdKey);
  }

  @override
  Future<void> clearAllPinData() async {
    // Clear in-memory caches
    _cachedPinKey = null;
    _cachedDeviceId = null;
    _cachedIsHardware = null;
    _cachedKeyPair = null;

    // Remove all PIN-related Keychain entries
    await Future.wait([
      _secureStorage.delete(_kPinEncryptedToken),
      _secureStorage.delete(_kPinTokenSalt),
      _secureStorage.delete(_kPinAttemptCount),
      _secureStorage.delete(_kHasPinCacheKey),
      // Legacy cleanup
      _secureStorage.delete(_kLegacyPinHashKey),
      _secureStorage.delete(_kLegacyPinSaltKey),
    ]);

    debugPrint('🔒 [SecurityRepo] clearAllPinData: Local PIN data wiped.');
  }

  @override
  Future<void> clearSecurityData() async {
    // 1. Wipe Memory Cache
    _devicesCache = null;
    _cachedPinKey = null;
    _cachedDeviceId = null;
    _cachedIsHardware = null;
    _cachedKeyPair = null;

    // 2. Clear Disk Cache (Specifically the non-binding ones)
    // We keep device_binding_id/seed because it usually persists across logout
    // unless the user wants a full factory reset.
    await Future.wait([
      _secureStorage.delete(_kHasPinCacheKey),
      _secureStorage.delete(_kPinEncryptedToken),
      _secureStorage.delete(_kPinTokenSalt),
      _secureStorage.delete(_kPinAttemptCount),
      _secureStorage.delete(_kLegacyPinHashKey),
      _secureStorage.delete(_kLegacyPinSaltKey),
      _secureStorage.delete(_kDevicesCacheKey),
    ]);

    debugPrint('🔒 [SecurityRepo] Hard-Clear: Sensitive data wiped.');
  }

}
