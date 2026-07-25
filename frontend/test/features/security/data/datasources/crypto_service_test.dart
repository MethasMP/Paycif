import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:frontend/features/security/data/datasources/app_encryption_service.dart';
import 'dart:convert';

void main() {
  late AppEncryptionService cryptoService;

  setUp(() {
    cryptoService = AppEncryptionService();
  });

  group('CryptoService Security Audit', () {
    test('Should generate a valid Ed25519 KeyPair', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();

      expect(publicKey.bytes.length, 32, reason: 'Ed25519 Public Key must be 32 bytes');
      expect(keyPair, isNotNull);
    });

    test('Should generate unique keys on subsequent calls', () async {
      final keyPair1 = await cryptoService.generateKeyPair();
      final keyPair2 = await cryptoService.generateKeyPair();

      final pub1 = await keyPair1.extractPublicKey();
      final pub2 = await keyPair2.extractPublicKey();

      expect(pub1.bytes, isNot(equals(pub2.bytes)), reason: 'Keys must be unique');
    });

    test('Should sign a payload successfully', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final messageBytes = utf8.encode('critical-transaction-data');
      final signature = await cryptoService.sign(keyPair, messageBytes);

      expect(signature.length, 64, reason: 'Ed25519 Signature must be 64 bytes');
    });

    test('Should verify its own signature securely', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final messageBytes = utf8.encode('verify-integrity');
      final signature = await cryptoService.sign(keyPair, messageBytes);
      final publicKey = await keyPair.extractPublicKey();

      final isValid = await Ed25519().verify(
        messageBytes,
        signature: Signature(signature, publicKey: publicKey),
      );

      expect(isValid, isTrue, reason: 'Signature verification failed');
    });

    test('Should correctly helper signPayload returning Base64', () async {
      final keyPair = await cryptoService.generateKeyPair();
      final signatureBase64 = await cryptoService.signPayload(keyPair, 'base64-test');

      expect(base64Decode(signatureBase64).length, 64);
    });

    test('Should restore key pair deterministically from seed', () async {
      final seed = List<int>.generate(32, (i) => i);
      final kp1 = await cryptoService.keyPairFromSeed(seed);
      final kp2 = await cryptoService.keyPairFromSeed(seed);

      final pub1 = await kp1.extractPublicKey();
      final pub2 = await kp2.extractPublicKey();

      expect(pub1.bytes, equals(pub2.bytes), reason: 'Deterministic generation failed');
    });

    // -------------------------------------------------------------------------
    // AES-256-GCM + PBKDF2-SHA256 PIN token — new industry-standard local gate
    // -------------------------------------------------------------------------
    group('PIN Token (AES-256-GCM + PBKDF2-SHA256)', () {
      test('derivePinKey produces consistent key for same PIN + salt', () async {
        final salt = cryptoService.randomBytes(32);
        const pin = '123456';

        final key1 = await AppEncryptionService.derivePinKey({'pin': pin, 'salt': salt});
        final key2 = await AppEncryptionService.derivePinKey({'pin': pin, 'salt': salt});

        expect(key1, equals(key2));
        expect(key1.length, 32);
      });

      test('derivePinKey produces different keys for different PINs', () async {
        final salt = cryptoService.randomBytes(32);

        final key1 = await AppEncryptionService.derivePinKey({'pin': '123456', 'salt': salt});
        final key2 = await AppEncryptionService.derivePinKey({'pin': '654321', 'salt': salt});

        expect(key1, isNot(equals(key2)));
      });

      test('derivePinKey produces different keys for different salts', () async {
        const pin = '123456';

        final key1 = await AppEncryptionService.derivePinKey({
          'pin': pin,
          'salt': cryptoService.randomBytes(32),
        });
        final key2 = await AppEncryptionService.derivePinKey({
          'pin': pin,
          'salt': cryptoService.randomBytes(32),
        });

        expect(key1, isNot(equals(key2)));
      });

      test('encrypt then decrypt returns original plaintext', () async {
        final key = await AppEncryptionService.derivePinKey({
          'pin': '123456',
          'salt': cryptoService.randomBytes(32),
        });
        final plaintext = cryptoService.randomBytes(32);

        final packed = await cryptoService.encryptPinToken(key, plaintext);
        final decrypted = await cryptoService.decryptPinToken(key, packed);

        expect(decrypted, equals(plaintext));
      });

      test('decryptPinToken throws on wrong key (wrong PIN)', () async {
        final salt = cryptoService.randomBytes(32);
        final correctKey = await AppEncryptionService.derivePinKey({'pin': '123456', 'salt': salt});
        final wrongKey = await AppEncryptionService.derivePinKey({'pin': '000000', 'salt': salt});

        final packed = await cryptoService.encryptPinToken(correctKey, cryptoService.randomBytes(32));

        expect(
          () async => cryptoService.decryptPinToken(wrongKey, packed),
          throwsA(isA<SecretBoxAuthenticationError>()),
          reason: 'Wrong PIN must fail GCM auth tag',
        );
      });

      test('each encrypt produces unique ciphertext (random nonce)', () async {
        final key = await AppEncryptionService.derivePinKey({
          'pin': '123456',
          'salt': cryptoService.randomBytes(32),
        });
        final plaintext = cryptoService.randomBytes(32);

        final packed1 = await cryptoService.encryptPinToken(key, plaintext);
        final packed2 = await cryptoService.encryptPinToken(key, plaintext);

        expect(packed1, isNot(equals(packed2)), reason: 'Random nonce must produce unique ciphertext');
      });

      test('randomBytes generates correct length and is non-deterministic', () {
        final b1 = cryptoService.randomBytes(32);
        final b2 = cryptoService.randomBytes(32);

        expect(b1.length, 32);
        expect(b2.length, 32);
        expect(b1, isNot(equals(b2)));
      });
    });
  });
}
