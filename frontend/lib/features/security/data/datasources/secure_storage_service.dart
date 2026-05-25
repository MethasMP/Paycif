import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for storing sensitive data (like Private Keys) securely.
/// Enforces hardware-backed encryption and access controls.
class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  /// Relaxed Options: For device identity (DeviceID).
  /// Required ONLY that the device has been unlocked at least once since boot.
  final _relaxedIosOptions = const IOSOptions(
    accessibility: KeychainAccessibility.unlocked,
    synchronizable: false,
  );

  /// Strict Options: For secrets (Private Keys, PIN Hashes).
  /// Requires device to be currently unlocked (Passcode/Biometric).
  final _strictIosOptions = const IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    synchronizable: false,
  );

  /// Android Options: Use EncryptedSharedPreferences (Hardware KeyStore).
  final _androidOptions = const AndroidOptions(resetOnError: true);

  /// Reads a value from secure storage.
  Future<String?> read(String key, {bool strict = false}) async {
    return await _storage.read(
      key: key,
      iOptions: strict ? _strictIosOptions : _relaxedIosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Writes a value to secure storage.
  Future<void> write(String key, String value, {bool strict = false}) async {
    await _storage.write(
      key: key,
      value: value,
      iOptions: strict ? _strictIosOptions : _relaxedIosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Deletes a value from secure storage.
  Future<void> delete(String key) async {
    await _storage.delete(
      key: key,
      iOptions: _strictIosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Checks if a key exists.
  Future<bool> containsKey(String key, {bool strict = false}) async {
    return await _storage.containsKey(
      key: key,
      iOptions: strict ? _strictIosOptions : _relaxedIosOptions,
      aOptions: _androidOptions,
    );
  }

  /// Clears all data (useful for reset/logout).
  Future<void> clear() async {
    await _storage.deleteAll(
      iOptions: _relaxedIosOptions,
      aOptions: _androidOptions,
    );
  }
}
