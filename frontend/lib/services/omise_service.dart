import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OmiseService {
  static const String _vaultUrl = 'https://vault.omise.co';

  /// Creates a single-use token from card details via Omise Vault.
  /// This token (tokn_...) is safe to send to our backend.
  Future<String> createToken({
    required String name,
    required String number,
    required String expiryMonth,
    required String expiryYear,
    required String securityCode,
  }) async {
    final publicKey = dotenv.env['OMISE_PUBLIC_KEY'];
    if (publicKey == null ||
        publicKey.isEmpty ||
        publicKey.contains('PLACEHOLDER')) {
      throw Exception('Missing or invalid OMISE_PUBLIC_KEY in .env');
    }

    final url = Uri.parse('$_vaultUrl/tokens');

    try {
      final month = int.tryParse(expiryMonth);
      final year = int.tryParse(expiryYear);

      if (month == null || year == null) {
        throw const FormatException('Invalid expiry date format');
      }

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$publicKey:'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'card': {
            'name': name,
            'number': number.replaceAll(' ', ''),
            'expiration_month': month,
            'expiration_year': year,
            'security_code': securityCode,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id']; // tokn_test_...
      } else {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? 'Unknown Omise Error';
        throw Exception('Tokenization failed: $message');
      }
    } catch (e) {
      debugPrint('Omise Tokenization Error: $e');
      rethrow;
    }
  }
}
