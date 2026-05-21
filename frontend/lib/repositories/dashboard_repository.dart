import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import 'dart:async';

class DashboardRepository {
  final SupabaseClient _client;
  final ApiService _api = ApiService();

  DashboardRepository(this._client);

  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  Stream<Wallet?> fetchUserWallet() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    return _client
        .from('wallets')
        .stream(primaryKey: ['id'])
        .eq('profile_id', userId)
        .limit(1)
        .map((data) => data.isEmpty ? null : Wallet.fromJson(data.first));
  }

  Stream<List<Transaction>> fetchTransactions(String walletId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('wallet_id', walletId)
        .order('created_at')
        .map((data) {
          final txs = data.map((json) => Transaction.fromJson(json)).toList();
          txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return txs;
        });
  }

  Future<void> createWalletManually() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('wallets').insert({
        'profile_id': user.id,
        'balance': 0,
        'currency': 'THB',
        'account_type': 'standard',
        'status': 'active',
      });
    } catch (e) {
      debugPrint("Manual wallet creation info: $e");
    }
  }
}
