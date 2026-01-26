import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/saved_card.dart';
import 'dart:async'; // Required for Completer

class ApiService {
  // 1. Return to localhost for simulator access via 127.0.0.1 (Android uses 10.0.2.2 usually, iOS 127.0.0.1)
  static String get baseUrl {
    final prodUrl = dotenv.env['BACKEND_URL'];
    if (prodUrl != null && prodUrl.isNotEmpty) {
      return prodUrl;
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080/api/v1';
    } else {
      return 'http://127.0.0.1:8080/api/v1';
    }
  }

  // 🛡️ Helper: Ensure Session is Fresh (Proactive + Mutex Lock)
  // Static Completer to handle concurrent refresh requests (The "Race Condition Killer")
  static Completer<void>? _refreshCompleter;

  // Made Public Static for Global Access (MainScreen, SecurityDataSource, etc.)
  static Future<void> ensureSessionValid({bool forceRefresh = false}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final expirationDate = JwtDecoder.getExpirationDate(session.accessToken);
    final timeUntilExpiration = expirationDate.difference(DateTime.now());

    // Proactive refresh if expiring soon (< 5 mins) OR if forced by 401 interceptor
    final needsRefresh = timeUntilExpiration.inMinutes < 5 || forceRefresh;

    if (!needsRefresh) {
      return;
    }

    // 🔒 MUTEX START: If a refresh is already running, wait for it.
    if (_refreshCompleter != null) {
      debugPrint("⏳ [Universal] Waiting for ongoing refresh...");
      await _refreshCompleter!.future;
      return;
    }

    // 🔒 LOCK: Start new refresh
    _refreshCompleter = Completer<void>();

    debugPrint(
      "⏳ [Universal] Token refresh triggered (force: $forceRefresh). Refreshing (SINGLE THREAD)...",
    );

    try {
      await Supabase.instance.client.auth.refreshSession();
      debugPrint("✅ [Universal] Token refreshed silently.");
      _refreshCompleter?.complete();
    } catch (e) {
      debugPrint("⚠️ [Universal] Silent refresh failed: $e");
      _refreshCompleter?.completeError(e);
      // We do NOT rethrow here to avoid crashing callers.
      // If refresh failed, subsequent API calls will fail 401 and trigger their own recovery loops if needed.
    } finally {
      // 🔓 UNLOCK: Clear completer so next check runs fresh
      _refreshCompleter = null;
    }
  }

  // 🛡️ Helper: Robust Edge Function Invoker (Total Control Edition)
  // Uses RAW HTTP to bypass any internal client state lag.
  // Made STATIC for universal use (Race condition proof).
  static Future<FunctionResponse> invokeEdgeFunction(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    // 1. Proactive Health Check
    await ApiService.ensureSessionValid();

    try {
      // 2. Initial Attempt (Raw HTTP)
      return await invokeRaw(functionName, body: body, headers: headers);
    } on FunctionException catch (e) {
      // 3. Catch 401 (Unauthorized) specifically
      // 🛡️ World-Class: Check if it's a REAL session error or a "Logical 401"
      final isLogicalError =
          e.details?['error']?.toString().contains('Device not recognized') ??
          false;

      if (e.status == 401 && !isLogicalError) {
        debugPrint(
          "🚨 [Universal Invoker] Caught 401 in $functionName. Force refreshing & Explicit retry...",
        );

        // 4. Force Refresh via Mutex Lock
        try {
          await ApiService.ensureSessionValid(forceRefresh: true);

          final freshToken =
              Supabase.instance.client.auth.currentSession?.accessToken;
          debugPrint(
            "✅ [Universal Invoker] Token refreshed. Retrying with explicit fresh token...",
          );

          // 5. Short Delay to allow session propagation
          await Future.delayed(const Duration(milliseconds: 300));

          // 6. Retry with EXPLICIT Fresh Token (Raw HTTP)
          return await invokeRaw(
            functionName,
            body: body,
            token: freshToken,
            headers: headers,
          );
        } catch (refreshError) {
          debugPrint(
            "❌ [Universal Invoker] Resilience recovery failed: $refreshError",
          );
          // 🛡️ World-Class Self-Healing: If refresh failed or server still rejects,
          // we throw the error so the caller can handle it (UI toast, etc).
          // DO NOT forcedly sign out here, as it causes death loops for server-side bugs.
          rethrow;
        }
      }
      rethrow;
    }
  }

  // 🛡️ Raw HTTP Invoker for Edge Functions
  // This provides absolute control over headers.
  static Future<FunctionResponse> invokeRaw(
    String functionName, {
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? headers,
  }) async {
    final client = Supabase.instance.client;
    final jwt = token ?? client.auth.currentSession?.accessToken ?? '';
    final sanitizedJwt = jwt.trim().replaceAll('\n', '').replaceAll('\r', '');

    final supabaseUrlBase = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseUrl = supabaseUrlBase.endsWith('/')
        ? supabaseUrlBase.substring(0, supabaseUrlBase.length - 1)
        : supabaseUrlBase;

    final supabaseKeyBase = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final supabaseKey = supabaseKeyBase
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '');

    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    }

    // Construct URL manually to avoid any client internal logic
    // Format: https://[project-id].supabase.co/functions/v1/[function-name]
    final functionUrl = Uri.parse('$supabaseUrl/functions/v1/$functionName');

    // Merge custom headers
    final Map<String, String> finalHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $sanitizedJwt',
      'apikey': supabaseKey,
      ...headers ?? {},
    };

    debugPrint('🌐 [RawInvoke] $functionName');

    final response = await http.post(
      functionUrl,
      headers: finalHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    debugPrint(
      '🌐 [RawInvoke] $functionName -> Status: ${response.statusCode}',
    );

    // Convert http.Response back to FunctionResponse to maintain compatibility
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decodedData = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;
      return FunctionResponse(data: decodedData, status: response.statusCode);
    } else {
      // Throw FunctionException to trigger the Interceptor
      Map<String, dynamic>? details;
      try {
        if (response.body.isNotEmpty) {
          details = jsonDecode(response.body);
        }
      } catch (e) {
        // Fallback for non-JSON error bodies
        details = {'error': response.body};
      }

      // 🔍 DEBUG: Print full error details for all non-2xx responses
      debugPrint('❌ [RawInvoke] Error - Details: $details');

      throw FunctionException(
        status: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        details: details,
      );
    }
  }

  // 🛡️ Global Request Interceptor (World-Class Resilience)
  // Wraps any http request with 401 Catch-Refresh-Retry logic.
  Future<http.Response> _safeRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    final headers = await _getHeaders();
    final response = await request(headers);

    if (response.statusCode == 401) {
      debugPrint("🚨 [Universal Interceptor] 401 detected. Recovery mode...");
      try {
        // 1. Synchronized Refresh
        await ApiService.ensureSessionValid(forceRefresh: true);

        // 2. Retry with pristine headers
        final freshHeaders = await _getHeaders();
        final retryResponse = await request(freshHeaders);

        debugPrint(
          "✅ [Universal Interceptor] Recovery successful. Status: ${retryResponse.statusCode}",
        );
        return retryResponse;
      } catch (e) {
        debugPrint("❌ [Universal Interceptor] Recovery failed: $e");
        // 3. Hard Reset if refresh fails
        await Supabase.instance.client.auth.signOut();
        rethrow;
      }
    }
    return response;
  }

  // 2. Helper to get headers
  Future<Map<String, String>> _getHeaders() async {
    await ApiService.ensureSessionValid(); // 🛡️ Universal Protection

    final session = Supabase.instance.client.auth.currentSession;
    final String token = session?.accessToken ?? '';
    final sanitizedJwt = token.trim().replaceAll('\n', '').replaceAll('\r', '');

    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final sanitizedApiKey = supabaseKey
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '');

    // 🛡️ World-Class: Always send both apikey and Authorization
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $sanitizedJwt',
      'apikey': sanitizedApiKey,
    };
  }

  // --- Exponential Backoff Retry Helper ---
  Future<T> _retry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool Function(Object)? shouldRetry,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await action();
      } catch (e) {
        final isLastAttempt = attempts >= maxAttempts;
        final worthRetrying =
            shouldRetry?.call(e) ??
            (e is SocketException || e is http.ClientException);

        if (isLastAttempt || !worthRetrying) {
          rethrow;
        }

        final delay = initialDelay * (1 << (attempts - 1)); // 1s, 2s, 4s...
        debugPrint(
          '⚠️ Network failure (Attempt $attempts). Retrying in ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);
      }
    }
  }

  // Get User Profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      await ApiService.ensureSessionValid(); // 🛡️ Protect Profile
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('preferred_payment_method_id, preferred_payment_method_type')
          .eq('id', user.id)
          .single();

      _cachedPreferredMethodId = response['preferred_payment_method_id'];
      _cachedPreferredMethodType = response['preferred_payment_method_type'];

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
    // 1. Update local cache IMMEDIATELY for instant UI feedback
    _cachedPreferredMethodId = methodId;
    _cachedPreferredMethodType = methodType;
    debugPrint(
      '⚡ Instant Sync: Payment preference cached: $methodId ($methodType)',
    );

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

      debugPrint('✅ Payment preference persisted to DB: $methodId');
    } catch (e) {
      debugPrint('Error updating payment preference: $e');
    }
  }

  // Get Wallet Balance
  // Example use in standard calls:
  Future<Map<String, dynamic>> getBalance(String currency) async {
    return _retry(() async {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/balance?currency=$currency'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load balance: ${response.statusCode}');
      }
    });
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
    final body = jsonEncode({
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'currency': currency,
      'idempotency_key': idempotencyKey,
      'description': description,
    });

    final response = await _safeRequest(
      (headers) => http.post(
        Uri.parse('$baseUrl/transfer'),
        headers: headers,
        body: body,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Transfer failed: ${response.body}');
    }
  }

  // Get Transactions
  Future<String> createPaymentIntent(double amount) async {
    final response = await _safeRequest(
      (headers) => http.post(
        Uri.parse('$baseUrl/payments/create-intent'),
        headers: headers,
        body: jsonEncode({'amount': amount, 'currency': 'thb'}),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['client_secret'];
    } else {
      throw Exception('Failed to create payment intent: ${response.body}');
    }
  }

  Future<List<dynamic>> getTransactions(String walletId) async {
    return _retry(() async {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/transactions?wallet_id=$walletId'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error: ${response.body}");
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    });
  }

  // Get Exchange Rate
  Future<Map<String, dynamic>> fetchExchangeRate(String homeCurrency) async {
    return _retry(() async {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/rates/latest?home_currency=$homeCurrency'),
          headers: headers,
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error (Rates): ${response.body}");
        throw Exception('Failed to load rates: ${response.statusCode}');
      }
    });
  }

  // Smart Routing Quote
  Future<Map<String, dynamic>> getQuote(
    double amount,
    String currency, {
    String? merchantId,
  }) async {
    try {
      final queryParams = {
        'amount': amount.toString(),
        'currency': currency,
        if (merchantId != null) 'merchant_id': merchantId,
      };

      final uri = Uri.parse(
        '$baseUrl/quote',
      ).replace(queryParameters: queryParams);

      final response = await _safeRequest(
        (headers) => http.get(uri, headers: headers),
      );

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

    try {
      debugPrint(
        '💸 Executing payout: $amountSatang satang to $targetType:$targetValue',
      );

      // 🛡️ Use Robust Invoker
      final response = await ApiService.invokeEdgeFunction(
        'payout-executor',
        body: {
          'user_id': user.id,
          'wallet_id': walletId,
          'amount_satang': amountSatang.toInt(),
          'target_type': targetType,
          'target_value': targetValue,
          'description': description ?? 'Paycif Payment',
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
    String? cardId,
    bool isApplePay = false,
    required String referenceId,
    String? description,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) throw Exception('User not authenticated');

    try {
      debugPrint(
        '💸 Executing Opn TopUp: $amountSatang satang (Token: ${token ?? "SAVED_CARD"}, Card: $cardId, ApplePay: $isApplePay)',
      );

      final payload = {
        'amount_satang': amountSatang.toInt(),
        if (token != null) 'token': token,
        if (cardId != null) 'card_id': cardId,
        if (isApplePay) 'is_apple_pay': true,
        'reference_id': referenceId,
        'description': description ?? 'Wallet Top Up',
        'currency': 'thb',
      };

      debugPrint('🚀 [ApiService] Sending Payload to Edge Function: $payload');

      // 🛡️ Use Robust Invoker
      final response = await ApiService.invokeEdgeFunction(
        'inbound-handler', // inbound-handler
        body: payload,
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
  static List<SavedCard>? _cachedSavedCards;
  static String? _cachedPreferredMethodId;
  static String? _cachedPreferredMethodType;

  // Get Cached Cards (Manual Access)
  static List<SavedCard>? getCachedCards() => _cachedSavedCards;

  // Get Cached Preferred Method (Manual Access)
  static String? getCachedPreferredMethodId() => _cachedPreferredMethodId;
  static String? getCachedPreferredMethodType() => _cachedPreferredMethodType;

  /// Clears all static caches. Call this on logout or account switch.
  static void clearStaticCache() {
    _cachedSavedCards = null;
    _cachedPreferredMethodId = null;
    _cachedPreferredMethodType = null;
    debugPrint('🧹 ApiService static cache cleared.');
  }

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
      // 🛡️ Use Robust Invoker
      final response = await ApiService.invokeEdgeFunction('get-saved-cards');

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

  // Save Card
  Future<void> saveCard(String token) async {
    try {
      debugPrint('💳 Saving new card with token: $token');
      // 🛡️ Use Robust Invoker
      final response = await ApiService.invokeEdgeFunction(
        'manage-payment-methods',
        body: {'action': 'add-card', 'token': token},
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] ?? 'Failed to save card';
        throw Exception(errorMessage);
      }

      // Clear cache to force refresh on next getSavedCards call
      _cachedSavedCards = null;
      debugPrint('✅ Card saved successfully (Cache cleared)');
    } catch (e) {
      debugPrint('❌ Save card error: $e');
      rethrow;
    }
  }

  // Delete Card
  Future<void> deleteCard(String cardId) async {
    try {
      debugPrint('🗑️ Deleting card: $cardId');
      // 🛡️ Use Robust Invoker
      final response = await ApiService.invokeEdgeFunction(
        'manage-payment-methods',
        body: {'action': 'delete-card', 'card_id': cardId},
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] ?? 'Failed to delete card';
        throw Exception(errorMessage);
      }

      // 2. Optimistic Update: Update cache directly instead of clearing it
      if (_cachedSavedCards != null) {
        _cachedSavedCards!.removeWhere((card) => card.id == cardId);
      }
      debugPrint('✅ Card deleted successfully (Cache Updated)');
    } catch (e) {
      debugPrint('❌ Delete card error: $e');
      rethrow;
    }
  }
}
