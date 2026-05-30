import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'dart:async';

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  Stream<List<Transaction>> fetchTransactions(String profileId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('profile_id', profileId)
        .order('created_at')
        .map((data) {
          final txs = data.map((json) => Transaction.fromJson(json)).toList();
          txs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return txs;
        });
  }

  Future<List<Transaction>> getTransactionsOnce(String profileId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to fetch transactions once: $e');
      return [];
    }
  }
}

