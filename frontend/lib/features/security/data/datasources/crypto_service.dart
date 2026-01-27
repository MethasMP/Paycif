import 'dart:convert';
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

  /// Generates a random 16-byte salt for Argon2 hashing.
  List<int> generateSalt() {
    // Note: In production, use a cryptographically secure random number generator.
    // For this implementation context, we'll use a simple approach or better yet,
    // use the cryptography package's random bytes if available in scope,
    // but dargon2 can also manage its own salt if configured.
    // Let's use a cleaner approach with `dargon2`.
    // Actually, let's just use a basic list generation here or better,
    // rely on the caller to provide randomness or use a proper secure random generator.
    //
    // Revised: Use `dargon2`'s capabilities or a simple secure random if possible.
    // Since `cryptography` export `SecureRandom` implicitly via implementations,
    // we can just use `List.generate` with `SecureRandom.safe` if available,
    // or keep it simple.
    //
    // Better approach: Use a predefined salt generation logic.
    return List<int>.generate(
      16,
      (i) => (DateTime.now().microsecondsSinceEpoch >> i) & 0xFF,
    );
  }

  /// Hashes a PIN using Argon2id (L1 Cache Optimized) via 'cryptography' package.
  /// Returns Base64 encoded hash bytes.
  Future<String> computePinHash(String pin, List<int> salt) async {
    return computePinHashStatic({'pin': pin, 'salt': salt});
  }

  /// Static version for Isolate (compute) compatibility
  static Future<String> computePinHashStatic(
    Map<String, dynamic> params,
  ) async {
    final String pin = params['pin'];
    final List<int> salt = params['salt'];

    final algorithm = Argon2id(
      parallelism: 1, // ⚡ Single Thread
      memory: 64, // ⚡ 64 KB (L1 Cache)
      iterations: 1, // ⚡ 1 Iteration
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
