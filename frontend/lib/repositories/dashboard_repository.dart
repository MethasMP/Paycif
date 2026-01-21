import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../models/exchange_rate_model.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';

class DashboardRepository {
  final SupabaseClient _client;
  final ApiService _api = ApiService();

  DashboardRepository(this._client);

  /// Streams the user's primary wallet.
  /// For V1/V2 transition, we fetch the first wallet found for the user.
  Stream<Wallet?> fetchUserWallet() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(null); // Return null stream if not logged in
    }

    // Real-time listener for the wallets table
    return _client
        .from('wallets')
        .stream(primaryKey: ['id'])
        .eq('profile_id', userId)
        .limit(1)
        .map((data) {
          if (data.isEmpty) {
            return null;
          }
          return Wallet.fromJson(data.first);
        });
  }

  /// Fetches the latest exchange rate for the given pair via API.
  Future<ExchangeRate?> fetchLatestRate(
    String fromCurrency,
    String toCurrency,
  ) async {
    try {
      String homeCurrency;
      bool invert = false;

      // Logic: We assume one of the currencies is THB (Base)
      if (toCurrency == 'THB') {
        homeCurrency = fromCurrency; // e.g. EUR -> THB
      } else if (fromCurrency == 'THB') {
        homeCurrency = toCurrency; // e.g. THB -> EUR
        invert = true;
      } else {
        debugPrint(
          'Cross rates not supported yet: $fromCurrency -> $toCurrency',
        );
        return null; // Only Base <-> Foreign supported for now
      }

      if (homeCurrency == 'THB') {
        return ExchangeRate(
          fromCurrency: 'THB',
          toCurrency: 'THB',
          providerRate: 1.0,
        );
      }

      final data = await _api.fetchExchangeRate(homeCurrency);

      ExchangeRate fetchedRate;
      try {
        fetchedRate = ExchangeRate.fromJson(data);
      } catch (e) {
        debugPrint('❌ Parsed Error: $e');
        debugPrint('📦 Raw JSON: $data');
        return null;
      }

      if (invert) {
        final double rateVal = fetchedRate.providerRate ?? 0.0;
        return ExchangeRate(
          fromCurrency: 'THB',
          toCurrency: homeCurrency,
          providerRate: (rateVal != 0) ? (1.0 / rateVal) : 0.0,
          updatedAt: fetchedRate.updatedAt,
        );
      }
      return fetchedRate;
    } catch (e) {
      debugPrint('Error fetching rate: $e');
      return null;
    }
  }

  /// Manually creates a wallet if one doesn't exist.
  /// Acts as a fallback for failed database triggers.
  Future<void> createWalletManually() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Ensure Profile Exists
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint("⚠️ Profile missing. Healing profile...");
        await _client.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? 'ZapPay User',
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint("✅ Profile manually created.");
      }

      // 2. Ensure Wallet Exists
      await _client.from('wallets').insert({
        'profile_id': user.id,
        'balance': 0,
        'currency': 'THB',
        'account_type': 'standard',
        'status': 'active',
      });
      debugPrint("✅ Wallet manually created.");
    } catch (e) {
      debugPrint("⚠️ Manual wallet creation info: $e");
    }
  }

  /// Streams the latest transactions for a specific wallet.
  /// Bypasses the Go backend for reads to improve performance.
  Stream<List<Transaction>> fetchTransactions(String walletId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('wallet_id', walletId)
        .order('created_at', ascending: false)
        .limit(10) // Limit to top 10 for dashboard
        .map((data) {
          return data.map((json) => Transaction.fromJson(json)).toList();
        });
  }

  /// Diagnostic function to check wallet existence and permissions.
  Future<String> runWalletDiagnostic() async {
    final sb = StringBuffer();
    final user = _client.auth.currentUser;
    sb.writeln('🔍 Auth ID: ${user?.id ?? "NULL"}');

    if (user == null) {
      sb.writeln('⚠️ User Not Logged In!');
      return sb.toString();
    }

    try {
      sb.writeln(
        '📦 DB Request: from(\'wallets\').select().eq(\'profile_id\', \'${user.id}\').single()',
      );
      final response = await _client
          .from('wallets')
          .select()
          .eq('profile_id', user.id)
          .maybeSingle();

      sb.writeln('✅ DB Result: Success!');
      sb.writeln('📄 Data: $response');
    } catch (e) {
      sb.writeln('⚠️ Error Details: $e');
      if (e.toString().contains('PGRST116')) {
        sb.writeln(
          '💡 Diagnosis: No wallet found for this user. Check signals: 1) Has the create_wallet trigger run? 2) Is RLS blocking view?',
        );
      }
    }
    return sb.toString();
  }
}
