import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto_pkg;
import 'package:frontend/features/security/data/datasources/hardware_security_bridge.dart';

// PBKDF2 iterations: OWASP 2023 recommendation for PBKDF2-SHA256 on mobile
const _kPbkdf2Iterations = 10000;

/// Service responsible for cryptographic operations.
/// Supports Ed25519 (Software) and P256 (Hardware-Backed Secure Enclave).
class AppEncryptionService {
  final _algorithm = Ed25519();
  final _hardwareBridge = HardwareSecurityBridge();

  // 🛡️ [NEW] Hardware-Backed Operations
  
  /// Creates a hardware-backed identity in the Secure Enclave / TEE.
  Future<String?> createHardwareIdentity() async {
    return await _hardwareBridge.createHardwareKeyPair(keyName: 'paycif_sentinel_key');
  }

  /// Signs a payload using hardware-protected keys.
  /// Triggers Biometric Prompt.
  Future<String?> signWithHardware({
    required String payload,
  }) async {
    return await _hardwareBridge.signPayload(
      payload: payload,
    );
  }

  Future<void> revokeHardwareIdentity(String keyName) async {
    await _hardwareBridge.deleteHardwareKey(keyName);
  }

  // --- Software Fallbacks & PIN Hashing ---

  /// Generates a new Ed25519 KeyPair (Software-only).
  Future<SimpleKeyPair> generateKeyPair() async {
    return await _algorithm.newKeyPair();
  }

  /// Signs a message (bytes) using the provided KeyPair.
  /// Returns the signature as a list of bytes.
  Future<List<int>> sign(SimpleKeyPair keyPair, List<int> message) async {
    final signature = await _algorithm.sign(message, keyPair: keyPair);
    return signature.bytes;
  }

  /// Helper to sign a String payload.
  Future<String> signPayload(SimpleKeyPair keyPair, String payload) async {
    final messageBytes = utf8.encode(payload);
    final signatureBytes = await sign(keyPair, messageBytes);
    return base64Encode(signatureBytes);
  }

  /// Extracts the Public Key bytes from a KeyPair.
  Future<List<int>> getPublicKeyBytes(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return publicKey.bytes;
  }

  /// Extracts the Public Key as a Base64 String (for sending to API).
  Future<String> getPublicKeyBase64(SimpleKeyPair keyPair) async {
    final bytes = await getPublicKeyBytes(keyPair);
    return base64Encode(bytes);
  }

  /// Extracts the Private Key bytes (seed) for storage.
  /// WARNING: Handle these bytes with extreme care (SecureStorage only).
  Future<List<int>> getPrivateKeyBytes(SimpleKeyPair keyPair) async {
    final data = await keyPair.extract();
    return data.bytes;
  }

  static Future<Map<String, List<int>>> _deriveEd25519(List<int> seed) async {
    final kp = await Ed25519().newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    final pk = await kp.extract();
    return {
      'pk': pk.bytes,
      'pub': pub.bytes,
    };
  }

  /// Reconstructs a KeyPair from a raw private key seed/bytes.
  /// Runs in an isolate to prevent UI jank (takes 1-2s in pure Dart).
  Future<SimpleKeyPair> keyPairFromSeed(List<int> seed) async {
    final data = await compute(_deriveEd25519, seed);
    return SimpleKeyPairData(
      data['pk']!,
      publicKey: SimplePublicKey(data['pub']!, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
  }

  /// Generates a cryptographically secure 16-byte salt for Argon2 hashing.
  List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (i) => random.nextInt(256));
  }



  // ---------------------------------------------------------------------------
  // AES-256-GCM + PBKDF2-SHA256 PIN token — industry-standard local gate
  // ---------------------------------------------------------------------------

  /// Derives a 256-bit key from PIN + salt using PBKDF2-SHA256.
  /// Static so it can run in a compute() isolate (~10ms on modern device).
  static Future<List<int>> derivePinKey(Map<String, dynamic> params) async {
    final String pin = params['pin'];
    final List<int> salt = params['salt'];
    final int iterations = params['iterations'] ?? _kPbkdf2Iterations;

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  /// Encrypts [plaintext] with AES-256-GCM using [keyBytes].
  /// Returns nonce (12 B) + ciphertext + GCM auth tag (16 B) packed together.
  Future<List<int>> encryptPinToken(
    List<int> keyBytes,
    List<int> plaintext,
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(plaintext, secretKey: secretKey, nonce: nonce);
    return [...nonce, ...box.cipherText, ...box.mac.bytes];
  }

  /// Decrypts an AES-256-GCM packed blob produced by [encryptPinToken].
  /// Throws [SecretBoxAuthenticationError] if the PIN (key) is wrong.
  Future<List<int>> decryptPinToken(
    List<int> keyBytes,
    List<int> packed,
  ) async {
    const nonceLen = 12;
    const macLen = 16;
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(keyBytes);

    final nonce = packed.sublist(0, nonceLen);
    final mac = Mac(packed.sublist(packed.length - macLen));
    final cipherText = packed.sublist(nonceLen, packed.length - macLen);

    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    return algorithm.decrypt(box, secretKey: secretKey);
  }

  /// Generates [length] cryptographically secure random bytes.
  List<int> randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  /// Hashes a PIN with a salt using SHA-256 for secure in-memory comparison.
  /// This prevents storing plaintext PINs in memory.
  String hashPinForComparison(String pin, List<int> salt) {
    final bytes = utf8.encode(pin) + salt;
    final digest = crypto_pkg.sha256.convert(bytes);
    return digest.toString();
  }
}
