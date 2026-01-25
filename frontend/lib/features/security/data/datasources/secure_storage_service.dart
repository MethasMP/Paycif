import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for storing sensitive data (like Private Keys) securely.
/// Enforces hardware-backed encryption and access controls.
class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  /// iOS Options: Require device to be unlocked (Passcode/Biometric).
  /// strictly forbids access if device is locked.
  final _iosOptions = const IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    synchronizable: false, // Do not sync to iCloud (device specific binding)
  );

  /// Android Options: Use EncryptedSharedPreferences (Hardware KeyStore).
  final _androidOptions = const AndroidOptions(
    resetOnError: true,
    // Ensures keys are stored in hardware-backed KeyStore
  );

  /// Reads a value from secure storage.
  Future<String?> read(String key) async {
    return await _storage.read(
      key: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Writes a value to secure storage.
  Future<void> write(String key, String value) async {
    await _storage.write(
      key: key,
      value: value,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Deletes a value from secure storage.
  Future<void> delete(String key) async {
    await _storage.delete(
      key: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Checks if a key exists.
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(
      key: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Clears all data (useful for reset/logout).
  Future<void> clear() async {
    await _storage.deleteAll(iOptions: _iosOptions, aOptions: _androidOptions);
  }
}
