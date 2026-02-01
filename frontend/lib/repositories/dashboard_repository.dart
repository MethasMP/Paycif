import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../models/exchange_rate_model.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../features/security/data/datasources/secure_storage_service.dart';
import 'dart:convert';
import 'dart:async';

class DashboardRepository {
  final SupabaseClient _client;
  final ApiService _api = ApiService();
  final SecureStorageService _storage = SecureStorageService();

  static const _kWalletCacheKey = 'cache_wallet_data';
  static const _kTxCacheKey = 'cache_transactions_data';

  // 🚀 Reactive Stream for Transactions
  final _txController = StreamController<List<Transaction>>.broadcast();
  Stream<List<Transaction>> get transactionsStream => _txController.stream;
  List<Transaction> _lastTxsCache = [];

  DashboardRepository(this._client);

  /// Exposes the auth state change stream from Supabase.
  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  /// Streams the user's primary wallet.
  /// For V1/V2 transition, we fetch the first wallet found for the user.
  Stream<Wallet?> fetchUserWallet() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(null);
    }

    // Real-time listener for the wallets table
    return _client
        .from('wallets')
        .stream(primaryKey: ['id'])
        .eq('profile_id', userId)
        .limit(1)
        .map((data) {
          if (data.isEmpty) return null;
          final wallet = Wallet.fromJson(data.first);

          // 📡 [Side-Effect] Keep cache in sync with Cloud ground truth
          _storage
              .write(_kWalletCacheKey, jsonEncode(wallet.toJson()))
              .ignore();

          return wallet;
        });
  }

  /// ⚡ [Fast-Path] Load Wallet from Disk Cache
  Future<Wallet?> getCachedWallet() async {
    final json = await _storage.read(_kWalletCacheKey);
    if (json == null) return null;
    try {
      return Wallet.fromJson(jsonDecode(json));
    } catch (e) {
      return null;
    }
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
          'full_name': user.userMetadata?['full_name'] ?? 'Paycif User',
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

  /// Fetches the latest transactions for a specific wallet via Go Backend.
  /// This ensures correct JOIN logic and auditing.
  Stream<List<Transaction>> fetchTransactions(String walletId) {
    // Return the broadcast stream so multiple listeners can stay in sync
    _api
        .getTransactions(walletId)
        .then((data) {
          final txs = data.map((json) => Transaction.fromJson(json)).toList();
          _lastTxsCache = txs;
          _txController.add(txs);

          // 📡 [Side-Effect] Keep cache in sync
          _storage
              .write(
                _kTxCacheKey,
                jsonEncode(txs.map((t) => t.toJson()).toList()),
              )
              .ignore();
        })
        .catchError((e) {
          debugPrint('❌ DashboardRepository: Error fetching transactions: $e');
        });

    return transactionsStream;
  }

  /// ⚡ [Fast-Path] Load Transactions from Disk Cache
  Future<List<Transaction>> getCachedTransactions() async {
    final json = await _storage.read(_kTxCacheKey);
    if (json == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(json);
      final txs = decoded.map((item) => Transaction.fromJson(item)).toList();
      _lastTxsCache = txs;
      return txs;
    } catch (e) {
      return [];
    }
  }

  /// 🚀 Atomic Sync: Updates both balance and transaction list instantly
  /// following a successful payment. This remains consistent with the
  /// Reactive Architecture as it pushes to the same stream.
  void synchronizePaymentSuccess({
    required String transactionId,
    required double amount,
    required String recipientName,
    required double remainingBalanceMajor,
  }) {
    // 1. Create the persistent Transaction entry
    final newTx = Transaction(
      id: transactionId,
      walletId: _client.auth.currentUser?.id ?? '', // Mock or actual wallet ID
      type: 'payment',
      amount: (amount * 100).toInt(),
      description: 'Payment to $recipientName',
      createdAt: DateTime.now(),
    );

    // 2. Prepend to current cache
    _lastTxsCache = [newTx, ..._lastTxsCache];

    // 3. Push to all reactive listeners (Dashboard, History, etc.)
    _txController.add(_lastTxsCache);

    // 4. Persistence: Write to Disk immediately (Resilience)
    _storage
        .write(
          _kTxCacheKey,
          jsonEncode(_lastTxsCache.map((t) => t.toJson()).toList()),
        )
        .ignore();

    // Note: Wallet balance is handled by Supabase Realtime Stream automatically,
    // but we heal the local cache just in case the Realtime connection is slow.
    getCachedWallet().then((wallet) {
      if (wallet != null) {
        final updatedWallet = wallet.copyWith(
          balance: (remainingBalanceMajor * 100).round(),
        );
        _storage
            .write(_kWalletCacheKey, jsonEncode(updatedWallet.toJson()))
            .ignore();
      }
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
