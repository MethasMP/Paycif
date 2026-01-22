import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/saved_card.dart';

class ApiService {
  // 1. Return to localhost for simulator access via 127.0.0.1 (Android uses 10.0.2.2 usually, iOS 127.0.0.1)
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android Emulator มอง localhost เป็น 10.0.2.2
      return 'http://10.0.2.2:8080/api/v1';
    } else {
      // iOS Simulator และ macOS มอง localhost เป็น 127.0.0.1
      return 'http://127.0.0.1:8080/api/v1';
    }
  }

  // 2. Helper to get headers
  Future<Map<String, String>> _getHeaders() async {
    // Get the current session's access token from Supabase Auth
    final String token =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';

    if (token.isNotEmpty) {
      if (JwtDecoder.isExpired(token)) {
        debugPrint(
          "❌ Token EXPIRED! Expired at: ${JwtDecoder.getExpirationDate(token)}",
        );
      } else {
        debugPrint(
          "✅ Token Valid. Expires: ${JwtDecoder.getExpirationDate(token)}",
        );
      }
    } else {
      debugPrint("⚠️ No Token Available");
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('preferred_payment_method_id, preferred_payment_method_type')
          .eq('id', user.id)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  // Update Preferred Payment Method
  Future<void> updatePaymentPreference(
    String methodId,
    String methodType,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({
            'preferred_payment_method_id': methodId,
            'preferred_payment_method_type': methodType,
          })
          .eq('id', user.id);

      debugPrint('✅ Payment preference updated: $methodId ($methodType)');
    } catch (e) {
      debugPrint('Error updating payment preference: $e');
    }
  }

  // Get Wallet Balance
  Future<Map<String, dynamic>> getBalance(String currency) async {
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/balance?currency=$currency'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error: ${response.body}");
        throw Exception('Failed to load balance: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
      throw Exception('Could not connect to Backend');
    }
  }

  // Transfer Funds
  Future<void> transferFunds({
    required String toWalletId,
    required String fromWalletId,
    required int amount,
    required String currency,
    required String idempotencyKey,
    String description = '',
  }) async {
    final headers = await _getHeaders();
    final body = jsonEncode({
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'currency': currency,
      'idempotency_key': idempotencyKey,
      'description': description,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/transfer'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Transfer failed: ${response.body}');
    }
  }

  // Get Transactions
  Future<String> createPaymentIntent(double amount) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/payments/create-intent'),
      headers: headers,
      body: jsonEncode({'amount': amount, 'currency': 'thb'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['client_secret'];
    } else {
      throw Exception('Failed to create payment intent: ${response.body}');
    }
  }

  Future<List<dynamic>> getTransactions(String walletId) async {
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transactions?wallet_id=$walletId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error: ${response.body}");
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
      throw Exception('Could not connect to Backend');
    }
  }

  // Get Exchange Rate
  Future<Map<String, dynamic>> fetchExchangeRate(String homeCurrency) async {
    final headers = await _getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rates/latest?home_currency=$homeCurrency'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error (Rates): ${response.body}");
        throw Exception('Failed to load rates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Connection Error (Rates): $e");
      throw Exception('Could not connect to Backend for Rates');
    }
  }

  // Smart Routing Quote
  Future<Map<String, dynamic>> getQuote(
    double amount,
    String currency, {
    String? merchantId,
  }) async {
    final headers = await _getHeaders();
    try {
      final queryParams = {
        'amount': amount.toString(),
        'currency': currency,
        if (merchantId != null) 'merchant_id': merchantId,
      };

      final uri = Uri.parse(
        '$baseUrl/quote',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error (Quote): ${response.body}");
        throw Exception('Failed to load quote: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Connection Error (Quote): $e");
      throw Exception('Could not connect to Backend for Quote');
    }
  }

  // ============================================================================
  // Execute Payout (calls payout-executor Edge Function)
  // ============================================================================
  /// Executes a real payout by calling the Supabase Edge Function.
  /// This deducts balance from wallet, creates transaction and ledger entry.
  Future<Map<String, dynamic>> executePayout({
    required String walletId,
    required double amountSatang,
    required String targetType, // MOBILE, NATID, EWALLET
    required String targetValue,
    String? description,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not authenticated');
    }

    final session = supabase.auth.currentSession;
    if (session == null) {
      throw Exception('No active session found! Please login again.');
    }

    final token = session.accessToken;

    // Check if token is expired
    if (JwtDecoder.isExpired(token)) {
      debugPrint('❌ Token is EXPIRED!');
      throw Exception('Token expired. Please login again.');
    } else {
      debugPrint(
        '✅ Token is Valid. Expires: ${JwtDecoder.getExpirationDate(token)}',
      );
    }

    try {
      debugPrint(
        '💸 Executing payout: $amountSatang satang to $targetType:$targetValue',
      );

      final response = await supabase.functions.invoke(
        'payout-executor',
        body: {
          'user_id': user.id,
          'wallet_id': walletId,
          'amount_satang': amountSatang.toInt(),
          'target_type': targetType,
          'target_value': targetValue,
          'description': description ?? 'ZapPay Payment',
        },
      );

      debugPrint('💸 Payout response status: ${response.status}');

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? 'Payout failed';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      debugPrint('✅ Payout success: ${data['transaction_id']}');

      return data;
    } catch (e) {
      debugPrint('❌ Payout error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Execute OPn TopUp (calls inbound-handler Edge Function)
  // ============================================================================
  Future<Map<String, dynamic>> executeOpnTopUp({
    required int amountSatang,
    String? token, // Now optional for Saved Cards
    required String referenceId,
    String? description,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) throw Exception('User not authenticated');

    try {
      debugPrint(
        '💸 Executing Opn TopUp: $amountSatang satang (Token: ${token ?? "SAVED_CARD"})',
      );

      final response = await supabase.functions.invoke(
        'inbound-handler', // inbound-handler
        body: {
          'amount_satang': amountSatang.toInt(),
          if (token != null) 'token': token,
          'reference_id': referenceId,
          'description': description ?? 'Wallet Top Up',
          'currency': 'thb',
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? 'TopUp failed';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>;
      debugPrint('✅ TopUp success: ${data['message']}');
      return data;
    } catch (e) {
      debugPrint('❌ TopUp error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // Get Saved Cards (calls get-saved-cards Edge Function)
  // Implements in-memory caching ("Frontend Redis-like experience")
  // ============================================================================
  // ============================================================================
  // Get Saved Cards (calls get-saved-cards Edge Function)
  // Implements in-memory caching ("Frontend Redis-like experience")
  // ============================================================================
  static List<SavedCard>? _cachedSavedCards;

  // Get Cached Cards (Manual Access)
  static List<SavedCard>? getCachedCards() => _cachedSavedCards;

  Future<List<SavedCard>> getSavedCards({bool forceRefresh = false}) async {
    // 1. Return cached data if available and not forced to refresh
    if (_cachedSavedCards != null && !forceRefresh) {
      debugPrint('🚀 Using cached saved cards (Instant Load)');
      return _cachedSavedCards!;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    try {
      debugPrint('🌐 Fetching saved cards from Edge Function...');
      final response = await supabase.functions.invoke('get-saved-cards');

      if (response.status != 200) {
        debugPrint('Failed to get saved cards: ${response.status}');
        return [];
      }

      final data = response.data as Map<String, dynamic>;
      final cardsData = data['cards'] as List<dynamic>? ?? [];

      final cards = cardsData
          .map((json) => SavedCard.fromJson(json as Map<String, dynamic>))
          .toList();

      // 2. Update Cache
      _cachedSavedCards = cards;
      return cards;
    } catch (e) {
      debugPrint('Error getting saved cards: $e');
      return [];
    }
  }

  // Delete Card
  Future<void> deleteCard(String cardId) async {
    final supabase = Supabase.instance.client;
    try {
      debugPrint('🗑️ Deleting card: $cardId');
      final response = await supabase.functions.invoke(
        'manage-payment-methods',
        body: {'action': 'delete-card', 'card_id': cardId},
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] ?? 'Failed to delete card';
        throw Exception(errorMessage);
      }

      // Successfully deleted, clear cache to force refresh
      _cachedSavedCards = null;
      debugPrint('✅ Card deleted successfully');
    } catch (e) {
      debugPrint('❌ Delete card error: $e');
      rethrow;
    }
  }
}
