import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'dart:async';

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  Stream<AuthState> get authStream => _client.auth.onAuthStateChange;

  /// Fetches transactions using Supabase Realtime postgres_changes.
  /// Falls back to a one-time query on channel error so the stream never goes silent.
  Stream<List<Transaction>> fetchTransactions(String profileId) {
    final controller = StreamController<List<Transaction>>.broadcast();
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      if (controller.isClosed) return;
      try {
        final data = await _client
            .from('transactions')
            .select()
            .eq('profile_id', profileId)
            .order('created_at', ascending: false);
        if (!controller.isClosed) {
          final txs = (data as List<dynamic>)
              .map((json) => Transaction.fromJson(json))
              .toList();
          controller.add(txs);
        }
      } catch (e) {
        debugPrint('❌ [DashboardRepository] fetchAndEmit error: $e');
      }
    }

    void subscribe() {
      channel?.unsubscribe();

      channel = _client
          .channel('transactions:profile_id=eq.$profileId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: profileId,
            ),
            callback: (_) => fetchAndEmit(),
          )
          .subscribe((status, [error]) {
            if (kDebugMode) {
              debugPrint('📡 [DashboardRepository] Realtime status: $status');
            }
            if (status == RealtimeSubscribeStatus.subscribed) {
              // Initial load on successful subscription
              fetchAndEmit();
            } else if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              debugPrint('⚠️ [DashboardRepository] Channel error ($status): $error. Falling back to one-time query.');
              fetchAndEmit();
            } else if (status == RealtimeSubscribeStatus.closed) {
              // 'closed' is expected when unsubscribing/switching screens, no need to query again or log
            }
          });
    }

    // Lazy initialization: subscribe only when there is a listener
    controller.onListen = () {
      subscribe();
    };

    // Clean up when the stream is no longer listened to
    controller.onCancel = () {
      channel?.unsubscribe();
      channel = null;
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
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
