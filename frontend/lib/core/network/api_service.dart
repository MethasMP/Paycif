import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/models/decoded_qr.dart';
import 'package:frontend/core/models/quotation_model.dart';
import 'package:frontend/features/transactions/domain/transaction.dart';
import 'dart:async'; // Required for Completer
import 'package:frontend/core/router/app_router.dart';

class ApiService {
  // 🛡️ Local-dev-only fallback for Supabase demo project. NEVER used outside
  // kDebugMode — release/profile builds must always pass --dart-define.
  static const String _localDevSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  /// Resolves a required `--dart-define` value. Falls back to a local-dev
  /// default ONLY in debug builds; release/profile builds fail fast instead
  /// of silently shipping with dev credentials.
  static String requireEnv(String value, String name, {String? debugFallback}) {
    if (value.isNotEmpty) return value;
    if (kDebugMode && debugFallback != null) {
      return debugFallback;
    }
    throw Exception(
      '🚨 FATAL: $name is missing. Pass it via --dart-define=$name=... at build time.',
    );
  }

  static String get supabaseAnonKey => requireEnv(
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
        'SUPABASE_ANON_KEY',
        debugFallback: _localDevSupabaseAnonKey,
      );

  // 🔌 CIRCUIT BREAKER: Stop hammering a dead backend
  static bool _isBackendDead = false;
  static DateTime? _lastBackendFailure;
  static const Duration _circuitBreakerCooldown = Duration(seconds: 30);

  /// Check if backend is likely down (Circuit Breaker)
  static bool get isBackendAvailable {
    if (!_isBackendDead) return true;
    // Auto-reset after cooldown period
    final lastFailure = _lastBackendFailure;
    if (lastFailure != null &&
        DateTime.now().difference(lastFailure) >
            _circuitBreakerCooldown) {
      _isBackendDead = false;
      debugPrint('🟢 [Circuit Breaker] Cooldown expired. Retrying backend...');
      return true;
    }
    return false;
  }

  /// Mark backend as dead (Circuit Breaker triggered)
  static void _markBackendDead() {
    if (!_isBackendDead) {
      debugPrint(
        '🔴 [Circuit Breaker] Backend marked as DEAD. Pausing requests for ${_circuitBreakerCooldown.inSeconds}s.',
      );
    }
    _isBackendDead = true;
    _lastBackendFailure = DateTime.now();
  }

  /// 🚀 Manual Reset (Used when user clicks 'Retry')
  static void resetCircuitBreaker() {
    if (_isBackendDead) {
      debugPrint('🟢 [Circuit Breaker] Manual reset triggered.');
      _isBackendDead = false;
      _lastBackendFailure = null;
    }
  }

  static String? _customHostOverride;

  /// Helper to dynamically replace 'localhost' / '127.0.0.1' with '10.0.2.2' for Android Emulator.
  static String resolveLocalHost(String url) {
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      if (Platform.isAndroid) {
        return url.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
      }
    }
    return url;
  }

  /// Initialize custom host override from local storage
  static Future<void> initHostOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customHostOverride = prefs.getString('custom_backend_url');
    } catch (e) {
      debugPrint('⚠️ [ApiService] Failed to initialize host override: $e');
    }
  }

  /// Save and update custom host override
  static Future<void> saveHostOverride(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url.trim().isEmpty) {
        await prefs.remove('custom_backend_url');
        _customHostOverride = null;
      } else {
        await prefs.setString('custom_backend_url', url.trim());
        _customHostOverride = url.trim();
      }
    } catch (e) {
      debugPrint('⚠️ [ApiService] Failed to save host override: $e');
    }
  }

  // 🚀 World-Class URL Management
  // Use: flutter run --dart-define=BACKEND_URL=http://192.168.1.XX:8080/api/v1
  static String get baseUrl {
    String url = '';
    // 0. Try Custom Host Override (Run Anywhere developer feature)
    final hostOverride = _customHostOverride;
    if (hostOverride != null && hostOverride.isNotEmpty) {
      url = hostOverride;
    } else {
      // 1. Try Dart Define (The most flexible way)
      const defineUrl = String.fromEnvironment('BACKEND_URL');
      if (defineUrl.isNotEmpty) {
        url = defineUrl;
      } else {
        // 2. Fallback logic for Local Development only — release/profile
        // builds must always pass --dart-define=BACKEND_URL=...
        url = requireEnv(
          '',
          'BACKEND_URL',
          debugFallback: Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080',
        );
      }
    }

    url = resolveLocalHost(url);
    if (!url.endsWith('/api/v1')) {
      url = url.endsWith('/') ? '${url}api/v1' : '$url/api/v1';
    }
    return url;
  }

  /// ️ [Performance] Pre-warm Connection
  /// Establishes TCP/TLS handshake with the backend and Supabase Auth early
  /// to eliminate connection setup delays for the first actual request.
  static Future<void> prewarmConnection() async {
    try {
      debugPrint('🕯️ [Warm-up] Priming connection to $baseUrl...');
      // Use a valid endpoint to avoid 404 logs
      final warmUpUrl = Uri.parse('$baseUrl/rates/latest?home_currency=USD');
      await http.head(warmUpUrl).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore failures
    }

    try {
      final supabaseUrlBase = requireEnv(
        const String.fromEnvironment('SUPABASE_URL'),
        'SUPABASE_URL',
        debugFallback: 'http://127.0.0.1:54321',
      );
      final supabaseUrl = resolveLocalHost(supabaseUrlBase);
      debugPrint('🕯️ [Warm-up] Priming connection to Supabase at $supabaseUrl...');
      final warmUpSupabase = Uri.parse('$supabaseUrl/auth/v1/health');
      await http.get(warmUpSupabase).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore failures
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
    final completer = _refreshCompleter;
    if (completer != null) {
      debugPrint("⏳ [Universal] Waiting for ongoing refresh...");
      await completer.future;
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
      rethrow; // 🛡️ World-Class: Propagate error so caller knows refresh failed
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
    // 🌍 FIRST PRINCIPLE: Remove Proactive Check.
    // Don't wait 100ms to check if valid. Assume valid, then recover on 401.

    try {
      // 2. Initial Attempt (Raw HTTP)
      return await invokeRaw(functionName, body: body, headers: headers);
    } on FunctionException catch (e) {
      // 3. Catch 401 (Unauthorized) specifically
      // Distinguish JWT-expired 401s from domain-logic 401s (wrong PIN, unbound
      // device, etc.) — domain errors must not trigger a token refresh + retry.
      final errorDetail = e.details?['error']?.toString() ?? '';
      final isLogicalError =
          errorDetail.contains('Device not recognized') ||
          errorDetail.contains('Invalid PIN') ||
          errorDetail.contains('PIN not') ||
          errorDetail.contains('Device not bound') ||
          errorDetail.contains('Account locked');

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

    final supabaseUrlBase = requireEnv(
      const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_URL',
      debugFallback: 'http://127.0.0.1:54321',
    );
    final resolvedUrl = resolveLocalHost(supabaseUrlBase);
    final supabaseUrl = resolvedUrl.endsWith('/')
        ? resolvedUrl.substring(0, resolvedUrl.length - 1)
        : resolvedUrl;

    final supabaseKey = supabaseAnonKey
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '');

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
    ).timeout(const Duration(seconds: 30));

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
    final response = await request(headers).timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      debugPrint("🚨 [Universal Interceptor] 401 detected. Recovery mode...");
      try {
        // 1. Synchronized Refresh
        await ApiService.ensureSessionValid(forceRefresh: true);

        // 2. Retry with pristine headers
        final freshHeaders = await _getHeaders();
        final retryResponse = await request(freshHeaders).timeout(const Duration(seconds: 30));

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
    if (response.statusCode == 403 && response.body.contains("service_unavailable_in_region")) {
      debugPrint("🚨 [Universal Interceptor] Geofencing block triggered. Redirecting to BlockedScreen...");
      appRouter.go('/blocked');
      return response;
    }

    return response;
  }

  // 2. Helper to get headers
  Future<Map<String, String>> _getHeaders() async {
    await ApiService.ensureSessionValid(); // 🛡️ Universal Protection

    final session = Supabase.instance.client.auth.currentSession;
    final String token = session?.accessToken ?? '';
    final sanitizedJwt = token.trim().replaceAll('\n', '').replaceAll('\r', '');

    final sanitizedApiKey = supabaseAnonKey
        .trim()
        .replaceAll('\n', '').replaceAll('\r', '');

    // 🛡️ World-Class: Always send both apikey and Authorization
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $sanitizedJwt',
      'apikey': sanitizedApiKey,
    };
  }

  // --- Exponential Backoff Retry Helper (with Circuit Breaker) ---
  Future<T> _retry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool Function(Object)? shouldRetry,
    bool isCritical =
        true, // Non-critical calls (like Rates) won't retry at all
  }) async {
    // 🔌 Circuit Breaker: Fast-fail if backend is known to be dead
    if (!ApiService.isBackendAvailable) {
      throw SocketException(
        'System is temporarily busy. Please try again in 30 seconds.',
      );
    }

    // Non-critical calls: Fail fast, no retries
    if (!isCritical) {
      maxAttempts = 1;
    }

    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await action();
      } catch (e) {
        // Detect fatal backend errors
        final isFatalBackendError =
            e.toString().contains('Host is down') ||
            e.toString().contains('Connection refused') ||
            e.toString().contains('Connection failed') ||
            e.toString().contains('Network is unreachable');

        if (isFatalBackendError) {
          ApiService._markBackendDead();
          // Transform strict network errors into friendly messages
          throw SocketException(
            'Unable to connect to server. Please check your internet connection.',
          );
        }

        final isLastAttempt = attempts >= maxAttempts;
        final worthRetrying =
            shouldRetry?.call(e) ??
            (e is SocketException || e is http.ClientException);

        if (isLastAttempt || !worthRetrying) {
          rethrow;
        }

        // Only log retries for critical calls to reduce noise
        if (isCritical) {
          final delay = initialDelay * (1 << (attempts - 1)); // 1s, 2s, 4s...
          debugPrint(
            '⚠️ Network failure (Attempt $attempts). Retrying in ${delay.inSeconds}s...',
          );
          await Future.delayed(delay);
        }
      }
    }
  }

  // Get User Profile
  Future<UserProfile?> getUserProfile() async {
    // 1. 🔒 MUTEX: Prevent multiple concurrent profile fetches
    final completer = _profileCompleter;
    if (completer != null) {
      debugPrint('⏳ [ApiService] Waiting for concurrent Profile Fetch...');
      return await completer.future;
    }

    _profileCompleter = Completer<UserProfile?>();

    try {
      await ApiService.ensureSessionValid(); // 🛡️ Protect Profile
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _profileCompleter?.complete(null);
        return null;
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
              'last_used_fiat, last_used_crypto, last_used_network, ach_user_token, ach_token_expires_at')
          .eq('id', user.id)
          .single();

      final profileObj = UserProfile.fromJson(response);
      _profileCompleter?.complete(profileObj);
      return profileObj;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      _profileCompleter?.completeError(e);
      return null;
    } finally {
      _profileCompleter = null; // 🔓 Unlock
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        String errorMessage = 'Unable to get balance';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = _friendlyError(response.statusCode);
        }
        throw Exception(errorMessage);
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
    Map<String, String>? headers,
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
      (headersMap) => http.post(
        Uri.parse('$baseUrl/transfer'),
        headers: {...headersMap, ...?headers},
        body: body,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Transfer failed: ${_friendlyError(response.statusCode)}',
      );
    }
  }

  // Decode PromptPay QR Code via SQRIL
  Future<DecodedQr> decodeQR(String qrString) async {
    return _retry(() async {
      final response = await _safeRequest(
        (headers) => http.post(
          Uri.parse('$baseUrl/payout/decode'),
          headers: headers,
          body: jsonEncode({'qr_string': qrString}),
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return DecodedQr.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        String errorMessage = 'Failed to decode QR code';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    });
  }

  // Get Quotation for payout via SQRIL
  Future<QuotationModel> getQuotation(String txId, int amountSatang) async {
    return _retry(() async {
      final response = await _safeRequest(
        (headers) => http.post(
          Uri.parse('$baseUrl/payout/quote'),
          headers: headers,
          body: jsonEncode({
            'tx_id': txId,
            'amount': amountSatang,
          }),
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return QuotationModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        String errorMessage = 'Failed to get quotation';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    });
  }

  // Pay to PromptPay (Wallet -> External)
  Future<Map<String, dynamic>> payToPromptPay({
    required int amountInSatang,
    String? promptPayId,
    required String recipientName,
    String? billerId,
    String? reference1,
    String? reference2,
    required String idempotencyKey,
    String? sqrilTxId,
    Map<String, String>? headers,
  }) async {
    final body = jsonEncode({
      'amount': amountInSatang,
      'promptpay_id': promptPayId,
      'recipient_name': recipientName,
      'biller_id': billerId,
      'reference1': reference1,
      'reference2': reference2,
      'idempotency_key': idempotencyKey,
      'sqril_tx_id': sqrilTxId,
    });

    final response = await _safeRequest(
      (headersMap) => http.post(
        Uri.parse('$baseUrl/payout/promptpay'),
        headers: {...headersMap, ...?headers},
        body: body,
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Payout failed';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['error'] ?? errorMessage;
      } catch (_) {
        errorMessage = 'Payout failed: ${_friendlyError(response.statusCode)}';
      }
      throw Exception(errorMessage);
    }
  }

  /// Look up recipient name from PromptPay ID
  /// Note: In Thailand, real-time Proxy Lookup (ID -> Name) is restricted
  /// to licensed banking applications via NITMX Interbank Switch.
  /// Third-party merchants cannot freely lookup names from IDs.
  ///
  /// Validation Rely On:
  /// 1. EMV QR Code Tag 59 (Merchant Name) - Best Practice
  /// 2. Payer verification after transaction
  Future<String?> lookupPromptPayName(String promptPayId) async {
    // ⚠️ No Verification Logic needed here.
    // relying strictly on the Secure QR Payload (Tag 59).
    return null;
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

  Future<List<Transaction>> getTransactions(String walletId) async {
    // 🔌 Circuit Breaker: If backend is dead, fallback to Supabase directly
    if (!ApiService.isBackendAvailable) {
      debugPrint(
        '⚡ [Fallback] Using Supabase directly for transactions (Backend offline)',
      );
      return _getTransactionsFromSupabase(walletId);
    }

    try {
      return await _retry(() async {
        final response = await _safeRequest(
          (headers) => http.get(
            Uri.parse('$baseUrl/transactions?wallet_id=$walletId'),
            headers: headers,
          ),
        );

        if (response.statusCode == 200) {
          // 🚀 10/10 Performance: Decode JSON in background isolate
          // to keep Main Thread free for animations (0% Jank).
          final decoded = await compute(_decodeJson, response.body) as List<dynamic>;
          return decoded.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
        } else {
          debugPrint("Backend Error: ${response.body}");
          throw Exception(
            'Unable to load transactions: ${_friendlyError(response.statusCode)}',
          );
        }
      });
    } catch (e) {
      // Fallback to Supabase on any error
      debugPrint(
        '⚡ [Fallback] Backend error, using Supabase for transactions: $e',
      );
      return _getTransactionsFromSupabase(walletId);
    }
  }

  /// Fallback: Get transactions directly from Supabase
  Future<List<Transaction>> _getTransactionsFromSupabase(String profileId) async {
    try {
      final response = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(50);
      final list = response as List<dynamic>;
      return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('❌ Supabase fallback also failed: $e');
      return []; // Return empty list instead of crashing
    }
  }

  // Global static helper for Isolate decoding
  static dynamic _decodeJson(String body) => jsonDecode(body);

  // Get Exchange Rate (Non-Critical: No Retries, Fail Fast)
  Future<Map<String, dynamic>> fetchExchangeRate(String homeCurrency) async {
    // 🔌 Circuit Breaker: If backend is dead, don't even try
    if (!ApiService.isBackendAvailable) {
      throw SocketException('System busy - Rate fetch skipped');
    }

    // Non-critical call: isCritical = false means NO retries
    return _retry(() async {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/rates/latest?home_currency=$homeCurrency'),
          headers: headers,
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        String errorMessage = 'Unable to update rates';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Unable to update rates: ${_friendlyError(response.statusCode)}';
        }
        throw Exception(errorMessage);
      }
    }, isCritical: false); // ← NO RETRIES for rates
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
        'merchant_id': merchantId,
      };

      final uri = Uri.parse(
        '$baseUrl/quote',
      ).replace(queryParameters: queryParams);

      final response = await _safeRequest(
        (headers) => http.get(uri, headers: headers),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Backend Error (Quote): ${response.body}");
        String errorMessage = 'Unable to get quote';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Unable to get quote: ${_friendlyError(response.statusCode)}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint("Connection Error (Quote): $e");
      if (e is Exception && e.toString().startsWith('Exception: Unable to get quote')) {
        rethrow;
      }
      if (e is Exception && !e.toString().contains('Unable to connect to server')) {
        rethrow; // It's our own backend error exception, don't mask it
      }
      throw Exception('Unable to connect to server.');
    }
  }

  // ============================================================================
  // Execute Payout (calls payout-executor Edge Function)
  // ============================================================================
  /// Executes a real payout by calling the Supabase Edge Function.
  /// Orchestrates card/partner funding to PromptPay settlement and creates transaction ledger entries.
  Future<Map<String, dynamic>> executePayout({
    required String walletId,
    required double amountSatang,
    required String targetType, // MOBILE, NATID, EWALLET, BILLER
    required String targetValue,
    String? reference1,
    String? reference2,
    required String idempotencyKey, // 🛡️ Mandatory for survivability
    String? description,
    Map<String, String>? headers,
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
          'reference1': reference1,
          'reference2': reference2,
          'idempotency_key': idempotencyKey, // Hardened
          'description': description ?? 'Paycif Payment',
        },
        headers: headers,
      );

      debugPrint('💸 Payout response status: ${response.status}');

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] ?? 'Transfer failed';
        
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
  // ACH On-Ramp Preferences
  // Non-sensitive pre-fill data only — card credentials live in On-Ramp.
  // ============================================================================
  static Completer<UserProfile?>? _profileCompleter;

  /// Clears all static caches. Call this on logout or account switch.
  static void clearStaticCache() {
    _profileCompleter = null;
    debugPrint('🧹 ApiService static cache cleared.');
  }

  /// Fetches a fresh 10-day ACH accessToken from the Go backend.
  /// Returns null on failure — caller falls back to opening widget without token.
  Future<String?> fetchAchToken() async {
    try {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/onramp/token'),
          headers: headers,
        ),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['access_token'] as String?;
      } else {
        debugPrint('❌ fetchAchToken failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ fetchAchToken error: $e');
    }
    return null;
  }

  /// Returns a signed On-Ramp Page Integration URL for managing saved payment methods.
  /// Backend embeds the ACH token so the user lands directly in their account.
  Future<String?> fetchManageUrl() async {
    try {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/onramp/manage-url'),
          headers: headers,
        ),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['url'] as String?;
      } else {
        debugPrint('❌ fetchManageUrl failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ fetchManageUrl error: $e');
    }
    return null;
  }

  /// Returns ACH-supported fiat payment methods (1-hour server cache).
  Future<List<Map<String, dynamic>>> fetchFiatMethods() async {
    try {
      final response = await _safeRequest(
        (headers) => http.get(
          Uri.parse('$baseUrl/onramp/fiat-methods'),
          headers: headers,
        ),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final list = body['methods'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      } else {
        debugPrint('❌ fetchFiatMethods failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ fetchFiatMethods error: $e');
    }
    return [];
  }

  /// Persists the user's last-used fiat/crypto/network to the profiles table.
  Future<void> updateAchPreferences({
    required String fiat,
    required String crypto,
    required String network,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('profiles').update({
      'last_used_fiat': fiat,
      'last_used_crypto': crypto,
      'last_used_network': network,
    }).eq('id', user.id);
  }

  // 🛡️ User-Friendly Error Mapper
  static String _friendlyError(int statusCode) {
    switch (statusCode) {
      case 400:
        return "Invalid request. Please check your input.";
      case 401:
        return "Session expired. Please log in again.";
      case 402:
        return "Insufficient balance.";
      case 403:
        return "Access denied.";
      case 404:
        return "Resource not found.";
      case 409:
        return "Duplicate transaction detected.";
      case 429:
        return "Too many requests. Please slow down.";
      case 500:
        return "System error. Please try again later.";
      case 502:
        return "Server unavailable. Please try again later.";
      case 503:
        return "Service maintenance. Please try again shortly.";
      default:
        return "Something went wrong (Error $statusCode).";
    }
  }

  /// 🔐 KYC: Initiate Alchemy Pay KYC — returns { status, kyc_url? }
  static Future<Map<String, dynamic>> initiateKyc({
    String kycPlatform = 'sumsub',
    String kycType = '1',
    String redirectUrl = '',
  }) async {
    final url = Uri.parse('$baseUrl/kyc/register');
    await ensureSessionValid();
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'kyc_platform': kycPlatform,
        'kyc_type': kycType,
        if (redirectUrl.isNotEmpty) 'redirect_url': redirectUrl,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to initiate KYC: ${response.body}');
  }

  /// 👤 KYC: Poll current verification status from backend
  static Future<Map<String, dynamic>> getKycStatus() async {
    final url = Uri.parse('$baseUrl/kyc/status');
    await ensureSessionValid();
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch KYC status: ${response.body}');
  }

  /// Creates a PayoutIntent and returns the On-Ramp checkout URL + intent ID.
  /// This is the entry point for the pay-per-use on-ramp flow.
  Future<({String webUrl, String intentId})> initiateOnRampPayment({
    required int amountSatang,
    required String sqrilTxId,
    required String promptPayId,
    required String recipientName,
    required String fiatCurrency,
    required String idempotencyKey,
    String? billerId,
    String? reference1,
    String? reference2,
    String? email,
    double? lat,
    double? lng,
  }) async {
    final response = await _safeRequest(
      (headers) => http.post(
        Uri.parse('$baseUrl/payments/create-intent'),
        headers: headers,
        body: jsonEncode({
          'amount': amountSatang,
          'fiat_currency': fiatCurrency,
          'promptpay_id': promptPayId,
          'recipient_name': recipientName,
          'sqril_tx_id': sqrilTxId,
          'corridor_type': 'CARD',
          'idempotency_key': idempotencyKey,
          // ignore: use_null_aware_elements
          if (billerId != null) 'biller_id': billerId,
          // ignore: use_null_aware_elements
          if (reference1 != null) 'reference1': reference1,
          // ignore: use_null_aware_elements
          if (reference2 != null) 'reference2': reference2,
          // ignore: use_null_aware_elements
          if (email != null) 'email': email,
          // Soft signal only — informational/audit, not used for blocking.
          // The real geo-fence is the backend's IP-based check.
          // ignore: use_null_aware_elements
          if (lat != null) 'lat': lat,
          // ignore: use_null_aware_elements
          if (lng != null) 'lng': lng,
        }),
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final webUrl = data['web_url'] as String?;
      final intentId = data['intent_id'] as String?;
      if (webUrl == null || intentId == null) {
        throw Exception('Invalid response from payment server');
      }
      return (webUrl: webUrl, intentId: intentId);
    }

    String errorMsg = 'Payment initiation failed';
    try {
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      errorMsg = err['error'] as String? ?? errorMsg;
    } catch (_) {}
    throw Exception(errorMsg);
  }

  /// Polls the status of a PayoutIntent.
  /// Returns: PENDING | COMPLETED | FAILED | ACH_FAILED | PAYMENT_SUCCESS_PAYOUT_PENDING
  Future<String> getIntentStatus(String intentId) async {
    final response = await _safeRequest(
      (headers) => http.get(
        Uri.parse('$baseUrl/payments/intent/$intentId/status'),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['status'] as String? ?? 'PENDING';
    }
    throw Exception('Failed to get intent status');
  }
}

