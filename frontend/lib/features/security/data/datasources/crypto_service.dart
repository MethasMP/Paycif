import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Service responsible for cryptographic operations using Ed25519.
/// This service handles key generation, signing, and public key extraction.
class CryptoService {
  final _algorithm = Ed25519();

  /// Generates a new Ed25519 KeyPair.
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

  /// Reconstructs a KeyPair from a raw private key seed/bytes.
  /// This is needed when retrieving the key from Secure Storage.
  Future<SimpleKeyPair> keyPairFromSeed(List<int> seed) async {
    return _algorithm.newKeyPairFromSeed(seed);
  }

  /// Generates a cryptographically secure 16-byte salt for Argon2 hashing.
  List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (i) => random.nextInt(256));
  }

  /// Hashes a PIN using Argon2id (L1 Cache Optimized) via 'cryptography' package.
  /// Returns Base64 encoded hash bytes.
  Future<String> computePinHash(String pin, List<int> salt) async {
    return computePinHashStatic({'pin': pin, 'salt': salt});
  }

  /// Static version for Isolate (compute) compatibility
  /// Uses OWASP/RFC 9106 compliant parameters (32MB, 3 iterations)
  /// For server-side verification - maximum security
  static Future<String> computePinHashStatic(
    Map<String, dynamic> params,
  ) async {
    final String pin = params['pin'];
    final List<int> salt = params['salt'];

    final algorithm = Argon2id(
      parallelism: 1, // ⚡ Single Thread (predictable for mobile)
      memory:
          32768, // 🛡️ 32 MB (OWASP/RFC 9106 defense against GPU/ASIC attacks)
      iterations:
          3, // 🛡️ 3 Iterations (Increased time-cost for brute-force defense)
      hashLength: 32,
    );

    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );

    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Fast version for local optimistic verification only
  /// ⚠️ UPDATED: Now uses SAME parameters as Static (32MB, 3 iterations)
  /// to ensure hash consistency. Speed is sacrificed for correctness.
  static Future<String> computePinHashFast(Map<String, dynamic> params) async {
    final String pin = params['pin'];
    final List<int> salt = params['salt'];

    final algorithm = Argon2id(
      parallelism: 1, // ⚡ Single Thread
      memory: 32768, // 🛡️ 32 MB (Same as Setup)
      iterations: 3, // 🛡️ 3 Iterations (Same as Setup)
      hashLength: 32,
    );

    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );

    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Verifies a PIN by re-computing the hash and comparing.
  Future<bool> verifyPinHashWithSalt(
    String pin,
    String expectedHash,
    List<int> salt,
  ) async {
    final computedHash = await computePinHash(pin, salt);
    return computedHash == expectedHash;
  }

  // Legacy support for the interface, though repository should use verifyPinHashWithSalt
  Future<bool> verifyPinHash(String pin, String encodedHash) async {
    throw UnimplementedError("Use verifyPinHashWithSalt instead");
  }
}
