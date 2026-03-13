import 'package:biometric_signature/biometric_signature.dart';
import 'package:flutter/foundation.dart';

/// 🛡️ Hardware Security Bridge (Sentinel Enclave)
/// 
/// Abstraction layer that communicates with the device's Secure Enclave (iOS)
/// or TEE/StrongBox (Android) to perform hardware-locked cryptographic operations.
class HardwareSecurityBridge {
  final _plugin = BiometricSignature();

  /// Generates a new ECDSA (P-256) KeyPair within the Hardware Module.
  /// The Private Key is marked as non-exportable and locked behind Biometrics.
  Future<String?> createHardwareKeyPair({required String keyName}) async {
    try {
      final result = await _plugin.createKeys(
        promptMessage: 'Setup Secure Identity',
        keyFormat: KeyFormat.base64,
        config: CreateKeysConfig(
          signatureType: SignatureType.ecdsa, // 🛡️ Secure Enclave / TEE Standard
          enforceBiometric: true,
          setInvalidatedByBiometricEnrollment: true,
        ),
      );
      
      if (result.code == BiometricError.success) {
        debugPrint('🛡️ [HardwareBridge] KeyPair created in Enclave.');
        return result.publicKey;
      }
      debugPrint('❌ [HardwareBridge] Key creation failed: ${result.error}');
      return null;
    } catch (e) {
      debugPrint('❌ [HardwareBridge] Failed to create hardware key: $e');
      rethrow;
    }
  }

  /// Signs a payload using the hardware-protected private key.
  /// This will trigger a system biometric prompt (FaceID/Fingerprint).
  Future<String?> signPayload({
    required String payload,
    String? promptMessage,
  }) async {
    try {
      final result = await _plugin.createSignature(
        payload: payload,
        promptMessage: promptMessage ?? 'Authorize Transaction',
      );
      
      if (result.code == BiometricError.success) {
        return result.signature;
      }
      debugPrint('❌ [HardwareBridge] Signing failed: ${result.error}');
      return null;
    } catch (e) {
      debugPrint('❌ [HardwareBridge] Secure signing failed: $e');
      rethrow;
    }
  }

  /// Checks if a key exists in the hardware module.
  Future<bool> deviceSupportsHardwareSigning() async {
    try {
      final exists = await _plugin.biometricKeyExists();
      return exists == true;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a key from the hardware module.
  Future<void> deleteHardwareKey(String keyName) async {
    try {
      await _plugin.deleteKeys();
      debugPrint('🛡️ [HardwareBridge] Key "$keyName" revoked from Enclave.');
    } catch (e) {
      debugPrint('❌ [HardwareBridge] Failed to delete hardware key: $e');
    }
  }
}
