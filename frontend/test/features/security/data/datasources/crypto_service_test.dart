import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:frontend/features/security/data/datasources/crypto_service.dart';
import 'dart:convert';

void main() {
  late CryptoService cryptoService;

  setUp(() {
    cryptoService = CryptoService();
  });

  group('CryptoService Security Audit', () {
    test('Should generate a valid Ed25519 KeyPair', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();

      expect(
        publicKey.bytes.length,
        32,
        reason: 'Ed25519 Public Key must be 32 bytes',
      );
      expect(keyPair, isNotNull);
    });

    test('Should generate unique keys on subsequent calls', () async {
      final keyPair1 = await cryptoService.generateKeyPair();
      final keyPair2 = await cryptoService.generateKeyPair();

      final pub1 = await keyPair1.extractPublicKey();
      final pub2 = await keyPair2.extractPublicKey();

      expect(
        pub1.bytes,
        isNot(equals(pub2.bytes)),
        reason: 'Keys must be unique',
      );
    });

    test('Should sign a payload successfully', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final payload = 'critical-transaction-data';
      final messageBytes = utf8.encode(payload);

      final signature = await cryptoService.sign(keyPair, messageBytes);

      expect(
        signature.length,
        64,
        reason: 'Ed25519 Signature must be 64 bytes',
      );
    });

    test('Should verify its own signature securely', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final payload = 'verify-integrity';
      final messageBytes = utf8.encode(payload);

      final signature = await cryptoService.sign(keyPair, messageBytes);
      final publicKey = await keyPair.extractPublicKey();

      final algorithm = Ed25519();
      final isValid = await algorithm.verify(
        messageBytes,
        signature: Signature(signature, publicKey: publicKey),
      );

      expect(isValid, isTrue, reason: 'Signature verification failed');
    });

    test('Should correctly helper signPayload returning Base64', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final payload = 'base64-test';

      final signatureBase64 = await cryptoService.signPayload(keyPair, payload);

      // Decode back to check length
      final signatureBytes = base64Decode(signatureBase64);
      expect(signatureBytes.length, 64);
    });

    test('Should handle key restoration from seed correctly', () async {
      // Create a random seed (32 bytes for Ed25519)
      final seed = List<int>.generate(32, (i) => i);

      final keyPair1 = await cryptoService.keyPairFromSeed(seed);
      final keyPair2 = await cryptoService.keyPairFromSeed(seed);

      final pub1 = await keyPair1.extractPublicKey();
      final pub2 = await keyPair2.extractPublicKey();

      expect(
        pub1.bytes,
        equals(pub2.bytes),
        reason: 'Deterministic generation failed',
      );
    });
  });
}
