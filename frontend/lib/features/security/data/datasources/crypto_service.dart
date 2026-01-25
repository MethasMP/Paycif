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
}
